# VoiceDesk

A small Windows desktop voice-control prototype. VoiceDesk listens for a fixed set of spoken commands and maps them to familiar desktop actions. Its window shows microphone status, recognized speech, the last action, and start/stop controls. It uses Windows' installed speech recognition engine and does not send audio to an AI service.

See [ROADMAP.md](ROADMAP.md) for the GitHub-tracked steps toward a more capable assistant.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1
- .NET Framework components included with Windows PowerShell (System.Speech and Windows Forms)
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
- “Open file” (opens a picker for common document and image formats)
- “Minimize window”
- “Maximize window”
- “Close window”
- “Take screenshot” (sends Print Screen)
- “Stop listening”

Press **Start listening** before speaking. Press **Stop listening**, say “Stop listening”, or close the app to stop microphone capture. VoiceDesk shows the recognized phrase and last action, reports microphone/recognition errors, and ignores recognized phrases below its confidence threshold. “Open file” opens a picker and only accepts common document and image formats; voice text is never treated as a path. Window commands identify the foreground window and use Windows UI Automation when available, with a keyboard shortcut fallback; the target title is shown in the action result. If VoiceDesk itself is active, select the window you mean to control and repeat the command. “Close window” may close the target or show its save prompt, so save your work first. “Take screenshot” sends Print Screen but does not save an image. VoiceDesk intentionally has no shutdown or arbitrary shell command in this prototype.

## Scope

This is an initial, local voice-command foundation, not an AI agent. It uses a fixed grammar and action allowlist; it cannot understand open-ended requests. The next steps are a confirmation flow for sensitive actions, explicit file selection, better feedback, and then optional AI intent parsing and camera gestures.

## License

MIT. See [LICENSE](LICENSE).
