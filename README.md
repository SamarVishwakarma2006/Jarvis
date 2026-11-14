# VoiceDesk

A Windows desktop voice-control prototype with an allowlisted set of desktop actions. Exact commands work locally; optional AI maps natural-language requests to those actions. Speech recognition runs on Windows, so raw microphone audio is not sent to the AI service. The app shows microphone status, recognized speech, and action results.

See [ROADMAP.md](ROADMAP.md) for the GitHub-tracked steps toward a more capable assistant.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1
- .NET Framework components included with Windows PowerShell (System.Speech and Windows Forms)
- A microphone and an installed Windows speech recognizer for your current language

## Run

For the source preview, extract the GitHub release ZIP and double-click `Run-VoiceDesk.cmd`. Or open PowerShell in this folder and run:

```powershell
.\VoiceDesk.ps1
```

The launcher allows the script for this process only; it does not change the machine's execution policy.

## Optional features

The core voice commands do not require Node.js or Python. To enable natural-language AI and screen questions, follow [Optional AI intent service](#optional-ai-intent-service). To enable hand gestures, install Python 3.10–3.12 and create an isolated environment:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-gestures.txt
```

VoiceDesk will use `.venv` for the gesture process when it exists. Camera capture remains off until you press **Start camera gestures**.

Say one of these commands:

- “Open Notepad”
- “Open Calculator”
- “Open file” (opens a picker for common document and image formats)
- “What is on my screen?” (asks AI about the active window)
- “Minimize window”
- “Maximize window”
- “Close window”
- “Take screenshot” (sends Print Screen)
- “Stop listening”

Press **Start listening** before speaking. Press **Stop listening**, say “Stop listening”, or close the app to stop microphone capture. Windows speech recognition transcribes locally. Exact basic commands are handled locally; other recognized requests are sent to OpenAI for intent interpretation. Internet access and API usage charges may apply. VoiceDesk shows the recognized phrase and last action, reports microphone/recognition errors, and ignores recognized phrases below its confidence threshold. “Open file” opens a picker and only accepts common document and image formats; voice text is never treated as a path. Window commands identify the foreground window and use Windows UI Automation when available, with a keyboard shortcut fallback; the target title is shown in the action result. If VoiceDesk itself is active, select the window you mean to control and repeat the command. “Close window” always asks for confirmation and may show the target app's save prompt. “Take screenshot” sends Print Screen but does not save an image.

For screen questions, VoiceDesk first reads accessible text from the active window and sends that text with the question to OpenAI. If the window exposes too little accessible text, it captures a scaled image of the virtual desktop and shows a preview. Nothing in that screenshot is sent unless you press **Send to OpenAI**; **Cancel** discards it. Screen content and spoken questions can contain private information, so only ask about screens you want sent for cloud analysis. VoiceDesk does not save screen text or screenshots to disk. It has no shutdown or arbitrary shell command.

## Optional camera gestures

If you have not created the virtual environment yet, install Python 3.10–3.12 and run:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-gestures.txt
```

If you already followed the setup above, no additional install command is needed.

In VoiceDesk, press **Start camera gestures**. A separate live preview appears and shows when camera processing is active. Hold a fist for about one second to pause voice listening; hold an open palm for about one second to resume it. Closing the preview with `Q` or pressing **Stop camera gestures** stops capture. Hand tracking runs locally; frames are not saved or sent to OpenAI. Only these two gestures are recognized, and gestures cannot close windows or launch apps.

Camera gesture support is optional. If Python, the camera, or the packages are unavailable, voice commands continue to work and VoiceDesk reports the camera error.

## Remove

Close VoiceDesk and delete the extracted `VoiceDesk` folder. If you created `.venv` inside it, deleting the folder removes those gesture packages too. Remove `OPENAI_API_KEY` and `VOICEDESK_MODEL` from Windows Environment Variables if you no longer want the optional AI service configured. Node.js or Python installations are not removed because they may be used by other projects.

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
