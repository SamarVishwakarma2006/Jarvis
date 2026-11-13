# VoiceDesk roadmap

Build a dependable Windows voice assistant in small, reviewable releases. The target is a useful desktop assistant with a Jarvis-like conversational feel, not an unrestricted agent.

## How to track the work on GitHub

Create one GitHub Issue for each numbered step. Copy its checklist into the issue, label it `enhancement`, and close it with the step's commit or pull request. Do one step per feature branch and open a pull request before merging to `master`.

The repository's GitHub remote is named `origin`. Replace `<issue-number>` in commit messages with the issue created for that step. Start each branch from the latest `master`:

```powershell
git switch master
git pull --ff-only origin master
```

After merging a step's pull request, repeat those two commands before starting the next step. If your default branch is named `main`, substitute `main` for `master` throughout.

## Step 1 — Make the voice prototype dependable

**Goal:** Make the current fixed-command prototype report microphone/recognizer errors clearly, show what it heard, and stop cleanly. Keep the existing small command allowlist.

**Done when:**

- Startup explains how to fix a missing microphone or speech recognizer.
- The recognized phrase and action result are visible.
- “Stop listening” and Ctrl+C both exit cleanly.
- Commands that are not in the allowlist cannot trigger an action.
- The README matches the commands that actually work.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/voice-reliability
```

After work:

```powershell
git add VoiceDesk.ps1 README.md
git commit -m "Improve voice command reliability (Closes #<issue-number>)"
git push -u origin feature/voice-reliability
```

## Step 2 — Add a real desktop interface

**Goal:** Replace the console-only experience with a small Windows app showing listening state, transcript, last action, and a large stop control. Keep push-to-talk or an obvious listening toggle; do not silently listen on startup.

**Done when:**

- The app starts and stops listening from its UI.
- The user can see when the microphone is active and what was recognized.
- Microphone permission/device failures are visible and recoverable.
- Closing the UI stops microphone capture.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/desktop-interface
```

After work:

```powershell
git add -A
git commit -m "Add a Windows desktop interface (Closes #<issue-number>)"
git push -u origin feature/desktop-interface
```

## Step 3 — Make desktop actions reliable and bounded

**Goal:** Replace broad keyboard shortcuts with named, typed actions. Use Windows UI Automation to inspect and invoke controls when an app exposes them; keep keyboard shortcuts as an explicit fallback.

**Done when:**

- Each action is a named operation with validated inputs and a result or error.
- The app identifies the target window before acting and reports the target to the user.
- Unsupported UI controls fail visibly instead of claiming success.
- The model or speech recognizer cannot supply executable shell or script text.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/desktop-actions
```

After work:

```powershell
git add -A
git commit -m "Add safe Windows UI automation actions (Closes #<issue-number>)"
git push -u origin feature/desktop-actions
```

## Step 4 — Open apps and files safely

**Goal:** Add useful app launching and file opening without guessing dangerous paths. Start with an app allowlist and the Windows file picker; add voice selection only after the user can confirm the chosen file.

**Done when:**

- The user can launch approved apps by name.
- File opening uses a picker or a confirmed, validated path.
- Missing files and unsupported apps produce helpful errors.
- No voice input is passed to PowerShell, Command Prompt, or an unrestricted process launcher.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/open-apps-and-files
```

After work:

```powershell
git add -A
git commit -m "Add safe app and file opening (Closes #<issue-number>)"
git push -u origin feature/open-apps-and-files
```

## Step 5 — Add AI intent understanding

**Goal:** Let the user say requests naturally, then have AI convert them into a proposed structured action such as `{ action: "open_file", path: ... }`. The app validates the proposal and calls only its own allowlisted tools.

**Done when:**

- AI output is structured and validated before execution.
- Unknown or ambiguous requests trigger a clarifying question.
- Low-risk actions can run directly; closing windows, overwriting/deleting, sending, and shutdown require explicit confirmation.
- API credentials are not committed or embedded in a distributed client. Cloud use is clearly disclosed; a local-only mode remains available for basic commands.
- The assistant reports what it did and whether it succeeded.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/ai-intent
```

After work:

```powershell
git add -A
git commit -m "Add validated AI intent handling (Closes #<issue-number>)"
git push -u origin feature/ai-intent
```

## Step 6 — Let the assistant understand the screen

**Goal:** Answer questions about the current screen using accessibility/UI Automation data first, with an explicit screenshot capture as a fallback for inaccessible apps.

**Done when:**

- Screen reading happens only after a clear user request or an enabled, visible setting.
- The user can preview or cancel a screenshot before it is sent to a cloud model.
- Sensitive text is not stored in logs by default.
- The assistant states when it cannot reliably identify a control or screen detail.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/screen-awareness
```

After work:

```powershell
git add -A
git commit -m "Add user-controlled screen awareness (Closes #<issue-number>)"
git push -u origin feature/screen-awareness
```

## Step 7 — Add optional camera gestures

**Goal:** Add a few configurable gestures for simple actions, such as pause/resume or dismiss. Gestures should complement voice, not become a requirement.

**Done when:**

- Camera activation is explicit and visibly indicated.
- The user can disable gestures and stop camera capture at any time.
- Gestures are debounced so one held pose does not repeat an action.
- Gestures cannot trigger high-impact actions such as shutdown, deletion, or sending.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c feature/optional-gestures
```

After work:

```powershell
git add -A
git commit -m "Add optional camera gestures (Closes #<issue-number>)"
git push -u origin feature/optional-gestures
```

## Step 8 — Package and publish a usable release

**Goal:** Make installation, first-run setup, privacy behavior, and supported Windows versions clear enough for someone else to try the app.

**Done when:**

- A clean Windows machine can install and launch the release using documented steps.
- First run asks for microphone/camera access only when needed.
- The app has visible listening/camera indicators, a global stop control, and a concise privacy page.
- GitHub Releases include version notes, known limitations, and removal instructions.

Before work:

```powershell
git switch master
git pull --ff-only origin master
git switch -c release/first-public-build
```

After work:

```powershell
git add -A
git commit -m "Prepare the first public release (Closes #<issue-number>)"
git push -u origin release/first-public-build
```

## Design rule for every step

AI may interpret and propose. The local app owns permissions, validation, confirmations, and execution. Never execute model-generated shell commands. Keep microphone, screen, and camera access visible and under user control.
