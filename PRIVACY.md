# VoiceDesk privacy

- Voice capture starts only after you press **Start listening**. Windows speech recognition transcribes locally.
- Optional spoken replies use the installed Windows voice locally. Listening pauses during playback; voice output stays on the PC.
- Exact basic commands are handled on the PC. Other recognized requests are sent to the local Qwen model through Ollama only when **Enable local AI** is checked; it is off by default. Model inference runs on this PC and does not use a cloud API.
- Optional conversation context is off by default. When enabled, VoiceDesk temporarily keeps up to three non-screen voice turns in memory and sends that context to the local model with later requests. Unchecking the option, using **Clear conversation context**, or closing VoiceDesk clears it. Screen text and screenshots are never added to this context.
- User-created routines are stored locally under `%LOCALAPPDATA%\VoiceDesk\routines.json`. Their names, spoken phrases, and selected action IDs are matched on the PC and are not sent to the model.
- Screen questions send accessible text from the active window to the local model. When accessibility text is insufficient, VoiceDesk shows a screenshot preview and processes it only after you choose **Send to local AI**.
- Camera capture starts only after you press **Start camera gestures**. Hand tracking runs locally in a separate preview. Camera frames are not saved or sent over the network.
- VoiceDesk does not intentionally save transcripts, screenshots, or camera frames.
- Stop voice capture with **Stop listening**. Stop camera capture with **Stop camera gestures** or `Q` in the preview. **Stop all capture** stops both immediately.

The first Qwen model download requires internet access. After download, VoiceDesk sends prompts and any approved screenshots only to the local Ollama service at `127.0.0.1`.
