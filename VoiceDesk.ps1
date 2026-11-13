$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

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
$commands.Text = 'Commands: open notepad · open calculator · minimize/maximize/close window · take screenshot · stop listening'
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
        $choices = [System.Speech.Recognition.Choices]::new(
            'open notepad', 'open calculator', 'minimize window', 'maximize window',
            'close window', 'take screenshot', 'stop listening'
        )
        $builder = [System.Speech.Recognition.GrammarBuilder]::new()
        $builder.Append($choices)
        $recognizer.LoadGrammar([System.Speech.Recognition.Grammar]::new($builder))
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
                    switch ($command) {
                        'open notepad' { Start-Process notepad; $result = 'Opened Notepad.' }
                        'open calculator' { Start-Process calc; $result = 'Opened Calculator.' }
                        'minimize window' { [System.Windows.Forms.SendKeys]::SendWait('% n'); $result = 'Sent minimize shortcut to the active window.' }
                        'maximize window' { [System.Windows.Forms.SendKeys]::SendWait('% x'); $result = 'Sent maximize shortcut to the active window.' }
                        'close window' { [System.Windows.Forms.SendKeys]::SendWait('%{F4}'); $result = 'Sent close shortcut to the active window.' }
                        'take screenshot' { [System.Windows.Forms.SendKeys]::SendWait('{PRTSC}'); $result = 'Sent Print Screen; no image file was saved.' }
                        'stop listening' {
                            $sender.RecognizeAsyncCancel()
                            $result = 'Listening stopped.'
                        }
                        default { $result = 'Ignored: command is not allowlisted.' }
                    }
                } catch {
                    $result = "Action failed: $($_.Exception.Message)"
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
                    $hint.Text = 'VoiceDesk is listening. Press Stop listening or say “stop listening”.'
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
