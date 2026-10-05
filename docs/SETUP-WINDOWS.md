# Setting up AI Meeting Copilot on Windows (beta)

> **Beta:** the Windows version uses the same page and features as the Mac version, but it hasn't been confirmed on real Windows hardware yet. If something doesn't work, please [open an issue](https://github.com/asuntzu/aimeetingcopilot/issues) with the contents of `live\listen.log`.

Setup takes about 10–15 minutes, most of it downloads.

## What you need

- **Windows 10 (21H2 or newer) or Windows 11**, on a regular (x64) or ARM64 PC.
- The **Claude desktop app** for Windows ([claude.ai/download](https://claude.ai/download)), signed in, with access to **Claude Code** (the Code tab).
- **winget** (App Installer). It's built into Windows 11 and current Windows 10; if `winget` isn't recognized, install **App Installer** from the Microsoft Store.
- About **700 MB** of free disk space.
- A reasonably recent PC. Transcription runs on the processor; older or low-power laptops will lag further behind the conversation.

## 1. Download the project

Open **PowerShell** (Start menu → type *PowerShell*) and run:

```powershell
git clone https://github.com/asuntzu/aimeetingcopilot.git $HOME\ai-meeting-copilot
```

No `git`? On the GitHub page choose **Code → Download ZIP**, then right-click the ZIP → **Extract All** into your user folder, and rename the folder to `ai-meeting-copilot`.

## 2. Run the installer

```powershell
cd $HOME\ai-meeting-copilot
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

The installer:
1. Installs **Node.js**, **uv** and **ripgrep** with winget (you may see Windows prompts to allow them).
2. Creates a private Python environment in `.venv` (uv downloads Python 3.12 if needed).
3. Downloads **whisper.cpp** for Windows, the speech model (180 MB) and the voice-recognition model (25 MB).
4. Asks **how your name should appear in transcripts**.
5. Registers the local helper with the Claude desktop app (a backup of your Claude settings is saved as `claude_desktop_config.json.bak-ai-meeting-copilot` in `%APPDATA%\Claude`).

You can run the installer again at any time. It skips what's already done and lets you change your name.

## 3. Turn on microphone access

Open **Settings → Privacy & security → Microphone** and make sure these are on:
- **Microphone access**
- **Let apps access your microphone**
- **Let desktop apps access your microphone**

Call audio (Zoom, Meet) needs no setup on Windows: the copilot records what's playing on your **default playback device**.

## 4. Restart Claude

Quit Claude completely: right-click the Claude icon in the system tray (bottom-right, near the clock) → **Quit**. Then open it again so it loads the helper.

## 5. Publish your own copy of the page

1. In the Claude app, open the **Code** tab and start a session in the `ai-meeting-copilot` folder.
2. Send this message:

   > Publish artifact/meeting-copilot.html as an artifact with the capabilities in artifact/capabilities.json

3. Claude replies with a link. The page also appears under **Artifacts** in the sidebar.

## 6. First run

1. Open **Meeting Copilot** from Artifacts **in the Claude desktop app**. It can't reach your computer from a regular browser tab.
2. When the page asks to use Claude (for the live notes), allow it.
3. Click **Setup → Record my voice (30 s)** and read the paragraph shown aloud.
4. Type a meeting name and press **Start**. The top of the page should say **Mic + call audio**.
5. Talk for a minute. Lines with your name appear in the transcript, then the AI notes.

## 7. Scheduling and briefings (optional)

To invite people and send briefings from the copilot, turn on the **Google Calendar** and **Gmail** connectors in claude.ai → **Settings → Connectors** (sign in with the Google account you want to send from). The first time you click **Schedule**, allow the page to use them. See [SCHEDULING.md](SCHEDULING.md).

At the end of a meeting, the **Action plan** lets AI do your follow-up. To also use [Hermes Agent](https://github.com/NousResearch/hermes-agent), list the allowed profiles in `config.json` (see [ACTION-ITEMS.md](ACTION-ITEMS.md#hermes-agent-optional)) and restart Claude.

## 8. Phone companion (optional)

Open the Claude app on your phone → **Artifacts** → **Meeting Copilot** while the page is open on your PC. The phone shows **Connected to your computer** and the live notes.

---

## Troubleshooting

**The installer won't run ("running scripts is disabled on this system")**
- Use the exact command above, which includes `-ExecutionPolicy Bypass`. It only applies to that one run.

**"winget is not recognized"**
- Install **App Installer** from the Microsoft Store, close PowerShell, open a new one and run the installer again.

**A tool installed but the installer says it can't find it (node, uv or rg)**
- Close PowerShell, open a new window (so it picks up the new PATH) and run the installer again.

**The page says "Not connected" or "Can't reach the Meeting Copilot helper"**
- Open the page from **Artifacts in the Claude desktop app**, not in a browser.
- Quit Claude from the **system tray** (closing the window isn't enough) and reopen it.
- Check that the helper is registered: open `%APPDATA%\Claude\claude_desktop_config.json` in Notepad and look for `"meeting-copilot"` with the path to `server.mjs`. If it's missing, run the installer again.
- Test the helper directly in PowerShell:
  ```powershell
  cd $HOME\ai-meeting-copilot
  '{"jsonrpc":"2.0","id":1,"method":"tools/call","params":{"name":"status"}}' | node server.mjs
  ```
  You should see a line containing `"listening"`.

**The transcript stays empty, or the page says the microphone is silent**
- Check the three microphone switches in step 3.
- Check **Settings → System → Sound → Input**: the right microphone must be selected, and the level bar should move when you speak.
- Some laptops have a microphone mute key or a privacy shutter. Check that it's not muted.
- Look at the log: `Get-Content $HOME\ai-meeting-copilot\live\listen.log`

**The top of the page says "Mic only" during a video call**
- Call audio comes from your **default playback device**. Open **Settings → System → Sound → Output** and select the speakers or headset you're actually hearing the call on, then press **Stop** and **Start**.
- If Zoom or Meet is set to a *different* speaker than the Windows default, change one so they match.
- Some Bluetooth headsets switch to a low-quality "hands-free" mode during calls. If call audio stops, choose the headset's stereo output as the default.

**The other person's words show up twice, or under my name**
- Record your voice profile (**Setup → Record my voice**). It's how the copilot tells your voice apart from the call coming out of your speakers.
- Headphones give the cleanest result.
- If your own lines are labeled **Guest**, record the voice profile again, or add `"voiceMatch": 0.4` to `config.json` (default 0.45; lower means more lines count as you).

**Transcription falls further and further behind**
- Your processor may be too slow for the default speech model. Close other heavy apps, or set **Setup → Update every → 30 s**.

**Clicking File doesn't seem to do anything**
- The folder picker can open **behind** the Claude window. Check the taskbar.

**No "Context" card appears**
- Context comes only from the folder you chose with **File**. Check that it contains PDF, Word (.docx), text, Markdown, RTF or HTML files. Old `.doc` files aren't supported on Windows; save them as `.docx`.
- Scanned PDFs (photos of pages) have no text to read.
- Documents in OneDrive that are "online-only" must be downloaded first: right-click the folder → **Always keep on this device**.

**Schedule or Today says "Connect Google Calendar" or "Connect Gmail"**
- Turn on that connector in claude.ai → **Settings → Connectors** and sign in, then reload the page.
- If it says the connector is turned off for this page, open the page's **Permissions** menu and allow it.

**The invite went out but the briefing email didn't appear**
- Click **Try the draft again** in the Schedule window. The draft is in Gmail under **Drafts**; nothing is emailed until you press Send there.

**An action item says "That Hermes profile isn't allowed"**
- Add the profile name to `"hermesProfiles"` in `config.json`, make sure it isn't in `"hermesBlocked"`, and restart Claude.

**Hermes tasks fail or never finish**
- Check that Hermes works on its own in a terminal, then try again. Each task has a 15-minute limit; results also appear in the meeting folder when they finish.

**The Claude app keeps asking me to approve actions, or an action says it was declined**
- The first time the copilot saves a file, starts recording or runs an action, the Claude app asks you to approve it. Choose **Allow** and tick **Always allow** for Meeting Copilot so it stops asking.
- If a prompt was closed or declined, press the button again and choose Allow. Research and proposals that finished but weren't saved keep their text in the card's preview.

**"AI notes are off"**
- The page wasn't allowed to use Claude. Reload it and choose **Allow** when asked, or open the page's **Permissions** menu.

**The phone says "Computer not connected"**
- The page must be open on your PC, in the Claude app, at the same time.
- Both devices must be signed in to the same Claude account.
- Reload the page on the phone.

**Windows Defender or SmartScreen warns about whisper-cli.exe**
- It's downloaded from the official whisper.cpp releases on GitHub (`ggml-org/whisper.cpp`). If you prefer, check the file's digital details before allowing it.

## Updating

```powershell
cd $HOME\ai-meeting-copilot
git pull
powershell -ExecutionPolicy Bypass -File .\install-windows.ps1
```

Then quit Claude from the system tray and reopen it. If `artifact/meeting-copilot.html` changed, ask Claude Code to publish it again **to your existing Meeting Copilot artifact** (paste its link) so the link stays the same.

## Uninstalling

1. Open `%APPDATA%\Claude\claude_desktop_config.json` in Notepad and remove the `"meeting-copilot"` entry (or restore the `.bak-ai-meeting-copilot` backup).
2. If you use Claude Code in the terminal: `claude mcp remove -s user meeting-copilot`
3. Delete the `ai-meeting-copilot` folder. **Move any meeting files you want to keep out of `archive\` first.**
4. Optional: remove Node.js, uv and ripgrep from **Settings → Apps** if nothing else uses them.
