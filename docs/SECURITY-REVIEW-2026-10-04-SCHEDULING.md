# Security Review: Scheduling Feature — October 4, 2026

**Bottom line:** The new scheduling feature (invitations, briefing emails, address book) was reviewed before release. It was designed so the app can't send email on its own and can't be tricked into putting harmful links or hidden content into what attendees receive. Every protection below was tested with an actual attack attempt; all attempts failed.

## Main risks and how they're handled

- **Sending as you:** the page can only create Gmail *drafts*. You press Send in Gmail yourself. The calendar invite goes out only after two clicks.
- **Leaking private information to outsiders:** the briefing is split into a shared version and a private version. The AI is told not to include confidential details, and you must read and edit the shared version before sending.
- **Booby-trapped text in emails:** names, titles and AI-written text are converted to plain text before going into emails and invites, so they can't add hidden links, images or scripts. *Tested.*
- **Fake meeting links:** only genuine Google Meet and Google links are accepted. Lookalikes such as `meet.google.com.evil.com` are rejected. *Tested.*
- **Tampered calendar files:** text can't sneak extra lines (such as a hidden extra attendee) into the attached calendar file. *Tested.*
- **Address book:** stored only on your computer, readable only by you. Bad emails, scripts in names and malicious time zones are rejected. *Tested.*
- **File tricks:** meeting titles can't be used to write files outside the meeting folder. *Tested.*
- **Least access:** the page may only create calendar events, read your calendar, and create Gmail drafts, nothing else in your Google account.

## Recommended

- Read the attendee briefing before sending, every time.
- Use the Google account you actually want invites to come from.

---

Technical details: [SCHEDULING.md](SCHEDULING.md) and [SECURITY.md](../SECURITY.md).
