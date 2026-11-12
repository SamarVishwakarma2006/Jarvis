Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms

$recognizerInfo = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
    Where-Object { $_.Culture.Name -eq (Get-Culture).Name } |
    Select-Object -First 1

if (-not $recognizerInfo) {
    throw "No Windows speech recognizer is installed for $((Get-Culture).Name). Install a matching Windows speech language and try again."
}

$recognizer = [System.Speech.Recognition.SpeechRecognitionEngine]::new($recognizerInfo)
$choices = [System.Speech.Recognition.Choices]::new(
    'open notepad', 'open calculator', 'minimize window', 'maximize window',
    'close window', 'take screenshot', 'stop listening'
)
$builder = [System.Speech.Recognition.GrammarBuilder]::new()
$builder.Append($choices)
$recognizer.LoadGrammar([System.Speech.Recognition.Grammar]::new($builder))
$recognizer.SetInputToDefaultAudioDevice()
$finished = [System.Threading.ManualResetEventSlim]::new()

$recognizer.add_SpeechRecognized({
    param($sender, $eventArgs)
    $command = $eventArgs.Result.Text
    Write-Host "Heard: $command"

    switch ($command) {
        'open notepad' { Start-Process notepad }
        'open calculator' { Start-Process calc }
        'minimize window' { [System.Windows.Forms.SendKeys]::SendWait('% n') }
        'maximize window' { [System.Windows.Forms.SendKeys]::SendWait('% x') }
        'close window' { [System.Windows.Forms.SendKeys]::SendWait('%{F4}') }
        'take screenshot' { [System.Windows.Forms.SendKeys]::SendWait('{PRTSC}') }
        'stop listening' { $sender.RecognizeAsyncCancel() }
    }
})
$recognizer.add_RecognizeCompleted({ $finished.Set() })

Write-Host 'VoiceDesk is listening. Say a command or "stop listening".'
Write-Host 'Press Ctrl+C to exit.'
$recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)

try {
    $finished.Wait()
} finally {
    $recognizer.Dispose()
    $finished.Dispose()
    Write-Host 'VoiceDesk stopped.'
}
