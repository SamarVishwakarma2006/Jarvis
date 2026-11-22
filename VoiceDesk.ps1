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
    param([IntPtr]$Handle = [IntPtr]::Zero)
    if ($Handle -eq [IntPtr]::Zero) { $Handle = [VoiceDeskNative]::GetForegroundWindow() }
    $handle = $Handle
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
    param(
        [Parameter(Mandatory)][ValidateSet('OpenNotepad','OpenCalculator','OpenExplorer','OpenSettings','OpenFile','MinimizeWindow','MaximizeWindow','CloseWindow','TakeScreenshot')][string]$Name,
        [IntPtr]$TargetHandle = [IntPtr]::Zero
    )

    switch ($Name) {
        'OpenNotepad' { Start-Process notepad; return 'Opened Notepad.' }
        'OpenCalculator' { Start-Process calc; return 'Opened Calculator.' }
        'OpenExplorer' { Start-Process explorer.exe; return 'Opened File Explorer.' }
        'OpenSettings' { Start-Process 'ms-settings:'; return 'Opened Windows Settings.' }
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

    $target = Get-ActiveTarget -Handle $TargetHandle
    if ($Name -eq 'TakeScreenshot') {
        [System.Windows.Forms.SendKeys]::SendWait('{PRTSC}')
        return "Sent Print Screen for '$($target.Title)'; no image file was saved."
    }
    if ($Name -in @('MinimizeWindow', 'MaximizeWindow', 'CloseWindow')) {
        $state.LastUndo = $null
        if ($undoButton) { $form.BeginInvoke([System.Action] { $undoButton.Enabled = $false }) | Out-Null }
    }

    try {
        if ($TargetHandle -eq [IntPtr]::Zero -and [VoiceDeskNative]::GetForegroundWindow() -ne $target.Handle) {
            throw 'The active window changed before the action could run.'
        }
        $pattern = $null
        $hasWindowPattern = $target.Element.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$pattern)
        if (-not $hasWindowPattern) { throw 'The window does not expose the UI Automation window pattern.' }
        $priorState = $null
        $appliedState = $null
        if ($Name -in @('MinimizeWindow', 'MaximizeWindow')) {
            $priorState = $pattern.Current.WindowVisualState
            $appliedState = if ($Name -eq 'MinimizeWindow') { [System.Windows.Automation.WindowVisualState]::Minimized } else { [System.Windows.Automation.WindowVisualState]::Maximized }
        }
        switch ($Name) {
            'MinimizeWindow' { $pattern.SetWindowVisualState($appliedState) }
            'MaximizeWindow' { $pattern.SetWindowVisualState($appliedState) }
            'CloseWindow' { $pattern.Close() }
        }
        if ($priorState -ne $null) {
            $state.LastUndo = @{ Handle = $target.Handle; Title = $target.Title; PriorState = $priorState; AppliedState = $appliedState }
            if ($undoButton) { $form.BeginInvoke([System.Action] { $undoButton.Enabled = $true }) | Out-Null }
        }
        return "$Name completed for '$($target.Title)' using UI Automation."
    } catch {
        # The active window is checked again before the keyboard fallback.
        if ([VoiceDeskNative]::GetForegroundWindow() -ne $target.Handle) {
            throw "UI Automation could not control '$($target.Title)', and it is not the foreground window for a safe keyboard fallback. No shortcut was sent. $($_.Exception.Message)"
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
        'open notepad' = 'open_notepad'; 'open calculator' = 'open_calculator'; 'open file explorer' = 'open_explorer'; 'open windows settings' = 'open_settings'; 'open file' = 'open_file'
        'open work tools' = 'run_work_tools_routine'
        'minimize window' = 'minimize_window'; 'maximize window' = 'maximize_window'
        'close window' = 'close_window'; 'take screenshot' = 'take_screenshot'
        'what is on my screen' = 'screen_question'; 'what is on the screen' = 'screen_question'
    }
    $normalized = $Text.Trim().ToLowerInvariant()
    if ($localIntents.ContainsKey($normalized)) {
        $localIntent = $localIntents[$normalized]
        if ($localIntent -eq 'screen_question' -and -not $state.AiEnabled) {
            return @{ intent = 'unknown'; reply = 'Cloud AI is off. Enable it in VoiceDesk to ask questions about the screen.'; question = $Text }
        }
        return @{ intent = $localIntent; reply = 'Matched a local voice command.'; requires_confirmation = ($normalized -eq 'close window'); question = $Text }
    }

    foreach ($routine in @(Get-ValidatedRoutine)) {
        if (@($routine.phrases | ForEach-Object { $_.Trim().ToLowerInvariant() }) -contains $normalized) {
            return @{ intent = 'run_routine'; routine_id = $routine.id; reply = 'Matched a saved local routine.'; question = $Text }
        }
    }

    if (-not $state.AiEnabled) {
        return @{ intent = 'unknown'; reply = 'Cloud AI is off. Enable it in VoiceDesk for natural-language commands.'; question = $Text }
    }

    $payloadObject = @{ text = $Text }
    if ($state.ContextEnabled -and $state.Context.Count -gt 0) { $payloadObject.context = @($state.Context) }
    $payload = $payloadObject | ConvertTo-Json -Depth 4 -Compress
    $intent = Invoke-RestMethod -Uri 'http://127.0.0.1:43127/intent' -Method Post -ContentType 'application/json' -Body $payload -TimeoutSec 35
    $allowed = @('open_notepad','open_calculator','open_explorer','open_settings','open_file','minimize_window','maximize_window','close_window','take_screenshot','screen_question','run_work_tools_routine','unknown')
    if ($intent.intent -notin $allowed -or [string]::IsNullOrWhiteSpace($intent.reply)) {
        throw 'AI returned an invalid action. No desktop action was run.'
    }
    $intent.requires_confirmation = ($intent.intent -eq 'close_window')
    $intent.used_cloud_ai = $true
    $intent | Add-Member -NotePropertyName question -NotePropertyValue $Text -Force
    return $intent
}

function Get-ActiveWindowText {
    $target = Get-ActiveTarget
    $elements = $target.Element.FindAll(
        [System.Windows.Automation.TreeScope]::Descendants,
        [System.Windows.Automation.Condition]::TrueCondition
    )
    $lines = [System.Collections.Generic.List[string]]::new()
    $count = [Math]::Min($elements.Count, 100)
    for ($index = 0; $index -lt $count; $index++) {
        try {
            $element = $elements.Item($index)
            $name = $element.Current.Name
            if (-not [string]::IsNullOrWhiteSpace($name)) {
                $type = $element.Current.ControlType.ProgrammaticName
                $lines.Add("$type`: $name")
            }
        } catch { }
    }
    return @{ Title = $target.Title; Text = ($lines -join "`n") }
}

