# Security Review — October 4, 2026

**Bottom line:** A full security review is done. 1 serious problem and 9 smaller ones were found and fixed. Each fix was tested by attempting the attack again, and all attacks failed. Fixes are in commit [`6e710b5`](https://github.com/asuntzu/aimeetingcopilot/commit/6e710b5).

## The serious one

A booby-trapped document or something said on a call could have tricked the app into running a program on the computer. Fixed and re-tested.

## Also fixed

- Private files (like security keys) can no longer be reached through the app
- If the page were ever shared, others can't see your live meeting notes
- Only the Claude desktop app can turn on the mic
- Downloads are checked for tampering before install
- Meeting files are now private to your user account
- The AI is told to ignore instructions hidden in documents or conversation

## Privacy

- Audio is never saved or uploaded
- Voice profile is stored as numbers, not a recording
- Only short relevant snippets go to Claude, like a normal chat

## Recommended

- Turn on FileVault (Mac) or BitLocker (Windows) to encrypt your disk
- Tell people the meeting is being transcribed

## Windows

Same fixes, but not yet tested on a real PC.

---

Technical details of every protection: [SECURITY.md](../SECURITY.md). To report a vulnerability privately, use **Security → Report a vulnerability** on this repository.
