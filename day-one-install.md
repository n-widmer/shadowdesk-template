# Your ShadowDesk Setup: What to Install Before We Talk

created: 07/07/26 - 20:19 EDT
updated: 07/08/26 - 15:40 EDT (before the call = VS Code + Claude only; Git and Node install live together)
updated: 08/01/26 - 14:08 EDT (added Path B: Claude desktop app, no VS Code)

Hey. This is your one page for getting ready. It has two parts.

**Section A** is short: install two free programs and do two quick sign-ups, on your own, before our call. Budget about 15 minutes. None of it can break anything.

**Section B** is what you and I do together on the call. That part is on me. It takes about 30 to 40 minutes and you just follow along.

A quick promise up front, because you should be able to trust every step here: **you will never be asked to paste a password or a secret code into anything.** If any step ever shows you a long random string of letters and numbers and asks you to copy it somewhere, stop right there and text me. That is not part of this.

Works the same on a Mac or a Windows laptop. A Chromebook will not work for this, so grab a real laptop if that is all you have.

One more choice before you start: this page walks the **VS Code** setup. If you would rather use the **Claude desktop app** (Claude's own program, no VS Code involved), jump to **Path B** at the bottom. It is shorter.

---

## Section A: Before our call (about 15 minutes, on your own)

Just two installs and two sign-ups. That is it, the rest we do together.

### 1. Install VS Code (the main window everything lives in)

Go to **https://code.visualstudio.com/download**.

**On a Mac:** Click the **Mac** button. It downloads a zip file. Open your Downloads, double-click the zip, and it becomes an app called **Visual Studio Code**. Drag that app into your **Applications** folder (this is the step people forget). Double-click to open it. If your Mac asks whether you are sure because it came from the internet, click **Open**.

**On Windows:** Click the **Windows** button. Run the file it downloads, click **Next** through the screens, and on the "Additional Tasks" screen tick the boxes for **Add to PATH** and **Add 'Open with Code'**. Click **Install**, then **Finish**.

**You should see:** VS Code opens to a Welcome tab. That is your desk from here on.

### 2. Install Claude (the AI you will actually talk to)

First, set up a **paid** Claude plan at **https://claude.ai** if you have not already. The tool only runs on a paid plan, not the free one. Pro works fine, Max if you want the top model.

Then add the Claude extension inside VS Code: press **Cmd+Shift+X** on a Mac or **Ctrl+Shift+X** on Windows. A search box opens on the left. Type **Claude Code**, find the one published by **Anthropic**, and click **Install**. When it is in, click the little spark icon near the top right to open the chat panel, and sign in with your paid Claude account (a browser window opens, approve it, and it sends you back signed in).

**You should see:** a chat panel that is ready and does not keep asking you to log in. That panel is where we do the real work.

### 3. Create a free GitHub account

Nothing to install. Go to **https://github.com** and create a free account. This is where your work gets backed up automatically during our call, so it is your safety net. Keep the login handy.

**You should see:** you can log into github.com with your new account.

That is Section A. VS Code, Claude, a paid Claude plan, and a free GitHub account. If you get stuck on any of it, do not sweat it, we finish it live together.

---

## Section B: On our call (about 30 to 40 minutes, I drive)

You do not prepare anything for this part. I walk you through it live. Here is the whole shape so nothing feels like a surprise.

**1. Install two small tools, together.** First thing on the call, I have you install **Git** and **Node**, the two engines your setup runs on. They are quick, a couple of minutes each, and I talk you through every click. We do these live so you do not have to wrestle with them alone.

**2. Open your personal link.** I send you a private link that is just for you. You open it, enter the passcode I gave you, and it shows you two things to copy.

**3. Copy ShadowDesk onto your machine.** The link gives you one line to paste into your VS Code terminal. Paste it, press Enter, and a new **shadowdesk** folder lands on your computer. Then you open that folder in VS Code (File, then Open Folder), and if it asks whether you trust the authors, click **Yes**.

**4. Paste one bundle into the chat.** The link gives you one more block of text. You paste that into the **chat panel** (the spark icon), not the terminal, and send it. From here your AI introduces itself and sets everything up: your backup, your voice tool, your settings, your live updates, and a quick look at your business.

**A heads-up on one moment:** partway through, your AI may pause once and ask you to confirm the step that switches on your live updates. **That pause is expected. Just approve it.** And the same promise from the top still holds: you will never be asked to paste a password or a secret code. If any step ever puts a long random string in front of you and asks you to copy it, stop and tell me.

**5. Quit and reopen, then the final check.** Near the end I have you fully quit VS Code and open it back up (that is what locks everything in). Then you type this one line in the chat panel and send it:

```
/shadowdesk:doctor
```

**You should see:** a set of green checks confirming everything is on and healthy.

**6. Build your first tool.** With the boring part done, we spend the rest of our time building your first real tool, on something you actually do every week, so you watch it work before we hang up.

---

## Path B: the Claude desktop app (no VS Code)

Prefer Claude's own desktop app over VS Code? Great, this path is shorter, and the same promise from the top holds the whole way: **you will never be asked to paste a password or a secret code into anything.**

### Before our call (about 10 minutes, on your own)

1. **Set up a paid Claude plan** at **https://claude.ai** if you have not already. Pro works fine, Max if you want the top model.
2. **Install the Claude desktop app** from **https://claude.ai/download**. Open it and sign in with that paid account. **You should see:** the Claude app open and signed in, ready to chat.
3. **Create a free GitHub account** at **https://github.com**. This is where your work gets backed up during our call. Keep the login handy.

That is the whole pre-call list. No VS Code, no extension.

### On our call (30 to 40 minutes, I drive)

1. **Install two small tools, together.** Git and Node, the same two engines from the main path, a couple minutes each. I talk you through every click. On this path there is one extra tiny install, GitHub's own helper tool, and I walk you through that one too.
2. **Open your personal link**, enter the passcode I gave you.
3. **Copy ShadowDesk onto your machine, the easy way.** There is no terminal in the Claude app, and that is the point: you paste the copy line from your link **straight into the Claude chat**, and your AI runs it for you. Then the app asks which folder to work in, and you pick the new **shadowdesk** folder.
4. **Paste the bundle into the same chat.** From here it is the same as the main path: your AI introduces itself and sets up your backup, your voice tool, your settings, your live updates, and a quick look at your business.
5. **One extra moment on this path:** when we switch on your backup, GitHub shows a short pairing code (something like `ABCD-1234`) and your AI tells you exactly where to type it. That is a pairing code, not a password. The no-secrets promise holds.
6. **Quit and reopen, then the final check.** Near the end you fully quit the Claude app, open it back up, pick the shadowdesk folder again, and type `/shadowdesk:doctor` in the chat. **You should see:** green checks.
7. **Build your first tool**, same as the main path, before we hang up.

---

That is it. Do Section A (or Path B's before-call list) on your own, show up for the call, and you will be up and running by the time we hang up. Anything at all feels off, text me: 330-284-2578.
