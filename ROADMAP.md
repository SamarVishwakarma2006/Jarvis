# VoiceDesk GitHub build plan

VoiceDesk is a Windows voice-control prototype with a small allowlist, optional cloud AI, screen questions with screenshot approval, and optional local camera gestures. Steps 2–7 have been implemented on `master`. Step 1 still needs a hands-on Windows run; Step 8 is deferred; Step 9 is prepared as a source preview but must not be called a verified release until Step 1 passes. Keep every change on `master`; do not create branches.

## Track each step on GitHub

For each step:

1. Create a GitHub Issue with the title and checklist below; label it `enhancement` (or `bug` if investigating a failure).
2. Start from the latest `master`:

   ```powershell
   git switch master
   git pull --ff-only origin master
   ```

3. Complete only that issue, run its listed checks, and commit with the issue number in the message.
4. Push the commit, then close the issue on GitHub.

Replace `<issue-number>` in each commit command with the number GitHub assigned. Push after each step with `git push origin master`. If Git says the branch is behind, pull with `--ff-only` before pushing; do not force-push.

## Already in the prototype

- Windows desktop UI with explicit start/stop controls, transcript, status, and action result.
- Local exact voice commands; speech audio is not sent to the AI service.
- Bounded desktop actions, a file picker, and confirmation before closing a window.
- Optional structured AI intents and screen questions; cloud AI starts off.
- Screenshot preview and explicit send/cancel choice for screen questions.
- Optional local text-to-speech and camera gestures, with visible controls.
- Local AI service request limits, timeouts, readiness check, UTF-8 parsing, and origin filtering.
- Source ZIP packaging and setup/privacy/removal documentation.

The source preview still needs hands-on verification on the target Windows setup before it should be called a stable public release. The feature list below is a plan, not a claim that those checks have passed.

## Step 1 — Verify the current Windows build

**GitHub Issue title:** `Verify VoiceDesk on the target Windows setup`

**Goal:** Run the app on the Windows machine it is meant to support, record failures, and fix the ones that block normal use.

**Done when:**

- Voice starts only after the user presses **Start listening** and stops from the UI or by closing the app.
- Missing microphone or speech recognizer produces a useful message.
- Exact commands, file picker, minimize/maximize, and confirmed close behave as documented.
- Cloud AI works when configured and enabled; it stays off otherwise.
- Screen questions show accessible text behavior and screenshot preview/cancel/send behavior.
- Camera gestures start and stop visibly; gesture failure does not break voice controls.
- Known limitations and actual results are recorded in `RELEASE_NOTES.md`.

**Check:** Follow the checklist manually on the target Windows version. Do not describe hardware-dependent behavior as verified until it has been tried.

```powershell
git add VoiceDesk.ps1 gesture_service.py README.md RELEASE_NOTES.md
git commit -m "Verify VoiceDesk on Windows (Closes #<issue-number>)"
git push origin master
```

## Step 2 — Make AI service setup easier

**Status:** Implemented in commit `9842356`.

**GitHub Issue title:** `Add a guided launcher for optional cloud AI`

**Goal:** Help users start the local Node service and diagnose missing Node.js, API key, or model configuration without putting secrets in the repository.

**Done when:**

- A launcher checks for Node.js and required environment variables before starting the service.
- Missing configuration prints clear setup instructions and exits with a useful status.
- Closing the service window stops the local service.
- README setup and troubleshooting instructions match the launcher.
- No API key is written into tracked files, command-line arguments, logs, or the ZIP.

```powershell
git add Start-AI-Service.cmd package-release.ps1 README.md
git commit -m "Add guided AI service startup (Closes #<issue-number>)"
git push origin master
```

## Step 3 — Improve microphone recovery

**Status:** Implemented in commit `8d5d5a7`.

**GitHub Issue title:** `Recover from microphone availability changes`

**Goal:** Let a user recover if the microphone is disconnected, disabled, or unavailable after VoiceDesk starts.

**Done when:**

- The UI explains the microphone error and offers a retry after the device is fixed.
- Retry does not create duplicate recognizers or event handlers.
- Stop and window-close still release capture cleanly.
- The local command flow works after recovery.

```powershell
git add VoiceDesk.ps1 README.md
git commit -m "Add microphone recovery (Closes #<issue-number>)"
git push origin master
```

## Step 4 — Add a few approved app launches

**Status:** Implemented in commits `9415538` and `e9cb49f` (File Explorer and Windows Settings).

**GitHub Issue title:** `Add safe app launching by name`

**Goal:** Extend the fixed action allowlist with a small set of useful Windows apps; never turn voice text into a process path or shell command.

**Done when:**

- Each supported app has an explicit name-to-launch mapping in local code.
- Unknown app names produce a clear response and launch nothing.
- Natural-language AI can select only the same fixed app intents.
- README lists the supported launch phrases.

```powershell
git add VoiceDesk.ps1 ai-service/server.mjs README.md
git commit -m "Add approved app launch commands (Closes #<issue-number>)"
git push origin master
```

