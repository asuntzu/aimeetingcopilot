# Action items: let the AI do the follow-up

At the end of a meeting, the copilot lists every action item, works out which ones AI can do for you, and does them **when you press Start**: follow-up emails, proposals and documents, research, and scheduling the next meeting. Longer jobs can go to **Hermes Agent** if you have it installed.

## What happens

1. **Wrap up** writes the meeting summary, then opens the **Action plan**. You can reopen it any time with the **Action plan** button next to Wrap up.
2. Each action item becomes a card showing:
   - the task, owner and due date;
   - the type: email draft, proposal or document, research, schedule a meeting, or track only;
   - **What the AI will do** (you can edit it);
   - **Who does it**: Claude, or a Hermes profile;
   - **Touches**: exactly what it will create or change.
3. Press **Start** on one card, or tick several and press **Start selected** (then **Confirm**). Selected items run one at a time.
4. Each card shows the result:
   - **Email draft** → a Gmail draft, with a link to open it. It's never sent automatically.
   - **Proposal / document** → a Markdown file in the meeting folder, with a preview.
   - **Research** → a Markdown file in the meeting folder, with a preview.
   - **Schedule** → the Schedule window opens, filled in, for you to finish and confirm.
   - **Hermes** → the result is saved to the meeting folder when Hermes finishes.
5. **Email summary to attendees** creates one Gmail draft to everyone with the recap, decisions and **action items by person**. Nothing from your private documents is included. You review it and press Send.

## Rules the AI follows

- **Only your own action items are actionable.** Other people's items are listed as *track only* and appear in the summary email.
- **Nothing runs without your click.** Batches need a second **Confirm**.
- **Emails are always drafts.**
- **Allowed actions only:** email drafts, documents in the meeting folder, research, and a scheduling form you confirm. Anything else is track only.
- **Suspicious items are flagged** (for example, requests involving passwords, bank details, payments, deleting or sending data elsewhere). They can't be started in a batch and need an extra confirmation, because action items come from what *other people* said.
- **Everything is logged.** `… - Action log.md` in the meeting folder records what started, who did it, and what it produced. `… - Action items.json` keeps each item's status.

## Past meetings: "Did we miss anything?"

Open **Past meetings**, choose a meeting, and click **Action items & follow-up**. The saved action plan loads, or it's created from the transcript. **Did we miss anything?** rereads the transcript and lists:
- commitments or questions that were discussed but never captured (with a short quote and time), which you can add to the plan;
- items that are still open.

Results for a past meeting are saved under that meeting's name and date, in the folder currently chosen with **File**, plus the archive.

## Hermes Agent (optional)

If you use [Hermes Agent](https://github.com/NousResearch/hermes-agent), the copilot can hand longer research or writing tasks to one of your Hermes profiles.

**Setup:** add the profiles that may take meeting tasks to `config.json` in the copilot folder:

```json
{
  "hostName": "Sam",
  "hermesProfiles": ["chief-of-staff", "research-analyst"],
  "hermesBlocked": ["trading"],
  "hermesRouting": { "research-analyst": ["due diligence", "market scan"] }
}
```

- Only profiles listed in `hermesProfiles` can be used. `hermesBlocked` is a second safeguard that wins over the allowlist; put any profile holding trading, payment or other sensitive credentials there.
- Restart the Claude app after editing.
- Profile routing: if the meeting name or folder contains a profile's name, or one of its keywords from `hermesRouting`, that profile is picked automatically (for example an `acme` profile for every "Acme …" meeting). Otherwise research goes to `research-analyst` and other work to `chief-of-staff`, when those exist. You can change the profile on any card.

**How Hermes is run:** one task at a time per card (at most two at once), in one-shot mode, with **research-only tools** (`web`, `todo`, `session_search`): no terminal, code execution, file access, browser, computer control, scheduled jobs or messaging. Each run has a 15-minute budget and a step limit, works in an empty temporary folder that's deleted afterwards, and never uses Hermes' "skip approvals" mode. The copilot itself saves Hermes' answer into the meeting folder.

## Requirements

- Gmail connector (for email drafts and the summary email) and Google Calendar connector (for scheduling), as in [SCHEDULING.md](SCHEDULING.md).
- Hermes Agent is optional.