function Get-ScreenAnswer {
    param([Parameter(Mandatory)][string]$Question)
    try {
        $context = Get-ActiveWindowText
    } catch {
        $context = @{ Title = 'Active desktop'; Text = '' }
    }
    $request = @{ text = $Question; screenText = "Window: $($context.Title)`n$($context.Text)" }
    $imageData = $null
    if ($context.Text.Length -lt 80) {
        $bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
        $source = [System.Drawing.Bitmap]::new($bounds.Width, $bounds.Height)
        $sourceGraphics = [System.Drawing.Graphics]::FromImage($source)
        $sourceGraphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $scale = [Math]::Min(1.0, 1600.0 / [Math]::Max($bounds.Width, $bounds.Height))
        $previewImage = [System.Drawing.Bitmap]::new([int]($bounds.Width * $scale), [int]($bounds.Height * $scale))
        $previewGraphics = [System.Drawing.Graphics]::FromImage($previewImage)
        $previewGraphics.DrawImage($source, 0, 0, $previewImage.Width, $previewImage.Height)
        $sourceGraphics.Dispose()
        $source.Dispose()

        $memory = [System.IO.MemoryStream]::new()
        $previewImage.Save($memory, [System.Drawing.Imaging.ImageFormat]::Png)
        $imageData = 'data:image/png;base64,' + [Convert]::ToBase64String($memory.ToArray())
        $memory.Dispose()

        $preview = [System.Windows.Forms.Form]::new()
        $preview.Text = 'Review screenshot before sending'
        $preview.StartPosition = 'CenterParent'
        $preview.Size = [System.Drawing.Size]::new(850, 650)
        $picture = [System.Windows.Forms.PictureBox]::new()
        $picture.Dock = 'Fill'
        $picture.SizeMode = 'Zoom'
        $picture.Image = $previewImage
        $footer = [System.Windows.Forms.Panel]::new()
        $footer.Dock = 'Bottom'
        $footer.Height = 76
        $notice = [System.Windows.Forms.Label]::new()
        $notice.Text = 'This screenshot may contain private information. It will be sent to OpenAI only if you choose Send.'
        $notice.Dock = 'Top'
        $notice.AutoSize = $true
        $send = [System.Windows.Forms.Button]::new()
        $send.Text = 'Send to OpenAI'
        $send.Width = 145
        $send.Height = 36
        $send.Location = [System.Drawing.Point]::new(670, 28)
        $send.DialogResult = [System.Windows.Forms.DialogResult]::Yes
        $cancel = [System.Windows.Forms.Button]::new()
        $cancel.Text = 'Cancel'
        $cancel.Width = 90
        $cancel.Height = 36
        $cancel.Location = [System.Drawing.Point]::new(570, 28)
        $cancel.DialogResult = [System.Windows.Forms.DialogResult]::No
        $footer.Controls.Add($notice)
        $footer.Controls.Add($send)
        $footer.Controls.Add($cancel)
        $preview.Controls.Add($picture)
        $preview.Controls.Add($footer)
        $preview.AcceptButton = $send
        $preview.CancelButton = $cancel
        $decision = @{ Send = $false }
        try {
            $form.Invoke([System.Action] {
                $decision.Send = ($preview.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::Yes)
            }) | Out-Null
        } finally {
            $previewImage.Dispose()
            $preview.Dispose()
            $previewGraphics.Dispose()
        }
        if (-not $decision.Send) { return 'Screenshot cancelled. Nothing was sent.' }
        $request.image = $imageData
    }

    $body = $request | ConvertTo-Json -Depth 4 -Compress
    $answer = Invoke-RestMethod -Uri 'http://127.0.0.1:43127/screen' -Method Post -ContentType 'application/json' -Body $body -TimeoutSec 60
    return $answer.answer
}