## Step 5 — Make target window selection clearer

**Status:** Implemented in commit `76d612c`.

**GitHub Issue title:** `Let users choose the target window`

**Goal:** Reduce mistakes when a window action should affect a window other than the current foreground window.

**Done when:**

- The user can see available windows and select a target for a supported window action.
- The selected target is shown before a close confirmation and remains the target acted on.
- If the target closes or becomes unavailable, the action fails visibly without switching to another window.
- Current foreground behavior remains available as the simple default.

```powershell
git add VoiceDesk.ps1 README.md
git commit -m "Add explicit window target selection (Closes #<issue-number>)"
git push origin master
```

## Step 6 — Improve gesture controls

**Status:** Implemented in commit `ec27756`.

**GitHub Issue title:** `Add configurable camera gesture behavior`

**Goal:** Make optional camera gestures easier to use across different cameras and users while keeping them limited to low-risk controls.

**Done when:**

- Camera access stays off until explicitly started and has an obvious stop control.
- Pause/resume gestures are debounced and can be individually enabled or disabled.
- Gesture confidence or loss of hand tracking does not trigger repeated actions.
- Gestures cannot close windows, open files, send content, or shut down the PC.
- README describes camera permission, supported gestures, and limitations.

```powershell
git add VoiceDesk.ps1 gesture_service.py README.md PRIVACY.md
git commit -m "Improve optional gesture controls (Closes #<issue-number>)"
git push origin master
```

## Step 7 — Add short-lived conversational context

**Status:** Implemented in commit `5a9c31b`.

**GitHub Issue title:** `Add opt-in session context for follow-up requests`

**Goal:** Support short follow-up phrases such as “what about the next window?” without keeping a permanent transcript or executing unrestricted model output.

**Done when:**

- Context is limited to the current app session and has a visible clear/reset action.
- Context is off by default or clearly enabled by the user before any text is retained.
- Sensitive screen content is not silently added to conversation history.
- AI still returns a validated allowlisted intent; ambiguous or high-impact requests ask the user before acting.
- Privacy documentation states what is retained and when it is cleared.

```powershell
git add VoiceDesk.ps1 ai-service/server.mjs README.md PRIVACY.md
git commit -m "Add controlled session context (Closes #<issue-number>)"
git push origin master
```

## Step 8 — Add optional wake-word mode

**GitHub Issue title:** `Prototype opt-in local wake-word listening`

**Goal:** Explore hands-free activation only after the explicit start/stop experience is reliable. Prefer local wake-word detection and keep it off by default.

**Current decision:** Deferred. The official [openWakeWord project](https://github.com/dscripka/openWakeWord) documents Windows inference support, while [Porcupine's Python quick start](https://picovoice.ai/docs/quick-start/porcupine-python/) requires an account access key. VoiceDesk would also need to coordinate a continuously open microphone stream with Windows speech recognition and demonstrate false-trigger behavior on the target PC. Keep push-to-start as the supported mode until that integration can be verified on hardware.

**Done when:**

- Wake-word mode requires explicit opt-in and has a persistent visible listening indicator and stop control.
- Wake-word detection runs locally; raw audio is not sent to cloud services for wake-word detection.
- Normal push-to-talk/toggle mode remains available.
- The feature documents battery/CPU, privacy, language, and false-trigger limitations.
- If reliable local detection cannot be achieved with supported dependencies, document the result and leave the feature out.

```powershell
git add VoiceDesk.ps1 gesture_service.py README.md PRIVACY.md package-release.ps1 requirements-wakeword.txt
git commit -m "Prototype local wake word mode (Closes #<issue-number>)"
git push origin master
```

## Step 9 — Verify and publish the 0.2.0 source preview

**GitHub Issue title:** `Verify and publish VoiceDesk 0.2.0 source preview`

**Goal:** Finish the Windows checks and publish the prepared source archive with honest limitations.

**Done when:**

- Step 1 acceptance checks pass on a clean supported Windows setup.
- Version, release notes, requirements, privacy details, and removal steps agree.
- The source ZIP contains only the intended release files and extracts into a clear folder.
- GitHub Release notes include setup, known limitations, and rollback/removal guidance.
- Create a GitHub Release only after the checks pass; identify it as an unsigned source preview, not a stable 1.0 installer.
- Any installer or signing work is included only if the source ZIP workflow proves insufficient.

```powershell
git add VERSION RELEASE_NOTES.md README.md PRIVACY.md WINDOWS-ACCEPTANCE.md package-release.ps1
git commit -m "Prepare VoiceDesk 0.2.0 preview (Closes #<issue-number>)"
git push origin master
```

## Keep out of scope until the safety model supports it

- Never execute AI-generated shell, PowerShell, or arbitrary file paths.
- Do not add shutdown, deletion, purchases, sending messages, or other high-impact actions without a separate permission and confirmation design.
- Do not add always-on cloud audio or store screen captures/transcripts by default.
- Treat wake-word and richer memory as optional experiments, not requirements for the core app.
