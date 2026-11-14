# VoiceDesk privacy

- Voice capture starts only after you press **Start listening**. Windows speech recognition transcribes locally.
- Exact basic commands are handled on the PC. Other recognized requests are sent to OpenAI through the local Node service for intent interpretation. API use may incur charges.
- Screen questions send accessible text from the active window to OpenAI. When accessibility text is insufficient, VoiceDesk shows a screenshot preview and sends it only after you choose **Send to OpenAI**.
- Camera capture starts only after you press **Start camera gestures**. Hand tracking runs locally in a separate preview. Camera frames are not saved or sent to OpenAI.
- VoiceDesk does not intentionally save transcripts, screenshots, or camera frames.
- Stop voice capture with **Stop listening** or by closing VoiceDesk. Stop camera capture with **Stop camera gestures** or `Q` in the preview.

Do not ask VoiceDesk to inspect screens containing information you do not want sent to the cloud.
