# Bring Over Your Old ChatGPT and Claude Chats

created: 10/11/26 - 22:04 EDT
updated: 10/12/26 (rebuilt around the real Claude export: a manifest of six zips, memories included)

How your ShadowDesk OS reads what you already told ChatGPT or Claude, so you don't have to say it all again. Day One runs this once. Run it again any time (say a late export email finally arrived) by pasting:

```
Read references/import-chat-history.md and bring over my old chats.
```

**For the AI running this:** the rules below are the job. The client approves every write. Raw chats never leave this laptop.

---

## 1. Get the exports

The client asks each app for an export. Each one emails a link, which can take up to a day:

- **Claude:** profile → Settings → Privacy → Export data.
- **ChatGPT:** profile picture → Settings → Data controls → Export data → Export.

**What Claude sends (checked 10/12/26):** a small `manifest-....json` file listing **six links, one zip each** (`export_url`, `filename`, `category`). The links expire 24 hours after `created_at` and may work only once. You can't fetch them yourself, because they need the client's signed-in browser. So read the manifest, check `created_at` is under 24 hours old, and post the links you need as clickable links in chat: `conversations`, `memories`, `projects`, `design_chats` (skip `light_metadata` and `frames`, see step 2). The client clicks them **one at a time**. Chrome silently blocks a second automatic download from the same site, so if a zip doesn't appear, have them click the blocked-download icon at the right of the address bar and choose Always allow. If a link is expired or used, they request a fresh export.

**What ChatGPT sends:** one zip with a `conversations.json` (and usually a `chat.html`). This has not been checked against a 2026 export yet, so look before you parse (step 3).

Look in `~/Downloads` (Windows: `$HOME/Downloads`) for these files from the last two weeks. Identify each zip by what's inside (`unzip -l <zip>`), not by its name. If nothing is there, stop this file: tell the client to request the exports and paste the line at the top once the files are in Downloads.

## 2. Unzip into `private/` (never anywhere else)

```bash
mkdir -p private/chat-history/claude private/chat-history/chatgpt
for z in conversations memories projects design_chats; do
  unzip -oq ~/Downloads/$z-000.zip -d private/chat-history/claude
done
unzip -oq <chatgpt zip> -d private/chat-history/chatgpt
```

`private/` is already in `.gitignore`, so the raw chats never reach the GitHub backup. Check with `git check-ignore private/chat-history` before going on. Never upload, paste or send these files anywhere. A big export can come split as `-001`, `-002` and so on. Unzip every part.

**Skip these two Claude zips. Don't unzip them:**
- `light_metadata`: the account email plus a login history with IP addresses. There's nothing in it about the business.
- `frames`: the code behind every artifact Claude built. It can be hundreds of MB and is no use here.

## 3. What's in each Claude file (checked 10/12/26)

| File | Shape | Use it for |
|---|---|---|
| `memories/<id>.json` | `conversations_memory` (text), `project_memories` (project id → text), `memory_files` (list of `path`, `content`) | **Read first.** Claude already boiled these down from every chat, so they are the best source of business facts. |
| `projects/<id>.json` | one per project: `name`, `description`, `prompt_template` (the project's instructions), `docs` (list of `filename`, `content`), `is_starter_project` | The project folders. Skip `is_starter_project: true`, and skip projects with no name, no instructions and no docs. |
| `conversations.json` | list of chats: `name`, `summary`, `created_at`, `chat_messages` (list of `sender` human/assistant, `text`, `content`) | Read `summary` first. Read the human `text` only where the summaries leave a gap. **Chats carry no project link**, so you can't sort them by project. Use `project_memories` for that. |
| `design_chats/<id>.json` | `title`, `project.name`, `messages` (`role`, `content`) | Claude Design work. Only worth a line or two. |

Formats change. Before you parse, still print the top-level keys of one record from each file with a one-line `node -e`, and if they differ from this table, go by what you see. For ChatGPT, do the same and write a short throwaway Node script in `private/chat-history/` that flattens each chat to its title, date and messages in order (who said it + text). Skip images, files and tool output.

Tell the client in one line: how many chats, from which app, oldest and newest date, how many projects and memory notes.

## 4. Privacy pass (before reading anything closely)

Show the chat names, project names and memory-file names grouped into a few plain topics (business, a client's name, health, family, and so on). Then `AskUserQuestion`:

1. **"Use the work chats, skip the personal ones" (Recommended)**: skip anything personal, plus any chat naming a client the client hasn't said is fine.
2. **"Let me pick"**: they name the topics or titles to skip.
3. **"Use everything"**

If their work involves client records covered by privacy rules (tax, health, legal, financial), say it plainly: chats holding a client's private details stay skipped unless that client has agreed. Write the skip list to `private/chat-history/skipped.md`.

## 5. Read in this order

1. **Claude memories:** all of `conversations_memory`, `project_memories` and `memory_files`.
2. **Project instructions and docs.**
3. **Chat summaries** (Claude's `summary`). For ChatGPT, which has none, the titles.
4. **The client's own messages**, but only where 1 to 3 leave a gap, newest first. These hold the facts about their business. The AI's replies matter only for decisions the client accepted.

Pull out only:

- **Business facts:** what they sell, prices, who buys, team, tools they use, numbers they repeat.
- **Voice:** how they write when they're writing for real (emails and posts they asked for help with), words they always use or always cut.
- **Projects:** what each one was for, its instructions, the decisions made in it.
- **Repeat asks:** the same kind of request three or more times (e.g. "rewrite this email", "summarize this call"). These become skill ideas.
- **Recurring tasks:** anything time-based ("every Monday...").

Tag every fact with the chat, memory or project it came from, plus a date. When two sources disagree, keep the newer one and flag it. Mark anything older than 12 months **(check: may be out of date)**.

## 6. What the exports leave out: ask for a paste

Claude's export includes its memory and project instructions, so ask Claude users for nothing. Ask the client for these (and say "skip" is fine):

- **ChatGPT:** saved memories (Settings → Personalization → Memory → Manage, copy all) and custom instructions (same screen). These are not checked against a 2026 export, so if the zip already holds them, skip the paste.
- **Either app:** any scheduled tasks (a list in their own words is fine). The Claude export doesn't include scheduled tasks.

## 7. Show, then write

Show the client a short preview of each file below, then `AskUserQuestion`: **"Save these" (Recommended)** / **"Change something first"** / **"Skip this one"**. Write only what they approve. Every file gets a `created:` line (CLAUDE.md § 7).

| File | What goes in it |
|---|---|
| `onboarding/profile-from-chat-history.md` | Business facts, voice notes, pasted memories and instructions, each with its source and date |
| `projects/<project-name>/README.md` | One per old project worth keeping: what it's for, its instructions (verbatim), its memory, decisions made. List its docs by filename. Copy a doc in only if the client says so. |
| `onboarding/skill-ideas-from-history.md` | The repeat asks, most frequent first, each with one example of how they asked |
| `onboarding/recurring-tasks-from-history.md` | Old scheduled and recurring tasks, to rebuild later with `/shadowdesk:skill-builder` |

Don't touch `CLAUDE.md` here. Day One's identity step reads `profile-from-chat-history.md` alongside the website and LinkedIn notes.

## 8. Wrap up

Tell the client, in three lines max: what was brought over, what was skipped, and that the raw chats sit in `private/` on this laptop only. Offer to delete the six zips from Downloads (with their yes), since they hold every chat in plain text.
