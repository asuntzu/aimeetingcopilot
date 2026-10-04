# Scheduling, invitations and briefings

Plan a meeting from the copilot: it writes a briefing from your meeting folder, sends a Google Calendar invitation with a Google Meet link, and prepares a briefing email that lets every attendee add the meeting to Google Calendar, Outlook, Microsoft 365, Apple Calendar or any other calendar app.

## What you get

- **A Google Calendar invitation** with a Google Meet link, sent by Google to every attendee. It works in every major calendar: attendees click Yes / Maybe / No and it's added automatically. If you later move the meeting in Google Calendar, everyone's calendar updates.
- **A briefing email, saved as a draft in your Gmail.** It shows the meeting time in **each attendee's own time zone**, a Join button, the purpose, agenda and what to prepare, plus buttons to add the meeting to:
  - Google Calendar
  - Outlook.com
  - Microsoft 365
  - Apple Calendar and any other app (an attached `invite.ics` file)

  You review the draft in Gmail and press Send yourself.
- **Two briefings, kept separate:**
  - **Attendee briefing**: purpose, agenda, what to prepare. This is what attendees see.
  - **Private prep brief**: background on each attendee and organization from your documents, your goals, likely questions with suggested answers, key numbers and risks. It's saved to your meeting folder and **never sent**.
- **A private address book**: people you invite are remembered on your computer (name, email, time zone), so next time you just start typing their name.
- **Today's meetings**: the **Today** button lists today's meetings with guests from your Google Calendar. Choosing one loads the meeting name, the attendees (the AI uses their names in the live notes) and, for meetings you scheduled here, the meeting folder.

## How to use it

1. Click **Schedule** in the top bar.
2. Fill in the title, date, start time, length and your time zone. For in-person meetings, add the address; a Google Meet link is always included.
3. Click **Choose folder…** and pick the meeting's folder of background documents.
4. Add attendees as `Name <email>` or just an email, and set each person's time zone.
5. Write your agenda and goals (private; used only by the AI) and click **Write briefing**.
6. **Read and edit the briefing.** Everything in the highlighted box goes to the attendees. The private prep brief below it doesn't.
7. Click **Send invite**, then **Confirm**. Google emails the invitation immediately.
8. Click **Open the draft**, check the briefing email in Gmail, and press **Send**.

The attendee briefing, private prep brief and meeting details are saved into the meeting folder (for example `2026-10-06 Pilot review - Prep brief (private).md`). After the meeting, the transcript, summary and live notes go into the same folder.

## Requirements

- The **Google Calendar** and **Gmail** connectors turned on in claude.ai → **Settings → Connectors**, signed in with the Google account you want to send from.
- The first time you use Schedule, the page asks permission to use each connector. Allow it.
- Attendees can use any calendar. Senders need Google Calendar and Gmail for now.

## Privacy and safety

- **The page can only create Gmail drafts, never send email.** Nothing reaches attendees by email until you press Send in Gmail. The calendar invitation is sent by Google only after you confirm twice.
- **Everything sent is plain text you've reviewed.** The AI's words are escaped before going into the invitation and email, so they can't add hidden links or formatting. The only links are the Google Meet link and the calendar buttons, which the copilot builds itself.
- **The AI is told** that the attendee briefing goes to outside people and must not contain internal pricing, strategy, opinions about attendees or details from internal documents. You still review it before anything is sent.
- **The address book stays on your computer** (`contacts.json`, readable only by you) and is never uploaded or shared with the phone companion.
- Guests can see the guest list but can't edit the event or invite others.

## Limits

- One-off meetings only (no recurring series yet).
- Video is always Google Meet. Zoom or Teams links aren't created automatically, though you can put one in the address field.
- Sending from Microsoft 365 / Outlook isn't supported yet. Microsoft *recipients* are fully supported.
