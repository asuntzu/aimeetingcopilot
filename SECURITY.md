# Security

AI Meeting Copilot handles sensitive material: live conversations, a voiceprint, and private documents. This page describes how it is protected and what it does not protect against.

## Security reviews

- [October 4, 2026](docs/SECURITY-REVIEW-2026-10-04.md): 1 serious and 9 smaller issues found and fixed.
- [October 4, 2026, scheduling feature](docs/SECURITY-REVIEW-2026-10-04-SCHEDULING.md): reviewed and attack-tested before release.

## Reporting a vulnerability

Please **don't open a public issue** for security problems. Use GitHub's private reporting instead: **Security → Report a vulnerability** on this repository. Include steps to reproduce and the version (commit) you tested.

## What is protected

| Area | Protection |
|---|---|
| **Audio** | Recorded in short chunks, transcribed locally with whisper.cpp, and deleted within seconds. Never uploaded, never stored. |
| **Voiceprint** | Stored as about 200 numbers in `voice/host.json`, not as a recording. |
| **File permissions (macOS)** | The install folder is `chmod 700`; the helper and recorder create files with `umask 077`, so transcripts, notes, the voiceprint and cached document text are readable only by you. On Windows these files live in your user profile, which other standard users can't read. |
| **Folder access** | A meeting folder must be inside your home folder (not the home folder itself), and can never be, or contain the path of, a hidden or system folder (`.ssh`, `.aws`, `.gnupg`, `.config`, `Library`, `AppData`, keychains, and so on). Symbolic links are resolved before every check and are never followed while indexing, so a link inside a meeting folder can't expose files outside it. |
| **File writes** | Meeting names and document kinds are sanitized before becoming file names; outputs can only be written directly inside the chosen meeting folder or the copilot's own `archive/`. |
| **Command execution** | Every external program is started with an argument list (no shell). Search terms are passed to ripgrep with `-e … --` and `--no-config`, so text from documents, transcripts or the AI can never be read as a command-line option. |
| **Process control** | Stopping the recorder uses a stop flag; the helper only signals a process after confirming it is this project's `processor.py`. |
| **Prompt injection** | Transcripts and documents are written by other people. Every AI prompt marks them as untrusted information and tells Claude not to follow instructions inside them. The AI's tools are read-only (search and read inside the chosen folder). |
| **Page (Artifact)** | All transcript, document, file-name and AI text is HTML-escaped before display. The page can only call the helper actions listed in `artifact/capabilities.json`, and the Claude app asks before the page uses Claude or the helper. |
| **Phone companion** | Live updates travel only between your own signed-in devices; nothing is stored online. Commands from the phone are accepted only from your own account, and folder changes only to folders the computer offered. If anyone else opens the page (for example, if you shared it), the computer stops sending meeting content until they leave. |
| **Helper exposure** | The installer registers the helper only with the Claude desktop app, not with Claude Code, so coding sessions can't start your microphone. |
| **Scheduling (Google Calendar, Gmail)** | The page may only create calendar events, read your calendar and create Gmail **drafts**. It can't send email. Calendar invites go out only after a two-step confirmation. Everything placed in invites, emails and the attached `.ics` file is escaped or encoded (no AI-supplied HTML or links, no injected calendar lines), and only verified `https://meet.google.com` and Google links are used. The attendee briefing is kept separate from the private prep brief and must be reviewed before sending. The address book (`contacts.json`) is validated, stored only on your computer with private permissions, and never sent to the phone companion. |
| **Supply chain** | Downloaded models and the Windows whisper.cpp build are verified against SHA-256 fingerprints before use; Python dependencies are pinned to exact tested versions. |

## Known limits

- **Text sent to Claude.** To write live notes, the relevant transcript lines and short passages from your documents are sent to Claude under your account, as in any Claude chat. Don't put material in a meeting folder that your organization doesn't allow in Claude.
- **Whole-system audio (macOS).** Call capture records everything your Mac plays while a meeting is recording (including notification sounds), not just Zoom or Meet. It runs only while you're recording.
- **Saved text is not encrypted by the app.** Transcripts and notes are plain text files protected by your operating system account. Use FileVault (macOS) or BitLocker (Windows) to protect them at rest, and lock your computer when you step away.
- **Ad-hoc code signing (macOS).** The recorder app is signed locally by the installer, not by an Apple Developer ID. Rebuilding it may make macOS ask for microphone permission again.
- **Consent.** Recording or transcribing a conversation can require everyone's consent where you live. Tell attendees.
