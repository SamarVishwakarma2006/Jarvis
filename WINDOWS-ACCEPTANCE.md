# Windows acceptance checklist

Run this on each Windows version you plan to support. Record the Windows version, microphone/camera models, date, and pass/fail notes in the GitHub Issue. This checklist is not a claim that the app has passed on a clean machine.

## Core voice and desktop actions

- [ ] Launch `Run-VoiceDesk.cmd`; confirm microphone and camera start off.
- [ ] Start listening, say “Open Notepad”, then stop listening from the UI.
- [ ] Start listening again; say “Open File Explorer” and “Open Windows Settings”.
- [ ] Say “Open file”, cancel the picker, then open a supported file.
- [ ] Choose a different window target; verify minimize and maximize apply to that window.
- [ ] Say “Close window”; cancel once and confirm no window closes, then confirm on a disposable window.
- [ ] Select **Foreground window (default)** and verify the default target behavior is restored.
- [ ] Close VoiceDesk while listening; confirm microphone capture stops.

## Microphone recovery

- [ ] Start without a usable microphone; confirm a clear error and that **Start listening** remains available.
- [ ] Connect or enable a microphone and press **Start listening** again; confirm recovery without restarting VoiceDesk.
- [ ] Disconnect/disable the microphone during listening; confirm the error is visible and retry works after restoring it.

## Optional AI and context

- [ ] Start without the AI service; enable cloud AI and confirm it reverts off with setup guidance.
- [ ] Start with missing AI environment configuration; run `Start-AI-Service.cmd` and confirm it explains the missing setting without printing a key.
- [ ] With valid configuration, start the service and confirm VoiceDesk enables cloud AI only after its readiness check.
- [ ] With cloud AI enabled and context off, try one natural-language request; confirm it uses only the fixed allowlist.
- [ ] Enable session context, complete two non-screen voice turns, and try a follow-up; confirm it sees recent turns.
- [ ] Clear context, disable the option, and restart VoiceDesk; confirm prior context is not retained.
- [ ] Ask a screen question with accessible text; confirm only the requested question and relevant screen data are sent.
- [ ] When a screenshot preview appears, cancel once and confirm nothing is sent; repeat and send only if appropriate.

## Camera gestures

- [ ] Confirm camera is off at startup; start gestures and verify the active indicator and live preview.
- [ ] Disable each gesture option in turn; verify its gesture no longer changes voice listening.
- [ ] With each option enabled, hold fist/open palm and verify pause/resume once per pose.
- [ ] Stop gestures with the button and with `Q`; confirm camera capture ends and voice still works.
- [ ] Test with Python or camera unavailable; confirm voice controls continue to work.

## Release notes

- [ ] Record failures and environment details in `RELEASE_NOTES.md` or the release issue.
- [ ] Do not mark a check as passed unless it was observed on the target Windows machine.
