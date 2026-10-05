# AI Meeting Copilot

A private, on-device meeting assistant for the **Claude desktop app**. It listens to your in-person meetings and your Zoom / Google Meet calls, transcribes them on your own computer, and gives you live help while you talk:

- **Live transcript with speaker labels**: your lines carry your name (recognized by your voice), the other people on a video call are labeled **Call**, and each other person in the room gets their own label (**Guest 1**, **Guest 2**…). Labels switch to real names when people introduce themselves ("Hi, I'm Dana") or when you click a speaker and type a name.
- **Say next**: the single most useful thing to say or ask right now.
- **Context from your documents**: choose a folder of background material (PDF, Word, notes) and the copilot briefs you on what those documents say about the topic being discussed, with the source file for each point.
- **Questions to raise, action items, decisions and notes**, updated as the conversation moves.
- **Ask**: type a question mid-meeting ("What did we quote them last time?") and get an answer from the transcript and your files.
- **Wrap up**: a summary, action items and a draft follow-up email, saved into your meeting folder with the transcript.
- **Phone companion**: open the same page on your phone to see the notes and control the meeting from it.
- **Scheduling and briefings**: invite people with a Google Calendar invitation and Google Meet link, get an AI-written attendee briefing and a private prep brief, and send a briefing email (as a Gmail draft you review) that shows the time in each attendee's time zone, with buttons to add the meeting to Google Calendar, Outlook, Microsoft 365, Apple Calendar or any other calendar. [How it works](docs/SCHEDULING.md)
- **AI does your follow-up**: after the meeting, an Action plan lists every action item and, when you press Start, Claude (or optionally [Hermes Agent](https://github.com/NousResearch/hermes-agent)) drafts the follow-up emails, writes proposals, does the research and sets up the next meeting. A group summary email lists everyone's action items, and **Did we miss anything?** checks past meetings for loose ends. [How it works](docs/ACTION-ITEMS.md)

| Version | Status | Setup guide |
|---|---|---|
| macOS (Apple Silicon or Intel, macOS 14.4+) | Stable | [docs/SETUP-MAC.md](docs/SETUP-MAC.md) |
| Windows 10 / 11 (x64 or ARM64) | **Beta**: not yet confirmed on real hardware | [docs/SETUP-WINDOWS.md](docs/SETUP-WINDOWS.md) |

## Privacy and security

See [SECURITY.md](SECURITY.md) for the full list of protections, known limits and how to report a vulnerability. Latest reviews: [October 4, 2026](docs/SECURITY-REVIEW-2026-10-04.md) and [Scheduling feature](docs/SECURITY-REVIEW-2026-10-04-SCHEDULING.md), [AI action items](docs/SECURITY-REVIEW-2026-10-04-ACTIONS.md).

- **Audio never leaves your computer and is never stored.** It's recorded in 10–30 second pieces, turned into text locally, and deleted within seconds.
- **Your voice profile is a voiceprint** (about 200 numbers), not a recording.
- **Your documents stay on your computer.** Only the short passages relevant to the current discussion are sent to Claude to write the live notes, the same as pasting them into a chat.
- **The phone companion** sends live updates between your own devices through your Claude account. Nothing is saved online.
- **What is saved**: the transcript, summary and live notes, as text files in the meeting folder you chose, plus a copy in `archive/`.
- **Consent**: recording or transcribing conversations requires the other people's consent in many places. Tell attendees the meeting is being transcribed.

## How it works

```
Claude desktop app
 └─ Meeting Copilot page (an Artifact you publish to your own account)
      ├─ talks to → server.mjs   local helper (MCP server) the installer registers with Claude
      │               ├─ starts → processor.py   records mic + call audio, transcribes with whisper.cpp,
      │               │                          labels speakers with a voiceprint (sherpa-onnx)
      │               └─ reads  → your meeting folder (extract.py for PDF / Word / RTF)
      └─ asks Claude for live notes, Context cards, answers and the wrap-up
Phone: open the same page → companion view, linked live to the computer
```

| File | Purpose |
|---|---|
| `artifact/meeting-copilot.html` | The page you publish as your own Artifact |
| `artifact/capabilities.json` | Permissions the page needs (Claude, live link, local helper) |
| `server.mjs` | Local helper: start/stop, transcript, folder search, saving files |
| `processor.py` | Recording, transcription, speaker labels |
| `extract.py` | Reads text from PDF, Word, RTF and HTML files |
| `mac/` | macOS call-audio helper and recorder app (built by the installer) |
| `install-mac.sh`, `install-windows.ps1` | Installers |

## Everyday use

1. Make a folder for the meeting and put background documents in it. Optionally click **Schedule** to invite people and send a briefing ([guide](docs/SCHEDULING.md)).
2. Open **Meeting Copilot** from Artifacts in the Claude app. For a meeting already on your calendar, click **Today** to load it.
3. Click **File** and choose the folder, type the meeting name, then press **Start**.
4. Watch the Copilot panel, or open the page on your phone.
5. Press **Wrap up meeting** at the end. The transcript, summary and live notes are saved into the folder, and the **Action plan** opens so AI can do your follow-up when you press Start ([guide](docs/ACTION-ITEMS.md)).
6. Press **New meeting** to clear everything for the next one.

## License

[MIT](LICENSE)
