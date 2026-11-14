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

Press **Start listening** before speaking. Press **Stop listening**, say “Stop listening”, or close the app to stop microphone capture. Windows speech recognition transcribes locally. Exact basic commands are handled locally; other recognized requests are sent to OpenAI for intent interpretation. Internet access and API usage charges may apply. VoiceDesk shows the recognized phrase and last action, reports microphone/recognition errors, and ignores recognized phrases below its confidence threshold. “Open file” opens a picker and only accepts common document and image formats; voice text is never treated as a path. Window commands identify the foreground window and use Windows UI Automation when available, with a keyboard shortcut fallback; the target title is shown in the action result. If VoiceDesk itself is active, select the window you mean to control and repeat the command. “Close window” always asks for confirmation and may show the target app's save prompt. “Take screenshot” sends Print Screen but does not save an image. VoiceDesk intentionally has no shutdown or arbitrary shell command.

## Optional AI intent service

Natural-language requests use a small local Node.js service that holds the OpenAI API key outside VoiceDesk and the repository. Install Node.js, set `OPENAI_API_KEY` and `VOICEDESK_MODEL` in your Windows user environment, then start the service in one PowerShell window:

```powershell
node .\ai-service\server.mjs
```

Start VoiceDesk in another PowerShell window. Keep the API key out of source files, command history, screenshots, and Git. Create/manage API keys in your OpenAI API account; API usage is billed separately from a ChatGPT subscription. The local service accepts requests only on `127.0.0.1`. Without it, exact basic commands still work and other requests show an error without running an action.

## Scope

AI output is a proposed intent from a fixed schema. VoiceDesk validates the intent and maps it to its own allowlisted actions; model output is never executed as shell code. Unknown requests result in a clarifying response, and closing a window requires an explicit confirmation. This remains a prototype, not an unrestricted desktop agent.

## License

MIT. See [LICENSE](LICENSE).
