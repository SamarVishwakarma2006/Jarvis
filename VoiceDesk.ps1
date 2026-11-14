$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class VoiceDeskNative {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)]
    public static extern int GetWindowText(IntPtr handle, StringBuilder text, int count);
}
'@

function Get-ActiveTarget {
    $handle = [VoiceDeskNative]::GetForegroundWindow()
    if ($handle -eq [IntPtr]::Zero) { throw 'No foreground window was found.' }
    if ($handle -eq $form.Handle) { throw 'VoiceDesk is the active window. Select the window you want to control, then try again.' }

    $element = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $title = $element.Current.Name
    if ([string]::IsNullOrWhiteSpace($title)) {
        $text = [System.Text.StringBuilder]::new(512)
        [void][VoiceDeskNative]::GetWindowText($handle, $text, $text.Capacity)
        $title = $text.ToString()
    }
    if ([string]::IsNullOrWhiteSpace($title)) { $title = 'Untitled window' }
    return @{ Handle = $handle; Element = $element; Title = $title }
}

function Invoke-DesktopAction {
    param([Parameter(Mandatory)][ValidateSet('OpenNotepad','OpenCalculator','OpenFile','MinimizeWindow','MaximizeWindow','CloseWindow','TakeScreenshot')][string]$Name)

    switch ($Name) {
        'OpenNotepad' { Start-Process notepad; return 'Opened Notepad.' }
        'OpenCalculator' { Start-Process calc; return 'Opened Calculator.' }
        'OpenFile' {
            $selection = @{ Path = $null }
            $form.Invoke([System.Action] {
                $dialog = [System.Windows.Forms.OpenFileDialog]::new()
                $dialog.Title = 'Choose a file to open'
                $dialog.Filter = 'Documents and images|*.txt;*.md;*.pdf;*.doc;*.docx;*.xls;*.xlsx;*.ppt;*.pptx;*.csv;*.png;*.jpg;*.jpeg;*.gif;*.bmp|All files (*.*)|*.*'
                $dialog.CheckFileExists = $true
                $dialog.Multiselect = $false
                if ($dialog.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK) {
                    $selection.Path = $dialog.FileName
                }
                $dialog.Dispose()
            }) | Out-Null

            if (-not $selection.Path) { return 'File selection cancelled.' }
            if (-not [System.IO.File]::Exists($selection.Path)) { throw 'The selected file no longer exists.' }
            $allowedExtensions = @('.txt','.md','.pdf','.doc','.docx','.xls','.xlsx','.ppt','.pptx','.csv','.png','.jpg','.jpeg','.gif','.bmp')
            $extension = [System.IO.Path]::GetExtension($selection.Path).ToLowerInvariant()
            if ($extension -notin $allowedExtensions) { throw "Files ending in '$extension' are not supported by the file picker." }
            Start-Process -FilePath $selection.Path
            return "Opened '$([System.IO.Path]::GetFileName($selection.Path))' in its default app."
        }
    }

    $target = Get-ActiveTarget
    if ($Name -eq 'TakeScreenshot') {
        [System.Windows.Forms.SendKeys]::SendWait('{PRTSC}')
        return "Sent Print Screen for '$($target.Title)'; no image file was saved."
    }

    try {
        if ([VoiceDeskNative]::GetForegroundWindow() -ne $target.Handle) {
            throw 'The active window changed before the action could run.'
        }
        $pattern = $null
        $hasWindowPattern = $target.Element.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$pattern)
        if (-not $hasWindowPattern) { throw 'The window does not expose the UI Automation window pattern.' }
        switch ($Name) {
            'MinimizeWindow' { $pattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Minimized) }
            'MaximizeWindow' { $pattern.SetWindowVisualState([System.Windows.Automation.WindowVisualState]::Maximized) }
            'CloseWindow' { $pattern.Close() }
        }
        return "$Name completed for '$($target.Title)' using UI Automation."
    } catch {
        # The active window is checked again before the keyboard fallback.
        if ([VoiceDeskNative]::GetForegroundWindow() -ne $target.Handle) {
            throw "The active window changed before the fallback action could run. $($_.Exception.Message)"
        }
        switch ($Name) {
            'MinimizeWindow' { [System.Windows.Forms.SendKeys]::SendWait('% n') }
            'MaximizeWindow' { [System.Windows.Forms.SendKeys]::SendWait('% x') }
            'CloseWindow' { [System.Windows.Forms.SendKeys]::SendWait('%{F4}') }
        }
        return "$Name shortcut sent to '$($target.Title)' (UI Automation was unavailable)."
    }
}

