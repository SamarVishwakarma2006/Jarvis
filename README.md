# VoiceDesk

A small Windows desktop voice-control prototype. VoiceDesk listens for a fixed set of spoken commands and maps them to familiar desktop actions. It uses Windows' installed speech recognition engine and does not send audio to an AI service.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1
- A microphone and an installed Windows speech recognizer for your current language

## Run

Open PowerShell in this folder and run:

```powershell
.\VoiceDesk.ps1
```

If PowerShell blocks the script, you can allow it for this process only:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\VoiceDesk.ps1
```

Say one of these commands:

- “Open Notepad”
- “Open Calculator”
- “Minimize window”
- “Maximize window”
- “Close window”
- “Take screenshot” (sends Print Screen)
- “Stop listening”

Use `Ctrl+C` to exit at any time. “Close window” sends `Alt+F4` to the foreground window, so save your work first. VoiceDesk intentionally has no shutdown, arbitrary shell, or arbitrary file-opening command in this prototype.

## Scope

This is an initial, local voice-command foundation, not an AI agent. It uses a fixed grammar and action allowlist; it cannot understand open-ended requests. The next steps are a confirmation flow for sensitive actions, explicit file selection, better feedback, and then optional AI intent parsing and camera gestures.

## License

MIT. See [LICENSE](LICENSE).
