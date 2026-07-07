---
name: day-one
description: First-touch on-ramp inside this ShadowDesk OS. Three steps, voice tool, harness settings (bypass mode + model picker), and a fast website scrape plus a LinkedIn paste, followed by a synthesized identity paragraph and a soft-ask handoff to /skill-builder. Use when the user pastes the kickoff bundle from shadowdesk.ai/levelup, says "set me up", "first time", "I just opened this", "walk me through Day One", or when you spot the SHADOWDESK_BUNDLE marker in their first message. One-shot per client.
---

# /day-one

The first-touch on-ramp inside this ShadowDesk OS. Three steps, identity paragraph, soft handoff. I am the on-ramp, not the work.

> Guided session: this skill assumes Nick (or a future facilitator) is screen-sharing with the client on Zoom or in-person. See § Notes for whoever is guiding this session at the bottom.

## Before you start, silent OS + shell detect

Before saying anything, run `uname` in Bash and read the result:

- **`Darwin`** → Mac. Remember it, proceed.
- **`MINGW...` or `MSYS...`** → Windows, and (this is the part that matters) you're running on **Git Bash**, the command line this whole skill is written in. Good. Remember it, proceed.
- **The command errors, the Bash tool can't run at all, or you get anything other than the above** → you're almost certainly on **PowerShell** (Windows' built-in command line), NOT Git Bash. **Stop here.** Every step below is Git Bash; on PowerShell the very first real command fails and onboarding dies confusingly three steps in. Fix the shell first (next section), then re-run `uname` and confirm you now get `MINGW...`/`MSYS...` before continuing.

Don't make the user tell you their OS; just know. But don't paper over a PowerShell shell either, catching it here is the difference between a clean setup and a baffling failure.

### If you're on PowerShell, not Git Bash (Windows only)

Say it plainly, no jargon: *"One quick setup thing before we start. Your computer's using its built-in command line, but your ShadowDesk OS needs a slightly different one that comes free with Git. Let me get that sorted, then we're off."*

1. **Make sure Git is installed** (it brings Git Bash with it). In the VS Code terminal: `winget install --id Git.Git -e --source winget` (winget ships with Win10 1809+/Win11).
2. **Close and reopen VS Code completely.** This is what lets your AI pick up Git Bash. Nine times out of ten this alone fixes it.
3. **Re-run `uname`.** If it now says `MINGW...`/`MSYS...`, you're set, continue with onboarding.
4. **If it STILL isn't on Git Bash** (rare): point Claude Code at Git Bash directly. Set the Windows environment variable `CLAUDE_CODE_GIT_BASH_PATH` to the full path of `bash.exe` (typically `C:\Program Files\Git\bin\bash.exe`), then reopen VS Code. To the user: *"I'm just telling your AI exactly where to find the right command line. One-time thing."*

The plain-English "what even is Git Bash" explainer for the user lives in [`/references/whats-getting-installed.md`](../../../references/whats-getting-installed.md), read it to them if they ask why any of this matters.

### Confirm Node is installed (silent, right after the shell detect)

Still before saying anything, run `node --version` in Bash:

- **You get a version (e.g. `v20.x`)** → good, proceed silently.
- **It errors or says "command not found"** → Node isn't installed. A few skills and the update channel run on it, so fix it now in plain language: *"One small engine your ShadowDesk OS runs on isn't installed yet. Let me point you at the 30-second install."* Mac: download the **LTS** installer from [nodejs.org](https://nodejs.org) and double-click it. Windows (Git Bash): `winget install --id OpenJS.NodeJS.LTS -e --source winget`. Then close and reopen VS Code, re-run `node --version`, and confirm a version before continuing.

## Silent toolkit install (right after the OS detect)

The full ShadowDesk toolkit ships INSIDE this clone (the bundled `.shadowdesk` folder). No key is needed to use it, the key only turns on live updates later. Your job here is to make sure it's switched on. Still before saying anything, run `claude plugin list` in Bash:

- **The output includes `shadowdesk`** → already installed. Say nothing, proceed.
- **It's missing** → install it from the bundle that came with the clone. Confirm you're in the shadowdesk folder (`pwd`), confirm the bundle is there (`ls .shadowdesk/.claude-plugin/marketplace.json`), then run:

  ```
  claude plugin marketplace add "$(pwd)/.shadowdesk"
  claude plugin install shadowdesk@shadowdesk-starter
  ```

  Then tell the client, plainly, no jargon:

  > Switching your toolkit on. One quick thing makes it stick: close VS Code all the way and open it again, then we'll keep going.

  After they reopen, re-run `claude plugin list` and confirm `shadowdesk` shows before moving on. The typeable `/shadowdesk:` commands appear after that reopen.

  **If `shadowdesk` still isn't listed after they reopen:** they probably did *Reload Window* or only closed the tab, which isn't a full restart. Say: *"Let's do a full restart. Quit VS Code completely (Mac: Cmd+Q; Windows: close every VS Code window), wait a second, then open the shadowdesk folder again. We'll pick up right here, nothing's lost."* Then re-run `claude plugin list` and confirm before moving on.

  **If the bundle folder isn't there** (rare, an old clone): fall back to *"Part of your toolkit didn't come through. Re-clone from shadowdesk.ai/levelup, or text Nick."* Don't continue until `claude plugin list` shows `shadowdesk`.

### Also switch on the document tools (best-effort, don't block on it)

These are Anthropic's own free tools for making and reading PDFs, Word, Excel, and PowerPoint files. Public, no key. Run both; if either errors (no internet, etc.), skip silently and move on, this is a nice-to-have, not a gate:

```
claude plugin marketplace add anthropics/skills
claude plugin install document-skills@anthropic-agent-skills
```

They also load on the next reopen, alongside the toolkit above.

## The paste-bundle

The user's first message may contain a kickoff line pasted from `shadowdesk.ai/levelup`:

```
Read .claude/skills/day-one/SKILL.md and follow it to walk me through Day One.
```

If you see it, just start Day One. There is nothing to parse or capture: onboarding needs no API key, not the client's and not Nick's. (An older bundle may still carry a `SHADOWDESK_BUNDLE` / `APIFY_TOKEN` marker. Ignore it, it is not used.)

## Greeting

After the silent OS detect and the silent toolkit check, open with this (ShadowDesk OS-branded, one thought per line, no progress bars):

> Hey. Welcome to your ShadowDesk OS.
>
> You just did the hard part, getting all this onto your computer.
>
> ---
>
> Day One is short. It's the on-ramp.
>
> First I'll turn on your backup so your work is safe. Then three quick things: get your voice tool working, two settings that make me easy to drive, and a fast look at your business so I know who I'm working with.
>
> Once that's done, your ShadowDesk OS is ready to start building real tools for you.
>
> ---
>
> Ready? Type **next**.

Between steps, use a plain progress indicator, no bars:

```
Day One, Step <N> of 3
```

"Type **next**" gates between steps. Reserve `AskUserQuestion` for real either/or choices inside the steps.

## First, turn on the backup (before Step 1)

The kickoff cloned a starter copy from my template. Before anything else, turn it into the client's OWN private, backed-up GitHub repo, and **prove it's real before you move on.** This step has silently half-failed on past setups (origin left pointing at my template, or a publish that made no commit), and nobody caught it until a later push failed. The discipline that kills that: **commit first, then publish, then verify against GitHub for real, then repair it yourself if the verify fails.** Never trust the button; trust the check.

**1. Detach + make the first save (you drive this in Bash, this alone fixes half the old bug).**
Confirm you're in the shadowdesk folder first (`pwd`, never run this anywhere else), then:
```
rm -rf .git
git init -b main
git add -A
git commit -m "ShadowDesk OS initial setup"
```
`rm -rf .git` severs the tie to `n-widmer/shadowdesk-template`; the init + commit guarantee a first save exists (publishing with zero commits was half the recurring failure). Confirm with `git log --oneline -1`.

**2. Create the private repo + push (the client's one click).**
> Click the **Source Control** icon on the left bar (the branch icon). Click **Publish to GitHub**. If it asks you to sign in to GitHub, do it (a browser opens, approve it). Choose **"Publish to GitHub private repository"** and name it **shadowdesk**.

Stress **private**, their real business data lives here. No GitHub account yet? The sign-in screen has a free "Create an account" link.

**3. VERIFY FOR REAL, do not skip, do not trust the button (you drive this in Bash).**
Wait for the client to confirm they clicked through. Then check against GitHub itself, not just a local string:
```
git remote -v          # origin MUST show github.com/<their-account>/shadowdesk, NOT n-widmer
git ls-remote origin   # actually contacts GitHub, success proves the repo exists, is reachable, and auth works
git log --oneline -1   # the commit exists (guaranteed by step 1)
```
The load-bearing check is **`git ls-remote origin`**, a clean local `git remote -v` can still be a dead backup. If `git ls-remote origin` errors, or `git remote -v` is empty / still shows `n-widmer`, the publish did NOT take → go to step 4. Only when `git ls-remote origin` succeeds AND origin is the client's own account do you tell them it's backed up.

**4. Repair it yourself if the button flaked (you drive this, this is the actual fix for the recurring bug).**
Do NOT just re-loop the button. Repair from the terminal:
- **Fast path if `gh` is already installed + authed** (`gh auth status` succeeds): one command does everything , 
  ```
  git remote remove origin 2>/dev/null; gh repo create shadowdesk --private --source=. --remote=origin --push
  ```
  (Don't install `gh` just for this, a stock Mac has no Homebrew, so it isn't guaranteed. If it's not there, use the next path.)
- **No-install path (works everywhere):** guide a 30-second manual repo create , 
  > Go to **github.com/new**, name it **shadowdesk**, set it to **Private**, click **Create repository**, then paste me the URL it shows you.

  When they paste the URL:
  ```
  git remote remove origin 2>/dev/null
  git remote add origin <THEIR-REPO-URL>
  git branch -M main
  git push -u origin main
  ```
  The push authenticates through VS Code's built-in GitHub sign-in, no token needed.

Re-run the step-3 checks after any repair. **Loop step 4 until `git ls-remote origin` succeeds. Never proceed to Step 1 on an unverified backup**, a broken backup that looks fine is exactly the failure we're killing.

On success: *"Done, your ShadowDesk OS is backed up to your own private GitHub, and I confirmed it's live, not just set up. Every time we wrap up I save and back it up automatically; you won't have to think about it."* Then proceed to Step 1.

## Step 1, Wispr Flow voice tool (strong soft gate)

**Why this matters (say if asked):** Voice is the highest-leverage Day-1 install. Talking is ~4x faster than typing and lets you give the long natural answers I'm going to ask for. Without it, every future session is worse.

Recommend Wispr Flow using Nick's affiliate link: `https://ref.wisprflow.ai/nicholas-widmer`. Always tell the client plainly that it is an affiliate link (Nick earns a referral commission if they sign up); never drop that disclosure. It is what Nick uses day to day. Cross-platform (Mac, Windows, iPhone), free to start.

`AskUserQuestion`:

1. **"Got it, Wispr Flow is working" (Recommended)**, accept, proceed to Step 2.
2. **"I already use a different voice tool"**, accept, proceed.
3. **"I'm stuck"**, patient walkthrough, one step at a time.
4. **"I'll skip this for now"**, skip path below.

**Skip path** (only if the user picks option 4):

1. Plain-English cost warning: *"Quick heads-up, you'll get a worse experience here without it. Talking is 4x faster and lets you give me the long answers I'm going to ask for. I highly recommend doing this now. But if you want to defer, totally fine, I'll remind you next session."*
2. `AskUserQuestion` ONE more time: **"Try Wispr Flow now"** / **"No, defer it (Recommended if you really want to skip)"**.
3. If they still defer: write `onboarding/voice-unconfigured.md` containing a single line: *"Voice tool skipped during /day-one on YYYY-MM-DD. /begin-session should re-prompt."* (Substitute today's date.) Proceed to Step 2.

No hard gate. A client who hits an install wall and is told "we can't proceed" closes the window. The re-prompt mechanism catches the lost conversion next session.

**On confirm:** *"From here on, talk, don't type. Let it be messy. I'll clean it up."*

## Step 2, Two settings: bypass-permissions + model picker

Two micro-steps inside Step 2.

### 2a, Bypass-permissions UI verification

The settings file already sets `permissions.defaultMode = "bypassPermissions"`. Honor § Verify before asserting, confirm with the user rather than assume the UI matches.

> See the mode selector at the bottom of the chat? Your settings file already set it to **Bypass permissions**, that means I don't stop and ask you every time I want to write a file or run a command. You stay in control of the big stuff; I stop pestering you about the little stuff.
>
> Check the selector, what does it say?

`AskUserQuestion`:

- **"It says Bypass permissions" (Recommended)**, proceed to 2b.
- **"It says something else"**, *"No problem. Click the selector and pick Bypass permissions."* Wait for confirm, then proceed.

### 2b, Model picker (default Opus 4.8)

> Up at the top there's a model picker. Pick **Opus 4.8** if you see it, that's the deepest-thinking model, best for real business work.
>
> If you don't see Opus 4.8 in your list (depends on your plan), pick whatever's at the top, Sonnet works too.
>
> If the menu hangs for more than ~10 seconds, don't wait, just close it. You can change models any time by typing `/model`.

Wait for any kind of confirm ("done" / "picked it" / "ok"). Don't gate too hard, model picker UI lag is a known v1 trip-up.

**No Max-plan upsell.** Plan-tier upgrade is a sales conversation, not a setup step. If the client volunteers interest in Opus 4.8 and doesn't have it, that's a guide handoff outside /day-one.

## Step 3, Business scrape (website + LinkedIn)

> Step 3.
>
> Before I get into the rest, let me get the quick version of who you are, so I'm not asking you things I could've found myself.
>
> Drop me two links:
>
> 1. Your website.
> 2. Your LinkedIn profile.
>
> Paste both and hit enter. If you don't have one of them, just say so.

### Website scrape (Firecrawl primary, WebFetch silent fallback)

1. **Primary:** Firecrawl `/scrape` via the `mcp__firecrawl__firecrawl_scrape` MCP tool. Uses `FIRECRAWL_AIOS_API_KEY` (already captured at user scope).
2. **Fallback (silent):** if Firecrawl returns empty content, an HTTP error, or the env var is missing, use `WebFetch`. Same extraction targets, narrower data quality. Don't tell the user the fallback fired, silent.
3. **Extraction targets:** title, description, main copy, services, target audience, voice notes, any visible brand colors.
4. **Output:** `onboarding/profile-from-website.md`. Frontmatter-tag which path was used:

   ```yaml
   ---
   source: firecrawl  # or webfetch-fallback
   url: <user's URL>
   scraped: YYYY-MM-DD
   ---
   ```

### LinkedIn (paste, no API)

LinkedIn blocks automated reads, so we don't scrape it, and onboarding uses no scraping key. Ask the client to paste it. Plain and quick:

> Last thing for your profile: open your LinkedIn, copy your headline and your About section, and paste them here. Prefer to skip it? Just say so and we keep moving.

1. If they paste text, use it directly. If they paste a profile URL, try `WebFetch` on it once; LinkedIn usually blocks that, so if it comes back empty just ask for the headline + About text instead. Never block Day 1 over LinkedIn.
2. **If the client has no LinkedIn or wants to skip:** note in the identity synthesis below that only the website was captured, and move on.
3. **Output:** `onboarding/profile-from-linkedin.md`, holding whatever they gave you rendered as clean markdown (headline, about, any roles they mention).

### Neither link works

If the client has no website AND no LinkedIn:

> No problem, we'll get it straight from you. Tell me in your own words: what do you do, who do you serve, and how long have you been doing it?

Capture the answer. Write it to `onboarding/profile-from-client-statement.md`. Proceed to identity synthesis with that as the only source.

## Identity paragraph synthesis (fills CLAUDE.md § 1)

Four-step flow.

### A, Bullet reflect

Reflect what the scrape captured back as 4-5 short bullets. Plain language, no jargon:

> Here's what I picked up:
>
> - **Who you are:** [name + role + headline]
> - **What you sell:** [services / products in plain English]
> - **Who you serve:** [target customer segment]
> - **How you sound:** [voice notes from website / LinkedIn, tone, signature phrases if any]
> - **Where you're based:** [city / region from LinkedIn]
>
> Close to right?

`AskUserQuestion`:

1. **"Yes, that's me" (Recommended)**, proceed to B.
2. **"You missed something"**, *"What did I miss?"*, capture, add to the picture, re-confirm.
3. **"Close enough, we'll build on it"**, accept as-is, proceed to B.

### B, One fact-check question

Ask exactly one, not a survey:

> One quick check, are you involved in more than one business or role? Main thing plus an advisor seat, two ventures, anything like that? If it's just the one, just say so.

Capture the answer. This is the most common scrape miss in 30 seconds.

### C, Synthesize the identity paragraph

Write a single paragraph (5-7 sentences) covering: name + primary role, business + what it sells, who they serve, voice notes (1 sentence on tone), multi-role flag if applicable, location if relevant. CEO-level voice, no jargon. This becomes the always-loaded identity context for every future session.

Format: just the paragraph as the body content under `## 1. Identity` in `CLAUDE.md`. No subheadings inside that section.

### D, Show-write confirm

Display the written paragraph back:

> Here's what I'm putting in your CLAUDE.md as your identity. This loads every time we start a session, so it's worth a quick read:
>
> [paragraph]
>
> Sound right, or want me to tweak it?

`AskUserQuestion`:

1. **"Sounds right" (Recommended)**, write to disk, done.
2. **"Tweak it"**, *"What needs to change?"*, capture, rewrite, re-confirm. One revision pass, then accept.

Write the final paragraph to `CLAUDE.md` § 1 Identity, replacing the empty stub. Do **not** touch any other section of CLAUDE.md.

## Handoff to /skill-builder (soft ask)

First, one short line introducing the toolkit, in plain words:

> One more thing: your full ShadowDesk toolkit is already installed. Type `/shadowdesk:` any time to see every command, and `/shadowdesk:adapt <skill>` wires one up to your own tools.

A couple of skills (like end-session) tune themselves from a plain settings file at [`references/shadowdesk-config.md`](../../../references/shadowdesk-config.md). It ships pre-filled with safe defaults, so everything works today; open it and fill in your own tools (your CRM, your city, your calendar) whenever you're ready. Don't walk the client through it now (it's a "later, on your own time" thing), just let them know it's there.

Then `AskUserQuestion`:

1. **"Build your first skill now" (Recommended)**, invoke `/shadowdesk:skill-builder` via the Skill tool in the same session. Continuity preserved.
2. **"Take a break, I'll be here when you come back."**, show the paste-line explicitly and stop:

   > Nice work today. Your ShadowDesk OS is ready.
   >
   > When you want to build your first skill, paste this line in and hit enter:
   >
   > ```
   > /shadowdesk:skill-builder
   > ```
   >
   > See you soon.

   Then stop. Don't keep talking.

## Out of scope (v1.0)

- **Re-running /day-one.** One-shot per client. Re-invocation behavior is undefined in v1.0.
- **Connector setup.** Connectors are lazy-loaded by `/skill-builder` § Connector gap when a skill needs them. /day-one ends with no connectors active.
- **Voice profile capture.** That's `/capture-voice`'s job (first opt-in update per the "Getting updates" pattern). /day-one does not create `voice-profile.md`.
- **Autonomous client self-onboarding.** v1.0 assumes a guided session. Autonomous mode is v1.1 backlog.
- **Connector setup walkthrough.** CONNECTIONS.md § "Recommended for solo experts" is visible to anyone who reads the file, but /day-one doesn't proactively walk through it.

## Notes for whoever is guiding this session

You (Nick at first, possibly future facilitators) are on Zoom or in-person, screen-sharing the client. Use this as a pre-flight checklist + pacing aid.

### Pre-flight checklist (before /day-one starts)

- [ ] Client has Mac or Windows laptop. **Chromebook = hard no.** ChromeOS (stock OR Crostini) can't reliably run npm / git CLI / browser-helper flows the ShadowDesk OS assumes. Escalate to "buy a real laptop first" before Day 1.
- [ ] VS Code installed.
- [ ] Claude Code extension installed; client signed into Claude account.
- [ ] **Git installed**, the one unavoidable install (the ShadowDesk OS *is* a git repo; without it Step 1's clone fails, like it did on an early setup call). Windows: paste `winget install --id Git.Git -e --source winget` into the VS Code terminal (winget ships with Win10 1809+/Win11). Mac: run `xcode-select --install` and click Install. Then **close and reopen VS Code** so it detects Git. Verify with `git --version`.
- [ ] **Windows only, confirm the shell is Git Bash, not PowerShell.** After the Git install + VS Code reopen, run `uname`. `MINGW...`/`MSYS...` = good (the AI is on Git Bash, the command line the whole ShadowDesk OS is written in). An error or anything else = it's on PowerShell, and onboarding breaks on step one. `/day-one` auto-checks and self-repairs this at its very start, so this is just a belt-and-suspenders glance. Why it matters, in plain English: [`references/whats-getting-installed.md`](../../../references/whats-getting-installed.md).
- [ ] **Node.js installed**, a small engine a few skills run on. Windows: `winget install --id OpenJS.NodeJS.LTS -e --source winget`. Mac: download the **LTS** installer from [nodejs.org](https://nodejs.org) and double-click it (no Homebrew needed, see the explainer). Close and reopen VS Code after; verify with `node --version`.
- [ ] GitHub account exists (free), or create one during the publish step; the sign-in screen has a "Create an account" link. The happy path is VS Code's "Publish to GitHub" (no `gh`, no token), but the backup step now **commits first, verifies against GitHub for real (`git ls-remote origin`), and self-repairs from the terminal** if the button flakes, so a half-failed publish gets caught and fixed in the session instead of surfacing later as a dead backup.
- [ ] `shadowdesk.ai/levelup` → enter passcode → run **Step 1** (clones the starter ShadowDesk OS into Downloads) → choose **File → Open Folder** and pick the `shadowdesk` folder → paste the **Step 2** kickoff bundle into Claude Code chat. `/day-one` starts, and its FIRST action turns the cloned folder into the client's own private GitHub repo (detaches the template, then guides "Publish to GitHub private repository").
- [ ] **Toolkit is keyless now, no install lines, no email key needed.** The full ShadowDesk toolkit ships INSIDE the clone (the bundled `.shadowdesk` folder). `/day-one` installs it from that bundle at the start and has the client reopen VS Code once so the `/shadowdesk:` commands register. The per-client key is no longer part of setup; it only unlocks live updates (`/shadowdesk:update`) later, and gets sent by email when the client signs on. So the kickoff page is now two steps (clone → Day One), not three.

**If the client asks what any of these installs are, don't improvise jargon.** The plain-English, no-background answers for every tool above (VS Code, Git, GitHub, Node.js, Git Bash vs PowerShell, and why we skip Homebrew on Mac) live in [`references/whats-getting-installed.md`](../../../references/whats-getting-installed.md). Read it to them.

> Repo creation moved INTO `/day-one` (the "First, turn on the backup" step) and uses VS Code's built-in Publish-to-GitHub. Decision: `decisions/2026-05-28-onboarding-flow-publish-to-github.md`, **hardened 6/3/26** (commit-first + live `git ls-remote` verify + terminal self-repair) after the publish silently half-failed on two early client setups. (`n-widmer/shadowdesk-template` is a normal public repo, not a GitHub "template" repo, so the old "Use this template" step never actually applied.)

### Pacing rules (during /day-one)

- **30-minute soft cap.** If /day-one runs past 30 min, you've gone too deep, the temptation is to start interviewing, don't. Identity-paragraph depth is /skill-builder's job (when building voice-aware skills), or /capture-voice's job later. Glance, don't dig.
- **Voice tool is the highest-leverage install.** If the client wants to skip, push back gently ONCE then let them skip, the re-prompt mechanism catches it next session.
- **No API key in onboarding.** Day One needs no scraping token. LinkedIn is a paste, the website scrape uses the client's own Firecrawl key (or the WebFetch fallback). If an old /levelup bundle still carries an `APIFY_TOKEN` marker, ignore it.
- **Identity paragraph is locked-in context for every future session.** If the bullet reflect or paragraph looks subtly wrong, push for the correction NOW, fixing it later costs more.

### Guided-vs-autonomous flag

/day-one v1.0 explicitly assumes a guided session. Autonomous client self-onboarding is parked in V5 (v1.1 backlog), a different SKILL.md shape that handles its own pacing without a human reading between the lines.

## Self-ping (do this at the end of every invocation)

Before you finish, increment my row in [`TIME-SAVED.md`](../../../TIME-SAVED.md):

- Skill: `/day-one`
- Manual time per use: 90 min (the rough cost of doing this kickoff by hand without a ShadowDesk OS, installing a voice tool, configuring Claude Code, manually researching my own business notes, writing the identity paragraph)
- Increment "Total uses" by 1
- Recompute "Total saved (cumulative)" as `Total uses × 90 min`
- Update "Last used" to today's date

If `/day-one` doesn't have a row yet, add one with the same fields.
