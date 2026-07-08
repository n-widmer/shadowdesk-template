# Your ShadowDesk Setup: What to Install Before We Talk

created: 07/07/26-20:19-EDT

Hey. This is your one page for getting ready. It has two parts.

**Section A** is a short list of free and paid sign-ups plus a few programs to install, all on your own, before our call. Budget about 30 minutes. None of it can break anything.

**Section B** is what you and I do together on the call. That part is on me. It takes about 30 minutes and you just follow along.

A quick promise up front, because you should be able to trust every step here: **you will never be asked to paste a password or a secret code into anything.** If any step ever shows you a long random string of letters and numbers and asks you to copy it somewhere, stop right there and text me. That is not part of this.

Works the same on a Mac or a Windows laptop. A Chromebook will not work for this, so grab a real laptop if that is all you have. Each step below tells you exactly what you should see when it worked.

---

## Section A: Before our call (about 30 minutes, on your own)

Do these in order. Each one is a normal download-and-install, the same as installing any app.

### Step 1: Install VS Code (the main window everything lives in)

Go to **https://code.visualstudio.com/download**.

**On a Mac:** Click the **Mac** button. It downloads a zip file. Open your Downloads, double-click the zip, and it becomes an app called **Visual Studio Code**. Drag that app into your **Applications** folder (this is the step people forget). Double-click to open it. If your Mac asks whether you are sure because it came from the internet, click **Open**.

**On Windows:** Click the **Windows** button. Run the file it downloads, click **Next** through the screens, and on the "Additional Tasks" screen tick the boxes for **Add to PATH** and **Add 'Open with Code'**. Click **Install**, then **Finish**.

**You should see:** VS Code opens to a Welcome tab. That is your desk from here on.

### Step 2: Install Node (a small engine a few tools run on)

Go to **https://nodejs.org**. Click the big green **LTS** button (LTS just means the stable version, always pick that one).

**On a Mac:** It downloads a file ending in **.pkg**. Double-click it, then click **Continue, Continue, Agree, Install**. It will ask for your Mac login password. That is normal and expected, type it in. Click **Close**.

**On Windows:** It downloads a file ending in **.msi**. Double-click it, click **Next**, accept the license, keep every default, and click **Install**. If a box pops up asking to allow changes, click **Yes**. Click **Finish**.

**You should see:** the installer finishes with no errors. Nothing else visible happens, that is fine.

### Step 3: Install Git (the tool that saves and backs up your work)

**On a Mac:** Open VS Code. From the top menu click **Terminal**, then **New Terminal**. A panel opens at the bottom. Type this and press Enter:

```
xcode-select --install
```

A small popup appears. Click **Install**, then **Agree**. Let it finish (it can take a few minutes). No password needed.

**On Windows:** Go to **https://git-scm.com/download/win** and the download starts on its own. Run the file. This installer has a lot of screens, so keep it simple: **click Next and accept every default, all the way to Install.** Click **Finish**.

**You should see:** on both, you can confirm it worked. In the VS Code terminal (top menu: Terminal, then New Terminal), type `git --version` and press Enter. It should print something like `git version 2.40`.

### Step 4: Install Claude Code (the AI you will actually talk to)

This is two small pieces. Do both.

**Piece one, the tool.** Open a fresh terminal in VS Code (Terminal, then New Terminal so it is brand new). Type this one line and press Enter:

```
npm install -g @anthropic-ai/claude-code
```

Give it a minute. When it finishes and you are back at a normal prompt, **close that terminal and open a new one**, then type `claude --version` and press Enter.

**You should see:** a version number prints. If it says "not found," you are on an old terminal window, just close it, open a new one, and try again.

**Piece two, the panel.** In VS Code, press **Cmd+Shift+X** on a Mac or **Ctrl+Shift+X** on Windows. A search box opens on the left. Type **Claude Code**, find the one published by **Anthropic**, and click **Install**.

**You should see:** a small spark icon appear near the top right. That is the chat panel where we do the real work.

### Step 5: Sign into your paid Claude account

The tool only runs on a paid Claude plan, not the free one. Pro works fine, Max if you want the top model. Set that up first at **https://claude.ai** if you have not already.

Then, in VS Code, click the spark icon to open the Claude Code panel and click **Sign in**. A browser window opens. Sign in with your paid Claude account, and it sends you back to VS Code already signed in.

**You should see:** the chat panel is ready and does not keep asking you to log in.

### Step 6: Create a free GitHub account

Last one, and there is nothing to install. Go to **https://github.com** and create a free account. This is where your work gets backed up automatically during our call, so it is your safety net. Keep the login handy for the call.

**You should see:** you can log into github.com with your new account. That is all you need.

That is Section A. Once these six are done, you are ready for our call. If you get stuck on any of them, do not sweat it, we can finish it live together.

---

## Section B: On our call (about 30 minutes, I drive)

You do not prepare anything for this part. I walk you through it live and you paste a couple of things I hand you. Here is the whole shape so nothing feels like a surprise.

**1. Open your personal link.** I will send you a private link that is just for you. You open it, and it shows you two things to copy.

**2. Clone ShadowDesk onto your machine.** The link gives you one line to paste into your VS Code terminal. Paste it, press Enter, and a new **shadowdesk** folder lands on your computer. Then you open that folder in VS Code (File, then Open Folder), and if it asks whether you trust the authors, click **Yes**.

**3. Paste one bundle into the chat.** The link gives you one more block of text. You paste that into the **chat panel** (the spark icon), not the terminal, and send it. From here your AI introduces itself and sets everything up for you: your backup, your voice tool, your settings, and a quick look at your business.

**A heads-up on one moment:** partway through, your AI may pause once and ask you to confirm a step that switches on your live updates. **That pause is expected. Just approve it.** And the same promise from the top still holds: you will never be asked to paste a password or a secret code. If any step ever puts a long random string of letters and numbers in front of you and asks you to copy it, stop and tell me right away.

**4. Quit and reopen.** Near the end I will have you fully quit VS Code and open it back up. That is a normal step, it is just what makes everything lock into place.

**5. Run the final check.** After it reopens, you type this one line in the chat panel and send it:

```
/shadowdesk:doctor
```

**You should see:** a set of green checks confirming everything is on and healthy. When those are green, you are fully set up, and we spend the rest of our time building your first real tool on something you actually do every week.

That is it. Do Section A on your own, show up for Section B, and you will be up and running by the time we hang up. Anything at all feels off, text me: 330-284-2578.