function Resolve-VoiceIntent {
    param([Parameter(Mandatory)][string]$Text)
    $localIntents = @{
        'open notepad' = 'open_notepad'; 'open calculator' = 'open_calculator'; 'open file' = 'open_file'
        'minimize window' = 'minimize_window'; 'maximize window' = 'maximize_window'
        'close window' = 'close_window'; 'take screenshot' = 'take_screenshot'
    }
    $normalized = $Text.Trim().ToLowerInvariant()
    if ($localIntents.ContainsKey($normalized)) {
        return @{ intent = $localIntents[$normalized]; reply = 'Matched a local voice command.'; requires_confirmation = ($normalized -eq 'close window') }
    }

    $payload = @{ text = $Text } | ConvertTo-Json -Compress
    $intent = Invoke-RestMethod -Uri 'http://127.0.0.1:43127/intent' -Method Post -ContentType 'application/json' -Body $payload -TimeoutSec 20
    $allowed = @('open_notepad','open_calculator','open_file','minimize_window','maximize_window','close_window','take_screenshot','unknown')
    if ($intent.intent -notin $allowed -or [string]::IsNullOrWhiteSpace($intent.reply)) {
        throw 'AI returned an invalid action. No desktop action was run.'
    }
    if ($intent.intent -eq 'close_window') { $intent.requires_confirmation = $true }
    return $intent
}

function Invoke-IntentFromVoice {
    param([Parameter(Mandatory)]$Intent)
    if ($Intent.intent -eq 'unknown') { return $Intent.reply }
    if ($Intent.requires_confirmation -or $Intent.intent -eq 'close_window') {
        $confirmation = @{ Approved = $false }
        $form.Invoke([System.Action] {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                $form, "Close the active window?`r`n`r`n$($Intent.reply)", 'Confirm close window',
                [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $confirmation.Approved = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
        }) | Out-Null
        if (-not $confirmation.Approved) { return 'Cancelled. The window was not closed.' }
    }
    $actionName = @{
        open_notepad = 'OpenNotepad'; open_calculator = 'OpenCalculator'; open_file = 'OpenFile'
        minimize_window = 'MinimizeWindow'; maximize_window = 'MaximizeWindow'; close_window = 'CloseWindow'
        take_screenshot = 'TakeScreenshot'
    }[$Intent.intent]
    if (-not $actionName) { return 'Unknown request. No action was run.' }
    return Invoke-DesktopAction -Name $actionName
}

[System.Windows.Forms.Application]::EnableVisualStyles()
$culture = (Get-Culture).Name
$recognizerInfo = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
    Where-Object { $_.Culture.Name -eq $culture } |
    Select-Object -First 1

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'VoiceDesk'
$form.StartPosition = 'CenterScreen'
$form.Size = [System.Drawing.Size]::new(480, 360)
$form.MinimumSize = [System.Drawing.Size]::new(420, 320)
$form.Font = [System.Drawing.Font]::new('Segoe UI', 10)

$layout = [System.Windows.Forms.TableLayoutPanel]::new()
$layout.Dock = 'Fill'
$layout.Padding = [System.Windows.Forms.Padding]::new(20)
$layout.ColumnCount = 1
$layout.RowCount = 6
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('Percent', 100))
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))

$status = [System.Windows.Forms.Label]::new()
$status.Text = 'Microphone off'
$status.AutoSize = $true
$status.Font = [System.Drawing.Font]::new('Segoe UI', 14, [System.Drawing.FontStyle]::Bold)
$hint = [System.Windows.Forms.Label]::new()
$hint.Text = 'Press Start listening before speaking.'
$hint.AutoSize = $true
$transcript = [System.Windows.Forms.Label]::new()
$transcript.Text = 'Heard: —'
$transcript.Dock = 'Fill'
$transcript.BorderStyle = 'FixedSingle'
$transcript.Padding = [System.Windows.Forms.Padding]::new(12)
$transcript.AutoEllipsis = $true
$lastAction = [System.Windows.Forms.Label]::new()
$lastAction.Text = 'Last action: none'
$lastAction.AutoSize = $true
$lastAction.MaximumSize = [System.Drawing.Size]::new(400, 0)
$listenButton = [System.Windows.Forms.Button]::new()
$listenButton.Text = 'Start listening'
$listenButton.AutoSize = $true
$listenButton.MinimumSize = [System.Drawing.Size]::new(180, 42)
$commands = [System.Windows.Forms.Label]::new()
$commands.Text = 'Exact basic commands work offline. Other requests send the transcript to OpenAI for interpretation; internet access and API usage charges may apply.'
$commands.AutoSize = $true
$commands.MaximumSize = [System.Drawing.Size]::new(400, 0)

