# Setting up AI Meeting Copilot on macOS

Setup takes about 10 minutes, most of it downloads.

## What you need

- A Mac with **macOS 14.4 or newer** (for capturing Zoom / Meet audio). Apple Silicon is recommended; Intel works but transcribes more slowly.
- The **Claude desktop app** ([claude.ai/download](https://claude.ai/download)), signed in, with access to **Claude Code** (the Code tab).
- **Homebrew** ([brew.sh](https://brew.sh)).
- About **600 MB** of free disk space.

## 1. Download the project

Open **Terminal** and run:

```bash
git clone https://github.com/asuntzu/aimeetingcopilot.git ~/ai-meeting-copilot
```

No `git`? Download the ZIP from the GitHub page (**Code → Download ZIP**), unzip it, and move the folder to your home folder as `ai-meeting-copilot`.

## 2. Run the installer

```bash
cd ~/ai-meeting-copilot && ./install-mac.sh
```

The installer:
1. Checks for Homebrew and Apple's Command Line Tools. If the Command Line Tools are missing, a window opens to install them; run the installer again when that finishes.
2. Installs ffmpeg, whisper.cpp, Node.js, uv and ripgrep with Homebrew.
3. Creates a private Python environment in `.venv`.
4. Downloads the speech model (180 MB) and the voice-recognition model (25 MB).
5. Builds the call-audio helper and **AI Meeting Copilot Recorder.app**, the small app macOS asks about microphone access.
6. Asks **how your name should appear in transcripts**.
7. Registers the local helper with the Claude desktop app (a backup of your Claude settings is saved as `claude_desktop_config.json.bak-ai-meeting-copilot`).

You can run the installer again at any time. It skips what's already done and lets you change your name.

## 3. Restart Claude

Quit the Claude app completely (**Claude → Quit Claude**, or ⌘Q) and open it again, so it loads the helper.

## 4. Publish your own copy of the page

The page lives in your own Claude account, so each person publishes their own copy.

1. In the Claude app, open the **Code** tab and start a session in the `ai-meeting-copilot` folder.
2. Send this message:

   > Publish artifact/meeting-copilot.html as an artifact with the capabilities in artifact/capabilities.json

3. Claude replies with a link. The page also appears under **Artifacts** in the sidebar.

## 5. First run

1. Open **Meeting Copilot** from Artifacts **in the Claude desktop app**. It can't reach your computer from a regular browser tab.
2. When the page asks to use Claude (for the live notes), allow it.
3. Click **Setup → Record my voice (30 s)**. macOS asks whether **AI Meeting Copilot Recorder** can use the microphone: click **Allow**, then read the paragraph shown aloud.
4. Type a meeting name and press **Start**. On the first meeting macOS asks about **system audio recording** for AI Meeting Copilot Recorder: click **Allow**. That's what lets it hear Zoom and Meet.
5. Talk for a minute. Lines with your name appear in the transcript, then the AI notes.

## 6. Phone companion (optional)

Open the Claude app on your phone → **Artifacts** → **Meeting Copilot** while the page is open on your Mac. The phone shows **Connected to your computer** and the live notes.

---

## Troubleshooting

**The page says "Not connected" or "Can't reach the Meeting Copilot helper"**
- Open the page from **Artifacts in the Claude desktop app**, not in a browser.
- Quit Claude completely (⌘Q) and reopen it, so it loads the helper.
- Check that the helper is registered: `grep -A3 meeting-copilot ~/Library/Application\ Support/Claude/claude_desktop_config.json` should show your `server.mjs` path. If not, run `./install-mac.sh` again.
- Test the helper directly: `cd ~/ai-meeting-copilot && echo '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"status"}}' | node server.mjs`. You should see a line with `"listening"`.

**The transcript stays empty, or the top of the page says "silent"**
- macOS is blocking the microphone. Open **System Settings → Privacy & Security → Microphone** and turn on **AI Meeting Copilot Recorder**, then press **Stop** and **Start**.
- If it isn't in the list, press Start again and click **Allow** when macOS asks.
- Using AirPods or a headset? The copilot uses whatever input macOS is set to (**System Settings → Sound → Input**).
- To reset the permission and be asked again: `tccutil reset Microphone org.aimeetingcopilot.recorder`

**The top of the page says "Mic only" during a video call**
- Open **System Settings → Privacy & Security → Screen & System Audio Recording**, turn on **AI Meeting Copilot Recorder** under **System Audio Recording Only**, then press **Stop** and **Start**.
- Requires macOS 14.4 or newer.
- See the reason in the log: `cat ~/ai-meeting-copilot/live/listen.log`

**The other person's words show up twice, or under my name**
- Record your voice profile (**Setup → Record my voice**). It's how the copilot tells your voice apart from the call coming out of your speakers.
- Headphones give the cleanest result.
- If your own lines are labeled **Guest**, record the voice profile again in the room you usually use. To make matching looser, add `"voiceMatch": 0.4` to `config.json` (default 0.45; lower means more lines count as you).

**Clicking File doesn't seem to do anything**
- The folder picker sometimes opens **behind** the Claude window. Check the Dock or press ⌘Tab.

**No "Context" card appears**
- Context comes only from the folder you chose with **File**. Check that it contains PDF, Word (.docx), text, Markdown, RTF or HTML files.
- While the folder is being read, the File chip shows "reading 3/12". Large folders take longer the first time.
- Scanned PDFs (photos of pages) have no text to read.

**"AI notes are off"**
- The page wasn't allowed to use Claude. Reload it and choose **Allow** when asked, or open the page's **Permissions** menu.

**The phone says "Computer not connected"**
- The page must be open on your Mac, in the Claude app, at the same time.
- Both devices must be signed in to the same Claude account.
- Reload the page on the phone.

**Something else went wrong**
- The recorder log is `live/listen.log` and the current transcript is `live/transcript.md`.
- Run `./install-mac.sh` again. It repairs missing pieces without deleting your meetings or voice profile.

## Updating

```bash
cd ~/ai-meeting-copilot && git pull && ./install-mac.sh
```

Then quit and reopen Claude. If `artifact/meeting-copilot.html` changed, ask Claude Code to publish it again **to your existing Meeting Copilot artifact** (paste its link) so the link stays the same.

## Uninstalling

1. Delete `"meeting-copilot"` from `~/Library/Application Support/Claude/claude_desktop_config.json` (or restore the `.bak-ai-meeting-copilot` backup).
2. If you use Claude Code in the terminal: `claude mcp remove -s user meeting-copilot`
3. Delete the `~/ai-meeting-copilot` folder. **Move any meeting files you want to keep out of `archive/` first.**
4. Optional: `brew uninstall whisper-cpp ffmpeg` if nothing else uses them.
