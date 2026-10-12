# Bring Over Your Old ChatGPT and Claude Chats

created: 10/11/26 - 22:04 EDT

How your ShadowDesk OS reads what you already told ChatGPT or Claude, so you don't have to say it all again. Day One runs this once. Run it again any time (say a late export email finally arrived) by pasting:

```
Read references/import-chat-history.md and bring over my old chats.
```

**For the AI running this:** the rules below are the job. The client approves every write. Raw chats never leave this laptop.

---

## 1. Find the exports

The client asks each app for an export, and each one emails a download link (it can take up to a day):

- **ChatGPT:** profile picture → Settings → Data controls → Export data → Export.
- **Claude:** profile → Settings → Privacy → Export data.

Look in `~/Downloads` (Windows: `$HOME/Downloads`) for zips from the last two weeks. Identify each one by what's inside (`unzip -l <zip>`), not by its name: a `conversations.json` plus `chat.html` is ChatGPT; a `conversations.json` plus `users.json` (often `projects.json` too) is Claude. If you can't tell, ask.

If no zip is there, stop this file: tell the client to request the exports and paste the line at the top when the emails arrive.

## 2. Unzip into `private/` (never anywhere else)

```bash
mkdir -p private/chat-history/chatgpt private/chat-history/claude
unzip -o <chatgpt zip> -d private/chat-history/chatgpt
unzip -o <claude zip>  -d private/chat-history/claude
```

`private/` is already in `.gitignore`, so the raw chats never reach the GitHub backup. Check with `git check-ignore private/chat-history` before going on. Never upload, paste or send these files anywhere.

## 3. Look before you parse

These export formats change without notice. Don't assume the shape. Print the top-level keys of the first record in each `conversations.json` (and `projects.json` if present) with a one-line `node -e`, then write a short throwaway Node script in `private/chat-history/` that flattens every chat to: title, date, project (if any), and the messages in order (who said it + text). Skip images, files and tool output.

Then tell the client in one line: how many chats, from which app, oldest and newest date.

## 4. Privacy pass (before reading anything closely)

Show the chat titles grouped into a few plain topics (business, a client's name, health, family, and so on). Then `AskUserQuestion`:

1. **"Use the work chats, skip the personal ones" (Recommended)**: you skip anything personal, plus any chat naming a client the client hasn't said is fine.
2. **"Let me pick"**: they name the topics or titles to skip.
3. **"Use everything"**

If their work involves client records covered by privacy rules (tax, health, legal, financial), say it plainly: chats holding a client's private details stay skipped unless that client has agreed. Write the skip list to `private/chat-history/skipped.md`.

## 5. Read, newest first

Read the client's own messages first, since that's where the facts about their business live. The AI's replies only matter for decisions the client accepted. With more than about 300 chats, read the newest 300 plus every project chat during Day One, then note in `private/chat-history/progress.md` where you stopped so a later run picks up from there.

Pull out only:

- **Business facts:** what they sell, prices, who buys, team, tools they use, numbers they repeat.
- **Voice:** how they write when they're writing for real (emails and posts they asked for help with), words they always use or always cut.
- **Projects:** each ChatGPT or Claude project, what it was for, its instructions, the decisions made in it.
- **Repeat asks:** the same kind of request three or more times (e.g. "rewrite this email", "summarize this call"). These become skill ideas.
- **Recurring tasks:** anything time-based ("every Monday...") and any scheduled tasks.

Tag every fact with the chat title and date it came from. Mark anything older than 12 months **(check: may be out of date)**.

## 6. What the export leaves out: ask for a paste

The export may not include these. Ask for each in one message, and say "skip" is fine:

- **ChatGPT:** Settings → Personalization → Memory → Manage (copy all). Custom instructions from the same screen. Any scheduled tasks (Tasks in the profile menu).
- **Claude:** Settings → Capabilities (or Profile) for saved memory and personal preferences. Each project's instructions, from inside the project.

## 7. Show, then write

Show the client a short preview of each file below, then `AskUserQuestion`: **"Save these" (Recommended)** / **"Change something first"** / **"Skip this one"**. Write only what they approve. Every file gets a `created:` line (CLAUDE.md § 7).

| File | What goes in it |
|---|---|
| `onboarding/profile-from-chat-history.md` | Business facts, voice notes, pasted memories and instructions, each with its source and date |
| `projects/<project-name>/README.md` | One per old project worth keeping: what it's for, its instructions, decisions made |
| `onboarding/skill-ideas-from-history.md` | The repeat asks, most frequent first, each with one example of how they asked |
| `onboarding/recurring-tasks-from-history.md` | Old scheduled and recurring tasks, to rebuild later with `/shadowdesk:skill-builder` |

Don't touch `CLAUDE.md` here. Day One's identity step reads `profile-from-chat-history.md` alongside the website and LinkedIn notes.

## 8. Wrap up

Tell the client, in three lines max: what was brought over, what was skipped, and that the raw chats sit in `private/` on this laptop only. If they want them gone, delete `private/chat-history/` (with their yes).