$layout.Controls.Add($status, 0, 0)
$layout.Controls.Add($hint, 0, 1)
$layout.Controls.Add($transcript, 0, 2)
$layout.Controls.Add($lastAction, 0, 3)
$layout.Controls.Add($listenButton, 0, 4)
$layout.Controls.Add($commands, 0, 5)
$form.Controls.Add($layout)
$state = @{ Listening = $false }

if (-not $recognizerInfo) {
    $hint.Text = "No Windows speech recognizer is installed for '$culture'. Install the matching speech language in Windows Settings."
    $listenButton.Enabled = $false
} else {
    try {
        $recognizer = [System.Speech.Recognition.SpeechRecognitionEngine]::new($recognizerInfo)
        $recognizer.LoadGrammar([System.Speech.Recognition.DictationGrammar]::new())
        try {
            $recognizer.SetInputToDefaultAudioDevice()
        } catch {
            $hint.Text = "Microphone unavailable. Connect or enable one and check Windows microphone privacy settings. $($_.Exception.Message)"
            $listenButton.Enabled = $false
        }

        $recognizer.add_SpeechRecognitionRejected({
            $form.BeginInvoke([System.Action] {
                $transcript.Text = 'Heard: (no supported command recognized)'
            }) | Out-Null
        })
        $recognizer.add_SpeechRecognized({
            param($sender, $eventArgs)
            $command = $eventArgs.Result.Text
            $confidence = $eventArgs.Result.Confidence
            $form.BeginInvoke([System.Action] {
                $transcript.Text = ("Heard: {0} ({1:P0} confidence)" -f $command, $confidence)
            }) | Out-Null

            if ($confidence -lt 0.60) {
                $result = 'Ignored: recognition confidence was too low.'
            } else {
                try {
                    if ($command.Trim().ToLowerInvariant() -eq 'stop listening') {
                        $sender.RecognizeAsyncCancel()
                        $result = 'Listening stopped.'
                    } else {
                        $intent = Resolve-VoiceIntent -Text $command
                        $result = Invoke-IntentFromVoice -Intent $intent
                    }
                } catch {
                    $result = "No action was run: $($_.Exception.Message)"
                }
            }
            $form.BeginInvoke([System.Action] { $lastAction.Text = "Last action: $result" }) | Out-Null
        })
        $recognizer.add_RecognizeCompleted({
            param($sender, $eventArgs)
            $message = if ($eventArgs.Error) { "Recognition error: $($eventArgs.Error.Message)" } else { 'Microphone off' }
            $form.BeginInvoke([System.Action] {
                $status.Text = $message
                $state.Listening = $false
                $listenButton.Text = 'Start listening'
                $hint.Text = if ($eventArgs.Error) { 'Check microphone access and try again.' } else { 'Press Start listening before speaking.' }
            }) | Out-Null
        })

        $listenButton.add_Click({
            if ($state.Listening) {
                $recognizer.RecognizeAsyncCancel()
                $hint.Text = 'Stopping microphone…'
            } else {
                try {
                    $state.Listening = $true
                    $status.Text = 'Listening…'
                    $hint.Text = 'Listening. Exact commands stay on this PC; other recognized requests are sent to OpenAI. Press Stop listening to stop.'
                    $listenButton.Text = 'Stop listening'
                    $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
                } catch {
                    $state.Listening = $false
                    $status.Text = 'Microphone off'
                    $listenButton.Text = 'Start listening'
                    $hint.Text = "Could not start listening: $($_.Exception.Message)"
                }
            }
        })
        $form.add_FormClosing({
            if ($recognizer) {
                try { $recognizer.RecognizeAsyncCancel() } catch {}
                $recognizer.Dispose()
            }
        })
    } catch {
        $hint.Text = "Voice recognition setup failed: $($_.Exception.Message)"
        $listenButton.Enabled = $false
    }
}

[void]$form.ShowDialog()