function Invoke-IntentFromVoice {
    param([Parameter(Mandatory)]$Intent)
    if ($Intent.intent -eq 'unknown') { return $Intent.reply }
    if ($Intent.intent -eq 'screen_question') { return Get-ScreenAnswer -Question $Intent.question }
    if ($Intent.intent -eq 'run_work_tools_routine') { return Show-WorkToolsRoutinePreview -Id 'open_work_tools' }
    if ($Intent.intent -eq 'run_routine') { return Show-WorkToolsRoutinePreview -Id $Intent.routine_id }
    $target = $null
    if ($Intent.intent -in @('minimize_window', 'maximize_window', 'close_window')) {
        if ($state.TargetHandle -ne [IntPtr]::Zero) {
            $target = Get-ActiveTarget -Handle $state.TargetHandle
            if ($target.Title -ne $state.TargetTitle) {
                $state.TargetHandle = [IntPtr]::Zero
                $state.TargetTitle = $null
                throw 'The selected window changed or closed. Choose a target window again.'
            }
        } else {
            $target = Get-ActiveTarget
        }
    }
    if ($Intent.intent -eq 'close_window') {
        $confirmation = @{ Approved = $false }
        $form.Invoke([System.Action] {
            $answer = [System.Windows.Forms.MessageBox]::Show(
                $form, "Close '$($target.Title)'?`r`n`r`n$($Intent.reply)", 'Confirm close window',
                [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning
            )
            $confirmation.Approved = ($answer -eq [System.Windows.Forms.DialogResult]::Yes)
        }) | Out-Null
        if (-not $confirmation.Approved) { return 'Cancelled. The window was not closed.' }
    }
    $actionName = @{
        open_notepad = 'OpenNotepad'; open_calculator = 'OpenCalculator'; open_explorer = 'OpenExplorer'; open_settings = 'OpenSettings'; open_file = 'OpenFile'
        minimize_window = 'MinimizeWindow'; maximize_window = 'MaximizeWindow'; close_window = 'CloseWindow'
        take_screenshot = 'TakeScreenshot'
    }[$Intent.intent]
    if (-not $actionName) { return 'Unknown request. No action was run.' }
    if ($target) { return Invoke-DesktopAction -Name $actionName -TargetHandle $target.Handle }
    return Invoke-DesktopAction -Name $actionName
}

function Get-ValidatedRoutine {
    param([string]$Id)
    $schema = Get-Content (Join-Path $PSScriptRoot 'routine.schema.json') -Raw | ConvertFrom-Json
    $definitions = [System.Collections.Generic.List[object]]::new()
    foreach ($file in @((Join-Path $PSScriptRoot 'routines.json'), (Join-Path $env:LOCALAPPDATA 'VoiceDesk\routines.json'))) {
        if (Test-Path $file) {
            foreach ($definition in @(Get-Content $file -Raw | ConvertFrom-Json)) { $definitions.Add($definition) }
        }
    }
    $allowedActions = @($schema.properties.steps.items.properties.action.enum)
    $validated = [System.Collections.Generic.List[object]]::new()
    foreach ($routine in $definitions) {
        $rootKeys = @($routine.PSObject.Properties.Name)
        if ($routine.version -ne 1 -or $rootKeys.Count -ne 5 -or @('version','id','name','phrases','steps' | Where-Object { $_ -notin $rootKeys }).Count -gt 0) {
            throw 'A routine has an invalid format or unsupported fields.'
        }
        if ($routine.id -notmatch '^[a-z0-9_]{1,64}$' -or [string]::IsNullOrWhiteSpace($routine.name) -or $routine.name.Length -gt 80) {
            throw 'A routine has an invalid ID or name.'
        }
        $phrases = @($routine.phrases)
        if ($phrases.Count -lt 1 -or $phrases.Count -gt 5 -or @($phrases | Where-Object { $_ -isnot [string] -or [string]::IsNullOrWhiteSpace($_) -or $_.Length -gt 100 }).Count -gt 0 -or @($phrases | Select-Object -Unique).Count -ne $phrases.Count) {
            throw "Routine '$($routine.id)' has invalid voice phrases."
        }
        $steps = @($routine.steps)
        if ($steps.Count -lt 1 -or $steps.Count -gt 10) { throw "Routine '$($routine.id)' has an invalid number of steps." }
        foreach ($step in $steps) {
            $stepKeys = @($step.PSObject.Properties.Name)
            if ($stepKeys.Count -ne 1 -or $stepKeys[0] -ne 'action' -or $step.action -notin $allowedActions) {
                throw "Routine '$($routine.id)' contains an unsupported action or field."
            }
        }
        $validated.Add($routine)
    }
    if (-not $Id) { return $validated.ToArray() }
    $match = $validated | Where-Object id -eq $Id | Select-Object -First 1
    if ($match) { return $match }
    throw "Routine '$Id' was not found."
}

function Undo-LastWindowChange {
    $entry = $state.LastUndo
    if (-not $entry) { $lastAction.Text = 'Last action: No reversible window change is available.'; return }
    try {
        $target = Get-ActiveTarget -Handle $entry.Handle
        if ($target.Title -ne $entry.Title) { throw 'The original window is no longer available.' }
        $pattern = $null
        if (-not $target.Element.TryGetCurrentPattern([System.Windows.Automation.WindowPattern]::Pattern, [ref]$pattern)) {
            throw 'The original window no longer supports restoration.'
        }
        if ($pattern.Current.WindowVisualState -ne $entry.AppliedState) {
            throw 'The window state changed after VoiceDesk acted. No undo was applied.'
        }
        $pattern.SetWindowVisualState($entry.PriorState)
        if ($pattern.Current.WindowVisualState -ne $entry.PriorState) { throw 'Windows did not confirm the restored state.' }
        $state.LastUndo = $null
        $undoButton.Enabled = $false
        $lastAction.Text = "Last action: Restored '$($target.Title)' to its prior window state."
    } catch {
        $state.LastUndo = $null
        $undoButton.Enabled = $false
        $lastAction.Text = "Last action: Undo unavailable. $($_.Exception.Message)"
    }
}

function Show-WorkToolsRoutinePreview {
    param([Parameter(Mandatory)][string]$Id)
    $routine = Get-ValidatedRoutine -Id $Id
    $labels = @{ open_notepad = 'Open Notepad'; open_explorer = 'Open File Explorer'; open_calculator = 'Open Calculator'; open_settings = 'Open Windows Settings' }
    $steps = @($routine.steps)
    $previewText = "Run '$($routine.name)'?`r`n`r`n" + (($steps | ForEach-Object { $labels[$_.action] }) -join "`r`n")
    $decision = @{ Approved = $false }
    $form.Invoke([System.Action] {
        $decision.Approved = ([System.Windows.Forms.MessageBox]::Show(
            $form, $previewText, "Preview routine: $($routine.name)", [System.Windows.Forms.MessageBoxButtons]::OKCancel,
            [System.Windows.Forms.MessageBoxIcon]::Information
        ) -eq [System.Windows.Forms.DialogResult]::OK)
    }) | Out-Null
    if (-not $decision.Approved) {
        $form.Invoke([System.Action] { $lastAction.Text = 'Last action: Routine cancelled. Nothing was run.' }) | Out-Null
        return
    }
    $receipt = [System.Collections.Generic.List[string]]::new()
    foreach ($step in $steps) {
        try {
            $result = Invoke-IntentFromVoice -Intent @{ intent = $step.action; reply = $step.label }
            $receipt.Add("Completed: $($labels[$step.action]) — $result")
        } catch {
            $receipt.Add("Failed: $($labels[$step.action]) — $($_.Exception.Message)")
            break
        }
    }
    if ($receipt.Count -lt $steps.Count) { $receipt.Add('Remaining steps were skipped.') }
    $summary = "$($routine.name) — $($receipt.Count) result lines."
    $form.Invoke([System.Action] {
        $lastAction.Text = "Last action: $summary"
        [void][System.Windows.Forms.MessageBox]::Show($form, ($receipt -join "`r`n"), "$($routine.name) — result")
    }) | Out-Null
}

function Show-RoutineEditor {
    param([string]$Id, $Owner = $form)
    $current = if ($Id) { Get-ValidatedRoutine -Id $Id } else { $null }
    $editor = [System.Windows.Forms.Form]::new()
    $editor.Text = if ($current) { 'Edit a local voice routine' } else { 'Create a local voice routine' }
    $editor.StartPosition = 'CenterParent'
    $editor.Size = [System.Drawing.Size]::new(400, 330)
    $panel = [System.Windows.Forms.FlowLayoutPanel]::new()
    $panel.Dock = 'Fill'; $panel.FlowDirection = 'TopDown'; $panel.WrapContents = $false; $panel.Padding = [System.Windows.Forms.Padding]::new(12)
    $nameLabel = [System.Windows.Forms.Label]::new(); $nameLabel.Text = 'Routine name'; $nameLabel.AutoSize = $true
    $nameBox = [System.Windows.Forms.TextBox]::new(); $nameBox.Width = 340
    $phraseLabel = [System.Windows.Forms.Label]::new(); $phraseLabel.Text = 'Spoken phrases (one per line, up to five)'; $phraseLabel.AutoSize = $true
    $phraseBox = [System.Windows.Forms.TextBox]::new(); $phraseBox.Width = 340; $phraseBox.Height = 55; $phraseBox.Multiline = $true
    $actionLabel = [System.Windows.Forms.Label]::new(); $actionLabel.Text = 'Actions (select an item, then move it to set the order)'; $actionLabel.AutoSize = $true
    $actionList = [System.Windows.Forms.CheckedListBox]::new(); $actionList.Width = 340; $actionList.Height = 70
    [void]$actionList.Items.Add('Open Notepad'); [void]$actionList.Items.Add('Open File Explorer'); [void]$actionList.Items.Add('Open Calculator'); [void]$actionList.Items.Add('Open Windows Settings')
    $moveUp = [System.Windows.Forms.Button]::new(); $moveUp.Text = 'Move up'; $moveUp.AutoSize = $true
    $moveDown = [System.Windows.Forms.Button]::new(); $moveDown.Text = 'Move down'; $moveDown.AutoSize = $true
    $orderButtons = [System.Windows.Forms.FlowLayoutPanel]::new(); $orderButtons.AutoSize = $true
    $orderButtons.Controls.Add($moveUp); $orderButtons.Controls.Add($moveDown)
    $moveAction = {
        param([int]$Offset)
        $from = $actionList.SelectedIndex; $to = $from + $Offset
        if ($from -lt 0 -or $to -lt 0 -or $to -ge $actionList.Items.Count) { return }
        $item = $actionList.Items[$from]; $checked = $actionList.GetItemChecked($from)
        $actionList.Items.RemoveAt($from); $actionList.Items.Insert($to, $item)
        $actionList.SetItemChecked($to, $checked); $actionList.SelectedIndex = $to
    }
    $moveUp.add_Click({ & $moveAction -1 })
    $moveDown.add_Click({ & $moveAction 1 })
    if ($current) {
        $nameBox.Text = $current.name; $phraseBox.Lines = @($current.phrases)
        for ($index = 0; $index -lt $actionList.Items.Count; $index++) {
            $actionId = @{ 0 = 'open_notepad'; 1 = 'open_explorer'; 2 = 'open_calculator'; 3 = 'open_settings' }[$index]
            if ($actionId -in @($current.steps | ForEach-Object action)) { $actionList.SetItemChecked($index, $true) }
        }
    }
    $save = [System.Windows.Forms.Button]::new(); $save.Text = 'Save routine'; $save.DialogResult = [System.Windows.Forms.DialogResult]::OK
    $cancel = [System.Windows.Forms.Button]::new(); $cancel.Text = 'Cancel'; $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
    foreach ($control in @($nameLabel,$nameBox,$phraseLabel,$phraseBox,$actionLabel,$actionList,$orderButtons,$save,$cancel)) { $panel.Controls.Add($control) }
    $editor.Controls.Add($panel); $editor.AcceptButton = $save; $editor.CancelButton = $cancel
    try {
        if ($editor.ShowDialog($Owner) -ne [System.Windows.Forms.DialogResult]::OK) { return }
        $name = $nameBox.Text.Trim()
        $phrases = @($phraseBox.Lines | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
        if (-not $name -or $name.Length -gt 80 -or $phrases.Count -lt 1 -or $phrases.Count -gt 5 -or @($phrases | Where-Object { $_.Length -gt 100 }).Count -gt 0 -or @($phrases | Select-Object -Unique).Count -ne $phrases.Count -or $actionList.CheckedItems.Count -eq 0) {
            throw 'Enter a name, one to five unique spoken phrases (one per line), and at least one action.'
        }
        $catalog = @(Get-ValidatedRoutine)
        $conflict = @($catalog | Where-Object { $_.id -ne $Id -and (@($_.phrases | ForEach-Object { $_.Trim().ToLowerInvariant() }) | Where-Object { $_ -in $phrases }).Count -gt 0 })
        if ($conflict.Count -gt 0) {
            throw 'That spoken phrase is already used.'
        }
        $actionIds = @{ 'Open Notepad' = 'open_notepad'; 'Open File Explorer' = 'open_explorer'; 'Open Calculator' = 'open_calculator'; 'Open Windows Settings' = 'open_settings' }
        $steps = @(); for ($index = 0; $index -lt $actionList.Items.Count; $index++) { if ($actionList.GetItemChecked($index)) { $steps += @{ action = $actionIds[[string]$actionList.Items[$index]] } } }
        $routine = @{ version = 1; id = $(if ($current) { $current.id } else { 'user_' + [guid]::NewGuid().ToString('N') }); name = $name; phrases = $phrases; steps = $steps }
        $directory = Join-Path $env:LOCALAPPDATA 'VoiceDesk'
        [void][System.IO.Directory]::CreateDirectory($directory)
        $userFile = Join-Path $directory 'routines.json'
        $existing = @(); if (Test-Path $userFile) { $existing = @(Get-Content $userFile -Raw | ConvertFrom-Json | Where-Object id -ne $routine.id) }
        $tempFile = "$userFile.$([guid]::NewGuid().ToString('N')).tmp"
        [System.IO.File]::WriteAllText($tempFile, (ConvertTo-Json -InputObject @($existing + $routine) -Depth 6), [System.Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $tempFile -Destination $userFile -Force
        $null = Get-ValidatedRoutine -Id $routine.id
        $hint.Text = "Saved '$name'. Say any saved phrase to preview the routine."
    } catch { $lastAction.Text = "Routine not saved: $($_.Exception.Message)" }
    finally { $editor.Dispose() }
}

function Show-RoutineManager {
    $routines = @(Get-ValidatedRoutine | Where-Object id -like 'user_*')
    if ($routines.Count -eq 0) { [void][System.Windows.Forms.MessageBox]::Show($form, 'No user-created routines are saved yet.', 'Manage routines'); return }
    $manager = [System.Windows.Forms.Form]::new()
    $manager.Text = 'Manage local routines'; $manager.StartPosition = 'CenterParent'; $manager.Size = [System.Drawing.Size]::new(420, 300)
    $list = [System.Windows.Forms.ListBox]::new(); $list.Dock = 'Fill'; $list.DisplayMember = 'Display'
    foreach ($routine in $routines) { [void]$list.Items.Add([pscustomobject]@{ Id = $routine.id; Display = "$($routine.name) — $($routine.phrases -join ', ')" }) }
    $edit = [System.Windows.Forms.Button]::new(); $edit.Text = 'Edit selected'; $edit.AutoSize = $true
    $remove = [System.Windows.Forms.Button]::new(); $remove.Text = 'Delete selected'; $remove.AutoSize = $true
    $close = [System.Windows.Forms.Button]::new(); $close.Text = 'Close'; $close.AutoSize = $true
    $buttons = [System.Windows.Forms.FlowLayoutPanel]::new(); $buttons.Dock = 'Bottom'; $buttons.AutoSize = $true
    $buttons.Controls.Add($edit); $buttons.Controls.Add($remove); $buttons.Controls.Add($close); $manager.Controls.Add($list); $manager.Controls.Add($buttons)
    $edit.add_Click({
        if (-not $list.SelectedItem) { return }
        $item = $list.SelectedItem
        Show-RoutineEditor -Id $item.Id -Owner $manager
        try {
            $updated = Get-ValidatedRoutine -Id $item.Id
            $item.Display = "$($updated.name) — $($updated.phrases -join ', ')"
            $list.Refresh()
        } catch { }
    })
    $remove.add_Click({
        if (-not $list.SelectedItem) { return }
        $item = $list.SelectedItem
        $answer = [System.Windows.Forms.MessageBox]::Show($manager, "Delete '$($item.Display)'?", 'Confirm routine deletion', [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Warning)
        if ($answer -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        try {
            $userFile = Join-Path $env:LOCALAPPDATA 'VoiceDesk\routines.json'
            $remaining = @((Get-Content $userFile -Raw | ConvertFrom-Json) | Where-Object id -ne $item.Id)
            $tempFile = "$userFile.$([guid]::NewGuid().ToString('N')).tmp"
            [System.IO.File]::WriteAllText($tempFile, (ConvertTo-Json -InputObject $remaining -Depth 6), [System.Text.UTF8Encoding]::new($false))
            Move-Item -LiteralPath $tempFile -Destination $userFile -Force
            [void]$list.Items.Remove($item)
            $lastAction.Text = "Last action: Deleted routine '$($item.Display.Split('—')[0].Trim())'."
        } catch { $lastAction.Text = "Routine not deleted: $($_.Exception.Message)" }
    })
    $close.add_Click({ $manager.Close() })
    try { [void]$manager.ShowDialog($form) } finally { $manager.Dispose() }
}

[System.Windows.Forms.Application]::EnableVisualStyles()
$culture = (Get-Culture).Name
$recognizerInfo = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
    Where-Object { $_.Culture.Name -eq $culture } |
    Select-Object -First 1

$form = [System.Windows.Forms.Form]::new()
$form.Text = 'VoiceDesk'
$form.StartPosition = 'CenterScreen'
$form.Size = [System.Drawing.Size]::new(500, 430)
$form.MinimumSize = [System.Drawing.Size]::new(440, 390)
$form.Font = [System.Drawing.Font]::new('Segoe UI', 10)

$layout = [System.Windows.Forms.TableLayoutPanel]::new()
$layout.Dock = 'Fill'
$layout.AutoScroll = $true
$layout.Padding = [System.Windows.Forms.Padding]::new(20)
$layout.ColumnCount = 1
$layout.RowCount = 11
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('Percent', 100))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))

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
$aiToggle = [System.Windows.Forms.CheckBox]::new()
$aiToggle.Text = 'Enable cloud AI for natural-language and screen questions'
$aiToggle.AutoSize = $true
$aiToggle.Checked = $false
$speakToggle = [System.Windows.Forms.CheckBox]::new()
$speakToggle.Text = 'Speak responses aloud using a local Windows voice'
$speakToggle.AutoSize = $true
$speakToggle.Checked = $false
$lastAction = [System.Windows.Forms.Label]::new()
$lastAction.Text = 'Last action: none'
$lastAction.AutoSize = $true
$lastAction.MaximumSize = [System.Drawing.Size]::new(400, 0)
$listenButton = [System.Windows.Forms.Button]::new()
$listenButton.Text = 'Start listening'
$listenButton.AutoSize = $true
$listenButton.MinimumSize = [System.Drawing.Size]::new(180, 42)
$commands = [System.Windows.Forms.Label]::new()
$commands.Text = 'With cloud AI off, speech stays on this PC and only exact basic commands run. Enabling AI can send recognized text and requested screen content to OpenAI; API charges may apply.'
$commands.AutoSize = $true
$commands.MaximumSize = [System.Drawing.Size]::new(400, 0)
$cameraStatus = [System.Windows.Forms.Label]::new()
$cameraStatus.Text = 'Camera off'
$cameraStatus.AutoSize = $true
$gestureButton = [System.Windows.Forms.Button]::new()
$gestureButton.Text = 'Start camera gestures'
$gestureButton.AutoSize = $true
$gestureButton.MinimumSize = [System.Drawing.Size]::new(180, 38)
$stopAllButton = [System.Windows.Forms.Button]::new()
$stopAllButton.Text = 'Stop all capture'
$stopAllButton.AutoSize = $true
$stopAllButton.MinimumSize = [System.Drawing.Size]::new(180, 38)
$targetStatus = [System.Windows.Forms.Label]::new()
$targetStatus.Text = 'Window target: foreground window'
$targetStatus.AutoSize = $true
$targetButton = [System.Windows.Forms.Button]::new()
$targetButton.Text = 'Choose target window'
$targetButton.AutoSize = $true
$pauseGestureToggle = [System.Windows.Forms.CheckBox]::new()
$pauseGestureToggle.Text = 'Allow fist gesture to pause voice'
$pauseGestureToggle.AutoSize = $true
$pauseGestureToggle.Checked = $true
$resumeGestureToggle = [System.Windows.Forms.CheckBox]::new()
$resumeGestureToggle.Text = 'Allow open-palm gesture to resume voice'
$resumeGestureToggle.AutoSize = $true
$resumeGestureToggle.Checked = $true
$contextToggle = [System.Windows.Forms.CheckBox]::new()
$contextToggle.Text = 'Keep up to three cloud voice turns for follow-up requests (session only)'
$contextToggle.AutoSize = $true
$contextToggle.Checked = $false
$clearContextButton = [System.Windows.Forms.Button]::new()
$clearContextButton.Text = 'Clear conversation context'
$clearContextButton.AutoSize = $true
$routineButton = [System.Windows.Forms.Button]::new()
$routineButton.Text = 'Preview routine: Open work tools'
$routineButton.AutoSize = $true
$createRoutineButton = [System.Windows.Forms.Button]::new()
$createRoutineButton.Text = 'Create local routine'
$createRoutineButton.AutoSize = $true
$manageRoutineButton = [System.Windows.Forms.Button]::new()
$manageRoutineButton.Text = 'Manage local routines'
$manageRoutineButton.AutoSize = $true
$undoButton = [System.Windows.Forms.Button]::new()
$undoButton.Text = 'Undo last window change'
$undoButton.AutoSize = $true
$undoButton.Enabled = $false

$layout.Controls.Add($status, 0, 0)
$layout.Controls.Add($hint, 0, 1)
$layout.Controls.Add($aiToggle, 0, 2)
$layout.Controls.Add($speakToggle, 0, 3)
$layout.Controls.Add($transcript, 0, 4)
$layout.Controls.Add($lastAction, 0, 5)
$layout.Controls.Add($listenButton, 0, 6)
$layout.Controls.Add($commands, 0, 7)
$layout.Controls.Add($cameraStatus, 0, 8)
$layout.Controls.Add($gestureButton, 0, 9)
$layout.Controls.Add($stopAllButton, 0, 10)
$layout.RowCount = 21
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
[void]$layout.RowStyles.Add([System.Windows.Forms.RowStyle]::new('AutoSize'))
$layout.Controls.Add($targetStatus, 0, 11)
$layout.Controls.Add($targetButton, 0, 12)
$layout.Controls.Add($pauseGestureToggle, 0, 13)
$layout.Controls.Add($resumeGestureToggle, 0, 14)
$layout.Controls.Add($contextToggle, 0, 15)
$layout.Controls.Add($clearContextButton, 0, 16)
$layout.Controls.Add($routineButton, 0, 17)
$layout.Controls.Add($undoButton, 0, 18)
$layout.Controls.Add($createRoutineButton, 0, 19)
$layout.Controls.Add($manageRoutineButton, 0, 20)
$form.Controls.Add($layout)
$state = @{ Listening = $false; MicrophoneReady = $false; Busy = $false; RecognitionStopped = $false; ResumeAfterAction = $false; GesturePaused = $false; GestureProcess = $null; GesturesActive = $false; AiEnabled = $false; ContextEnabled = $false; Context = @(); TargetHandle = [IntPtr]::Zero; TargetTitle = $null; LastUndo = $null }

function Stop-AllCapture {
    $state.GesturePaused = $false
    $state.ResumeAfterAction = $false
    if ($state.Speaking -and $speaker) {
        try { $speaker.SpeakAsyncCancelAll() } catch {}
        $state.Speaking = $false
    }
    if ($state.Listening -and $recognizer) {
        try { $recognizer.RecognizeAsyncCancel() } catch {}
    }
    if ($state.GestureProcess) {
        try { $state.GestureProcess.Kill() } catch {}
    }
    $state.GesturesActive = $false
    $cameraStatus.Text = 'Camera off'
    $gestureButton.Text = 'Start camera gestures'
    $hint.Text = 'Voice and camera capture stopped.'
}
$stopAllButton.add_Click({ Stop-AllCapture })

$targetButton.add_Click({
    try {
        $root = [System.Windows.Automation.AutomationElement]::RootElement
        $windows = $root.FindAll([System.Windows.Automation.TreeScope]::Children, [System.Windows.Automation.Condition]::TrueCondition)
        $choices = [System.Collections.Generic.List[object]]::new()
        $choices.Add([pscustomobject]@{ Title = 'Foreground window (default)'; Handle = [IntPtr]::Zero })
        for ($index = 0; $index -lt $windows.Count; $index++) {
            try {
                $element = $windows.Item($index)
                $title = $element.Current.Name
                $handle = [IntPtr]$element.Current.NativeWindowHandle
                if ($handle -ne [IntPtr]::Zero -and $handle -ne $form.Handle -and -not [string]::IsNullOrWhiteSpace($title) -and -not $element.Current.IsOffscreen) {
                    $choices.Add([pscustomobject]@{ Title = $title; Handle = $handle })
                }
            } catch { }
        }
        if ($choices.Count -eq 0) { throw 'No visible windows were found.' }

        $picker = [System.Windows.Forms.Form]::new()
        $picker.Text = 'Choose a window target'
        $picker.StartPosition = 'CenterParent'
        $picker.Size = [System.Drawing.Size]::new(480, 360)
        $list = [System.Windows.Forms.ListBox]::new()
        $list.Dock = 'Fill'
        $list.DisplayMember = 'Title'
        foreach ($choice in $choices) { [void]$list.Items.Add($choice) }
        $buttons = [System.Windows.Forms.FlowLayoutPanel]::new()
        $buttons.Dock = 'Bottom'
        $buttons.Height = 48
        $select = [System.Windows.Forms.Button]::new()
        $select.Text = 'Use selected window'
        $select.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $cancel = [System.Windows.Forms.Button]::new()
        $cancel.Text = 'Cancel'
        $cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $buttons.Controls.Add($select)
        $buttons.Controls.Add($cancel)
        $picker.Controls.Add($list)
        $picker.Controls.Add($buttons)
        $picker.AcceptButton = $select
        $picker.CancelButton = $cancel
        try {
            if ($choices.Count -gt 0) { $list.SelectedIndex = 0 }
            if ($picker.ShowDialog($form) -eq [System.Windows.Forms.DialogResult]::OK -and $list.SelectedItem) {
                $state.TargetHandle = $list.SelectedItem.Handle
                $state.TargetTitle = $list.SelectedItem.Title
                $targetStatus.Text = if ($state.TargetHandle -eq [IntPtr]::Zero) { 'Window target: foreground window' } else { "Window target: $($state.TargetTitle)" }
            }
        } finally { $picker.Dispose() }
    } catch {
        $lastAction.Text = "Window picker: $($_.Exception.Message)"
    }
})
$pauseGestureToggle.add_CheckedChanged({ $state.GesturePauseEnabled = $pauseGestureToggle.Checked })
$resumeGestureToggle.add_CheckedChanged({ $state.GestureResumeEnabled = $resumeGestureToggle.Checked })
$state.GesturePauseEnabled = $pauseGestureToggle.Checked
$state.GestureResumeEnabled = $resumeGestureToggle.Checked
$contextToggle.add_CheckedChanged({
    $state.ContextEnabled = $contextToggle.Checked
    if (-not $state.ContextEnabled) { $state.Context = @() }
})
$clearContextButton.add_Click({
    $state.Context = @()
    $hint.Text = 'Cloud conversation context cleared.'
})
$routineButton.add_Click({ Show-WorkToolsRoutinePreview -Id 'open_work_tools' })
$createRoutineButton.add_Click({ Show-RoutineEditor })
$manageRoutineButton.add_Click({ Show-RoutineManager })
$undoButton.add_Click({ Undo-LastWindowChange })

if (-not $recognizerInfo) {
    $hint.Text = "No Windows speech recognizer is installed for '$culture'. Install the matching speech language in Windows Settings."
    $listenButton.Enabled = $false
} else {
    try {
        $recognizer = [System.Speech.Recognition.SpeechRecognitionEngine]::new($recognizerInfo)
        $speaker = [System.Speech.Synthesis.SpeechSynthesizer]::new()
        $recognizer.LoadGrammar([System.Speech.Recognition.DictationGrammar]::new())
        try {
            $recognizer.SetInputToDefaultAudioDevice()
            $state.MicrophoneReady = $true
        } catch {
            $hint.Text = "Microphone unavailable. Connect or enable one and check Windows microphone privacy settings. $($_.Exception.Message)"
        }

        function Start-VoiceListening {
            if ($state.Listening) { return }
            if (-not $state.MicrophoneReady) {
                try {
                    $recognizer.SetInputToDefaultAudioDevice()
                    $state.MicrophoneReady = $true
                } catch {
                    throw "Microphone unavailable. Connect or enable one, check Windows microphone privacy settings, then retry. $($_.Exception.Message)"
                }
            }
            $state.Listening = $true
            $state.RecognitionStopped = $false
            $status.Text = 'Listening…'
            $hint.Text = if ($state.AiEnabled) { 'Listening. Cloud AI is enabled for non-exact requests and screen questions.' } else { 'Listening locally. Cloud AI is off; only exact basic commands will run.' }
            $listenButton.Text = 'Stop listening'
            $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
        }
        function Resume-VoiceWhenReady {
            if ($state.Busy -or $state.Speaking -or -not $state.RecognitionStopped) { return }
            $state.RecognitionStopped = $false
            if ($state.ResumeAfterAction) {
                $state.ResumeAfterAction = $false
                try { Start-VoiceListening } catch {
                    $state.Listening = $false
                    $status.Text = 'Microphone off'
                    $listenButton.Text = 'Start listening'
                    $hint.Text = "Could not resume listening: $($_.Exception.Message)"
                }
            } else {
                $status.Text = 'Microphone off'
                $listenButton.Text = 'Start listening'
                $hint.Text = 'Press Start listening before speaking.'
            }
        }
        function Stop-VoiceListening {
            if ($state.Listening) { $recognizer.RecognizeAsyncCancel() }
        }
        $aiToggle.add_CheckedChanged({
            $state.AiEnabled = $aiToggle.Checked
            if ($state.AiEnabled) {
                try {
                    Invoke-RestMethod -Uri 'http://127.0.0.1:43127/health' -Method Get -TimeoutSec 2 | Out-Null
                    $hint.Text = 'Cloud AI is ready. Non-exact requests and screen questions may be sent to OpenAI.'
                } catch {
                    $state.AiEnabled = $false
                    $aiToggle.Checked = $false
                    $hint.Text = 'AI service is not running. Start it using the Optional AI intent service steps in README.md.'
                }
            }
        })

        $recognizer.add_SpeechRecognitionRejected({
            $form.BeginInvoke([System.Action] {
                $transcript.Text = 'Heard: (no supported command recognized)'
            }) | Out-Null
        })
        $recognizer.add_SpeechRecognized({
            param($sender, $eventArgs)
            if ($state.Busy -or -not $state.Listening) { return }
            $command = $eventArgs.Result.Text
            $confidence = $eventArgs.Result.Confidence
            $form.BeginInvoke([System.Action] {
                $transcript.Text = ("Heard: {0} ({1:P0} confidence)" -f $command, $confidence)
            }) | Out-Null

            if ($confidence -lt 0.60) {
                $result = 'Ignored: recognition confidence was too low.'
            } else {
                $isStopCommand = $command.Trim().ToLowerInvariant() -eq 'stop listening'
                $state.ResumeAfterAction = -not $isStopCommand
                if (-not $isStopCommand) {
                    $state.Busy = $true
                    $state.RecognitionStopped = $false
                }
                $sender.RecognizeAsyncCancel()
                if (-not $isStopCommand) {
                    $form.BeginInvoke([System.Action] {
                        $status.Text = 'Processing request…'
                        $hint.Text = 'Listening pauses while this request runs.'
                    }) | Out-Null
                }
                try {
                    if ($isStopCommand) {
                        $result = 'Listening stopped.'
                    } else {
                        $intent = Resolve-VoiceIntent -Text $command
                        $result = Invoke-IntentFromVoice -Intent $intent
                        if ($intent.used_cloud_ai -and $state.ContextEnabled -and $intent.intent -ne 'screen_question') {
                            $form.Invoke([System.Action] {
                                $state.Context += @(@{ role = 'user'; content = $command }, @{ role = 'assistant'; content = $result })
                                if ($state.Context.Count -gt 6) { $state.Context = @($state.Context | Select-Object -Last 6) }
                            }) | Out-Null
                        }
                    }
                } catch {
                    $result = "No action was run: $($_.Exception.Message)"
                }
            }
            $form.BeginInvoke([System.Action] {
                $lastAction.Text = "Last action: $result"
                if ($state.Busy) {
                    $state.Busy = $false
                    if ($speakToggle.Checked -and $result -ne 'Listening stopped.') {
                        $state.Speaking = $true
                        try { $speaker.SpeakAsync($result) } catch {
                            $state.Speaking = $false
                            $lastAction.Text = "Last action: $result (speech output failed)"
                            Resume-VoiceWhenReady
                        }
                    } else {
                        Resume-VoiceWhenReady
                    }
                }
            }) | Out-Null
        })
        $recognizer.add_RecognizeCompleted({
            param($sender, $eventArgs)
            $message = if ($eventArgs.Error) { "Recognition error: $($eventArgs.Error.Message)" } else { 'Microphone off' }
            $form.BeginInvoke([System.Action] {
                $state.Listening = $false
                $state.RecognitionStopped = $true
                if ($state.Busy) {
                    $status.Text = 'Processing request…'
                    $listenButton.Text = 'Processing…'
                } else {
                    if ($eventArgs.Error) {
                        $state.MicrophoneReady = $false
                        $state.ResumeAfterAction = $false
                        $state.RecognitionStopped = $false
                        $status.Text = $message
                        $listenButton.Text = 'Start listening'
                        $hint.Text = 'Check microphone access and try again.'
                    } else {
                        Resume-VoiceWhenReady
                    }
                }
            }) | Out-Null
        })
        $speaker.add_SpeakCompleted({
            param($sender, $eventArgs)
            $form.BeginInvoke([System.Action] {
                $state.Speaking = $false
                if ($eventArgs.Error) { $lastAction.Text += ' (speech output failed)' }
                Resume-VoiceWhenReady
            }) | Out-Null
        })

        $listenButton.add_Click({
            if ($state.Speaking) {
                $state.ResumeAfterAction = $false
                try { $speaker.SpeakAsyncCancelAll() } catch {}
                $state.Speaking = $false
                $hint.Text = 'Speech stopped; voice listening will remain off.'
                Resume-VoiceWhenReady
                return
            }
            if ($state.Busy) {
                $state.ResumeAfterAction = $false
                $hint.Text = 'Current request will finish; listening will stay off.'
                return
            }
            if ($state.Listening) {
                $state.GesturePaused = $false
                $state.ResumeAfterAction = $false
                $recognizer.RecognizeAsyncCancel()
                $hint.Text = 'Stopping microphone…'
            } else {
                try {
                    Start-VoiceListening
                } catch {
                    $state.Listening = $false
                    $status.Text = 'Microphone off'
                    $listenButton.Text = 'Start listening'
                    $hint.Text = "Could not start listening: $($_.Exception.Message)"
                }
            }
        })
        $gestureButton.add_Click({
            if ($state.GesturesActive -and $state.GestureProcess) {
                try { $state.GestureProcess.Kill() } catch {}
                $state.GesturesActive = $false
                $state.GesturePaused = $false
                $cameraStatus.Text = 'Camera off'
                $gestureButton.Text = 'Start camera gestures'
                return
            }
            try {
                $venvPython = Join-Path $PSScriptRoot '.venv\Scripts\python.exe'
                if (Test-Path $venvPython) {
                    $pythonPath = $venvPython
                } else {
                    $python = Get-Command python -ErrorAction SilentlyContinue
                    if (-not $python) { $python = Get-Command py -ErrorAction Stop }
                    $pythonPath = $python.Source
                }
                $pythonArgs = '-u'
                if ($pythonPath -eq (Get-Command py -ErrorAction SilentlyContinue).Source) {
                    $pythonArgs = '-3 -u'
                }
                $start = [System.Diagnostics.ProcessStartInfo]::new()
                $start.FileName = $pythonPath
                $start.Arguments = "$pythonArgs `"$(Join-Path $PSScriptRoot 'gesture_service.py')`""
                $start.UseShellExecute = $false
                $start.CreateNoWindow = $true
                $start.RedirectStandardOutput = $true
                $start.RedirectStandardError = $true
                $process = [System.Diagnostics.Process]::new()
                $process.StartInfo = $start
                $process.add_OutputDataReceived({
                    param($sender, $eventArgs)
                    $line = $eventArgs.Data
                    if (-not $line) { return }
                    $form.BeginInvoke([System.Action] {
                        switch ($line) {
                            'CAMERA_ACTIVE' {
                                $state.GesturesActive = $true
                                $cameraStatus.Text = 'Camera active (local processing)'
                                $gestureButton.Text = 'Stop camera gestures'
                            }
                            'PAUSE_VOICE' {
                                if ($state.GesturePauseEnabled -and $state.Listening) {
                                    $state.GesturePaused = $true
                                    Stop-VoiceListening
                                    $hint.Text = 'Gesture paused voice listening. Show an open palm to resume.'
                                }
                            }
                            'RESUME_VOICE' {
                                if ($state.GestureResumeEnabled -and $state.GesturePaused) {
                                    $state.GesturePaused = $false
                                    try { Start-VoiceListening } catch { $hint.Text = "Gesture could not resume voice: $($_.Exception.Message)" }
                                }
                            }
                            'CAMERA_STOPPED' {
                                $state.GesturesActive = $false
                                $cameraStatus.Text = 'Camera off'
                                $gestureButton.Text = 'Start camera gestures'
                            }
                            default {
                                if ($line.StartsWith('ERROR:')) {
                                    $cameraStatus.Text = 'Camera error'
                                    $lastAction.Text = $line
                                }
                            }
                        }
                    }) | Out-Null
                })
                $process.add_ErrorDataReceived({
                    param($sender, $eventArgs)
                    if ($eventArgs.Data) {
                        $line = $eventArgs.Data
                        $form.BeginInvoke([System.Action] { $cameraStatus.Text = "Camera setup error: $line" }) | Out-Null
                    }
                })
                $process.add_Exited({
                    $form.BeginInvoke([System.Action] {
                        $state.GesturesActive = $false
                        $state.GesturePaused = $false
                        $cameraStatus.Text = 'Camera off'
                        $gestureButton.Text = 'Start camera gestures'
                    }) | Out-Null
                })
                $process.Start() | Out-Null
                $state.GestureProcess = $process
                $state.GesturesActive = $true
                $cameraStatus.Text = 'Starting camera…'
                $gestureButton.Text = 'Stop camera gestures'
                $process.BeginOutputReadLine()
                $process.BeginErrorReadLine()
            } catch {
                $state.GesturesActive = $false
                $state.GestureProcess = $null
                $cameraStatus.Text = 'Camera off'
                $gestureButton.Text = 'Start camera gestures'
                $lastAction.Text = "Could not start gestures: $($_.Exception.Message)"
            }
        })
        $form.add_FormClosing({
            Stop-AllCapture
            if ($recognizer) {
                try { $recognizer.RecognizeAsyncCancel() } catch {}
                $recognizer.Dispose()
            }
            if ($speaker) { $speaker.Dispose() }
        })
    } catch {
        $hint.Text = "Voice recognition setup failed: $($_.Exception.Message)"
        $listenButton.Enabled = $false
    }
}

[void]$form.ShowDialog()
