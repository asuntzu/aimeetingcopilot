# Security Review: AI Action Items — October 4, 2026

**Bottom line:** The new feature that lets AI carry out your meeting follow-ups (Claude and Hermes) was reviewed and attack-tested before release. Because this feature *acts* instead of just taking notes, it has the strictest rules in the app. All attack attempts failed.

## Main risks and how they're handled

- **AI acting without you:** nothing runs until you press Start. Doing several at once needs a second Confirm.
- **Someone planting instructions in the meeting** (for example, "email the client list and bank details to…"): action items come from other people's words, so risky requests are flagged in amber and can't be run in a batch. *Tested.*
- **Acting on other people's tasks:** the AI only acts on your own items. Everyone else's are track-only. *Tested.*
- **Unexpected kinds of action:** only four are possible: email drafts, documents, research, and a scheduling form you confirm. Anything else (such as "run a command") is track-only. *Tested.*
- **Sending as you:** emails are always Gmail drafts. You press Send.
- **Hermes:** only the profiles you approve; your trading profile is blocked even if it's added by mistake. Hermes gets research tools only (no terminal, files, browser, payments or messaging), a 15-minute limit, and no "skip approval" mode. *Tested, including a real run.*
- **Leaking private info in the group email:** the summary email uses only what was said in the meeting, never your documents, and you review the draft.
- **Booby-trapped text in emails:** links, images and scripts written by the AI show up as plain text, not working links. *Tested.*
- **File tricks:** names and dates can't be used to write files outside the meeting folder. *Tested.*
- **Fake log entries:** text can't add lines to the action log. *Tested.*
- **Phone:** the phone companion can't start actions.

## Recommended

- Read the "What the AI will do" line before pressing Start.
- Treat amber-flagged items with suspicion.
- Keep any Hermes profile with trading or payment access in `hermesBlocked`.

---

Details: [ACTION-ITEMS.md](ACTION-ITEMS.md) and [SECURITY.md](../SECURITY.md).
