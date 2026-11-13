$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
Add-Type -AssemblyName System.Windows.Forms

$culture = (Get-Culture).Name
$recognizerInfo = [System.Speech.Recognition.SpeechRecognitionEngine]::InstalledRecognizers() |
    Where-Object { $_.Culture.Name -eq $culture } |
    Select-Object -First 1

if (-not $recognizerInfo) {
    throw "No Windows speech recognizer is installed for '$culture'. Install that speech language in Windows Settings, or change your Windows display/speech language to one with an installed recognizer."
}

$recognizer = $null
$finished = $null

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
        throw "VoiceDesk could not access the default microphone. Connect or enable a microphone, check Windows microphone privacy settings, and try again. Details: $($_.Exception.Message)"
    }

    $finished = [System.Threading.ManualResetEventSlim]::new()
    $recognizer.add_SpeechRecognitionRejected({
        Write-Host 'Did not recognize a supported command. Try one of the commands listed in README.md.' -ForegroundColor Yellow
    })
    $recognizer.add_SpeechRecognized({
        param($sender, $eventArgs)
        $command = $eventArgs.Result.Text
        $confidence = $eventArgs.Result.Confidence
        Write-Host ("Heard: {0} (confidence {1:P0})" -f $command, $confidence)

        if ($confidence -lt 0.60) {
            Write-Host 'Ignored: recognition confidence was too low.' -ForegroundColor Yellow
            return
        }

        try {
            switch ($command) {
                'open notepad' {
                    Start-Process notepad
                    Write-Host 'Action: opened Notepad.' -ForegroundColor Green
                }
                'open calculator' {
                    Start-Process calc
                    Write-Host 'Action: opened Calculator.' -ForegroundColor Green
                }
                'minimize window' {
                    [System.Windows.Forms.SendKeys]::SendWait('% n')
                    Write-Host 'Action: sent the minimize shortcut to the active window.' -ForegroundColor Green
                }
                'maximize window' {
                    [System.Windows.Forms.SendKeys]::SendWait('% x')
                    Write-Host 'Action: sent the maximize shortcut to the active window.' -ForegroundColor Green
                }
                'close window' {
                    [System.Windows.Forms.SendKeys]::SendWait('%{F4}')
                    Write-Host 'Action: sent the close shortcut to the active window. Save your work if prompted.' -ForegroundColor Yellow
                }
                'take screenshot' {
                    [System.Windows.Forms.SendKeys]::SendWait('{PRTSC}')
                    Write-Host 'Action: sent Print Screen. VoiceDesk does not save the image to a file.' -ForegroundColor Green
                }
                'stop listening' {
                    Write-Host 'Stopping voice recognition.'
                    $sender.RecognizeAsyncCancel()
                }
                default {
                    Write-Host 'Ignored: command is not allowlisted.' -ForegroundColor Yellow
                }
            }
        } catch {
            Write-Host "Action failed: $($_.Exception.Message)" -ForegroundColor Red
        }
    })
    $recognizer.add_RecognizeCompleted({
        param($sender, $eventArgs)
        if ($eventArgs.Error) {
            Write-Host "Voice recognition stopped with an error: $($eventArgs.Error.Message)" -ForegroundColor Red
        }
        $finished.Set()
    })

    Write-Host 'VoiceDesk is listening. Say a supported command or "stop listening".' -ForegroundColor Cyan
    Write-Host 'Press Ctrl+C to exit. "Close window" affects the active window.'
    $recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
    $finished.Wait()
} finally {
    if ($recognizer) { $recognizer.Dispose() }
    if ($finished) { $finished.Dispose() }
    Write-Host 'VoiceDesk stopped.'
}
