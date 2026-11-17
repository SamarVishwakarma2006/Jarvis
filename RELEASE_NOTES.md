# VoiceDesk 0.2.0 source preview

This is an unsigned source preview for Windows 10/11, not a stable installer. The latest app changes have passed static syntax checks but have not been verified with a microphone and camera on a clean Windows machine. Follow `WINDOWS-ACCEPTANCE.md` before describing this preview as verified. See `README.md` for setup and `PRIVACY.md` for data handling.

## Changes in 0.2.0

- Added a guided launcher for the optional local AI service.
- Added microphone connection retry after device or permission errors.
- Added allowlisted File Explorer and Windows Settings voice actions.
- Added an optional window picker for window actions.
- Added independent pause/resume gesture toggles.
- Added off-by-default, session-only cloud conversation context with a clear control; screen content is excluded.
- Hardened local AI service request timeouts, size handling, UTF-8 parsing, health checks, and browser origin filtering.

## 0.2.0 limitations

- Wake-word activation is deferred; voice listening starts only after the user presses the button.
- This release has not passed the manual checklist in `WINDOWS-ACCEPTANCE.md` on a clean Windows installation.
- It is not code-signed and is not an installer.
- No shutdown or arbitrary shell execution is included.

## Changes in 0.1.1

- Cloud AI is opt-in and off by default.
- Added a Stop all capture control and optional local spoken responses.
- Voice recognition pauses while actions run and avoids overlapping actions.
- Close-window confirmation stays bound to the named target window.
- Updated setup and privacy instructions.

## Included

- Windows voice controls with a fixed local action allowlist.
- Optional OpenAI intent and screen-question service.
- Optional local hand gesture preview for pause/resume.
- Optional local spoken responses using Windows text-to-speech.

## Requirements and limitations

- Windows PowerShell 5.1, a microphone, and an installed Windows speech recognizer.
- The AI service additionally needs Node.js, an OpenAI API key, internet access, and a configured API model.
- Camera gestures additionally need Python 3.10–3.12, a camera, and the optional packages in `requirements-gestures.txt`.
- Desktop actions are limited to the documented command set. No shutdown or arbitrary shell execution is included.
- This source preview has not been verified on a clean Windows installation.
