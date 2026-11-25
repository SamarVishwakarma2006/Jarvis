# VoiceDesk

A Windows desktop voice-control prototype with an allowlisted set of desktop actions. Exact commands work locally; optional AI maps natural-language requests to those actions. Speech recognition runs on Windows, so raw microphone audio is not sent to the AI service. The app shows microphone status, recognized speech, and action results.

See [ROADMAP.md](ROADMAP.md) for the GitHub build plan and [WINDOWS-ACCEPTANCE.md](WINDOWS-ACCEPTANCE.md) for the manual release checklist.

## Requirements

- Windows 10 or 11
- Windows PowerShell 5.1
- .NET Framework components included with Windows PowerShell (System.Speech and Windows Forms)
- A microphone and an installed Windows speech recognizer for your current language

If **Start listening** is disabled, VoiceDesk could not find a speech recognizer for your Windows language. Add the matching speech language in Windows Settings and restart VoiceDesk. The rest of the interface remains available while voice recognition is unavailable.

## Run

For the source preview, extract the GitHub release ZIP and double-click `Run-VoiceDesk.cmd`. Or open PowerShell in this folder and run:

```powershell
.\VoiceDesk.ps1
```

The launcher allows the script for this process only; it does not change the machine's execution policy.

## Optional features

The core voice commands do not require Node.js or Python. To enable local natural-language AI and screen questions with Qwen3.5 4B, follow [Optional local AI service](#optional-local-ai-service). To enable hand gestures, install Python 3.10–3.12 and create an isolated environment:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-gestures.txt
```

VoiceDesk will use `.venv` for the gesture process when it exists. Camera capture remains off until you press **Start camera gestures**.

Say one of these commands:

- “Open Notepad”
- “Open Calculator”
- “Open File Explorer”
- “Open work tools” (previews before opening Notepad and File Explorer)
- “Open Windows Settings”
- “Open file” (opens a picker for common document and image formats)
- “What is on my screen?” (asks AI about the active window)
- “Minimize window”
- “Maximize window”
- “Close window”
- “Take screenshot” (sends Print Screen)
- “Stop listening”

Press **Start listening** before speaking. VoiceDesk pauses recognition while it processes each accepted phrase, then resumes unless you stop capture. Check **Speak responses aloud** to hear results using Windows' local voice; the microphone stays paused until speech finishes to prevent feedback. Press **Stop listening**, say “Stop listening”, or close the app to stop microphone capture. **Stop all capture** stops both microphone and camera capture. Windows speech recognition transcribes locally. Exact basic commands are handled locally. Non-exact requests and screen questions use Qwen3.5 4B through Ollama only while **Enable local AI** is checked; it is unchecked by default. The separate session-context option is also off by default; when enabled, it keeps up to three non-screen voice turns in memory for follow-ups and clears them when unchecked or when VoiceDesk closes. The **Clear conversation context** button clears them immediately. Requests run on this PC; an internet connection is needed to download Ollama and the model, not for inference after installation. VoiceDesk shows the recognized phrase and last action, reports microphone/recognition errors, and ignores recognized phrases below its confidence threshold. “Open file” opens a picker and only accepts common document and image formats; voice text is never treated as a path. Window actions target the foreground window by default; use **Choose target window** to select a different one. VoiceDesk shows the selected title, uses Windows UI Automation when available, and keeps close confirmation bound to that same target. Keyboard shortcuts are only used when the target is foreground. “Take screenshot” sends Print Screen to the foreground window and does not save an image.

For screen questions, VoiceDesk first reads accessible text from the active window and sends that text with the question to the local Qwen model. If the window exposes too little accessible text, it captures a scaled image of the virtual desktop and shows a preview. Nothing in that screenshot is sent unless you press **Send to local AI**; **Cancel** discards it. Screen content and spoken questions can contain private information, so only inspect screens you are comfortable processing on this PC. VoiceDesk does not save screen text or screenshots to disk. It has no shutdown or arbitrary shell command.

## Optional camera gestures

If you have not created the virtual environment yet, install Python 3.10–3.12 and run:

```powershell
py -3.12 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements-gestures.txt
```

If you already followed the setup above, no additional install command is needed.

In VoiceDesk, leave the individual gesture options enabled as desired, then press **Start camera gestures**. A separate live preview appears and shows when camera processing is active. Hold a fist for about one second to pause voice listening; hold an open palm for about one second to resume it. Closing the preview with `Q` or pressing **Stop camera gestures** stops capture. Hand tracking runs locally; frames are not saved or sent over the network. Only these two gestures are recognized, and gestures cannot close windows or launch apps.

Camera gesture support is optional. If Python, the camera, or the packages are unavailable, voice commands continue to work and VoiceDesk reports the camera error.

## Remove

Close VoiceDesk and delete the extracted `VoiceDesk` folder. If you created `.venv` inside it, deleting the folder removes those gesture packages too. Uninstall Ollama separately if you no longer want it; Ollama manages downloaded models outside the VoiceDesk folder. Node.js or Python installations are not removed because they may be used by other projects.

## Optional local AI service

Natural-language requests use Qwen3.5 4B through Ollama on your PC. Install [Ollama for Windows](https://ollama.com/download), install Node.js 18 or newer, then open PowerShell and download the model:

```powershell
ollama pull qwen3.5:4b
```

The model download is about 3.3–4.0 GB. Ollama must be running. Double-click `Start-AI-Service.cmd` to start VoiceDesk's small local bridge; the default model is `qwen3.5:4b`. You can override it with `VOICEDESK_MODEL` if you install another compatible model. The bridge and Ollama listen on loopback addresses only.

```powershell
Start-AI-Service.cmd
```

Start VoiceDesk and check **Enable local AI** for non-exact voice commands and screen questions. VoiceDesk checks that Ollama and the selected model are available before enabling the feature. If Ollama is stopped or the model is missing, the UI shows a setup hint; exact basic commands still work. Inference runs locally and does not require an API key or incur per-request API charges. The first model download does require internet access. See the [Qwen3.5 4B model page](https://ollama.com/library/qwen3.5:4b) for model details and its license information.

## Scope

AI output is a proposed intent from a fixed schema. VoiceDesk validates the intent and maps it to its own allowlisted actions; model output is never executed as shell code. Unknown requests result in a clarifying response, and closing a window requires an explicit confirmation. This remains a prototype, not an unrestricted desktop agent.

**Undo last window change** restores a UI Automation minimize/maximize to its prior state only if the same window is still there and unchanged. Keyboard shortcuts do not support undo.

The routine format is defined by [`routine.schema.json`](routine.schema.json), and the built-in example is in [`routines.json`](routines.json). VoiceDesk validates the routine and every action ID before showing its preview.

Use **Create local routine** to save a routine with a name, up to five spoken phrases (one per line), and one or more supported actions: **Open Notepad**, **Open File Explorer**, **Open Calculator**, or **Open Windows Settings**. Select an action and use **Move up** or **Move down** to change its run order. Any saved phrase triggers the same preview, and phrases cannot be shared between routines. **Manage local routines** lets you preview, edit, or delete a selected user routine; previewing uses the usual confirmation before actions run, deletion also requires confirmation, and the built-in routine is protected. The **Preview selected** option works when voice recognition is unavailable. User routines are stored in `%LOCALAPPDATA%\VoiceDesk\routines.json` and stay on this PC. The editor does not accept scripts, shell commands, or file paths.

## License

MIT. See [LICENSE](LICENSE).
