# VoiceDesk 0.1.0 source preview

This is an early source release for Windows 10/11. It is not a signed installer. See `README.md` for setup and `PRIVACY.md` for data handling.

## Included

- Windows voice controls with a fixed local action allowlist.
- Optional OpenAI intent and screen-question service.
- Optional local hand gesture preview for pause/resume.

## Requirements and limitations

- Windows PowerShell 5.1, a microphone, and an installed Windows speech recognizer.
- The AI service additionally needs Node.js, an OpenAI API key, internet access, and a configured API model.
- Camera gestures additionally need Python 3.10–3.12, a camera, and the optional packages in `requirements-gestures.txt`.
- Desktop actions are limited to the documented command set. No shutdown or arbitrary shell execution is included.
- This source preview has not been verified on a clean Windows installation.
