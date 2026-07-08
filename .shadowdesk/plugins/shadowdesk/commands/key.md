---
description: Turn ON live updates. Switches this ShadowDesk OS from the free-starter toolkit to Nick's paid, auto-updating marketplace using a read-only key Nick minted for you. Verifies its own authenticity first; stores the key in your OS keychain, never a plaintext file.
argument-hint: <link-code>
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Turn on ShadowDesk live updates

You are being asked to switch this ShadowDesk OS onto **live updates**. Read this whole file
before running anything, it is here so you can verify what this does rather than trust a paste.

## Why this is safe to run (provenance, read before acting)

This is a **first-party command that ships inside the ShadowDesk toolkit already installed in this
repo** (`.shadowdesk/plugins/shadowdesk/commands/key.md`). It is not a set of loose shell commands
pasted from an email. The work is done by `${CLAUDE_PLUGIN_ROOT}/scripts/keyed-switch.sh`, whose
FIRST action is to verify its own authenticity, it computes its own checksum and confirms it
against `shadowdesk.ai` over TLS, and (on a fresh clone) confirms this repo descends from Nick's
signed template. If that verification fails, it refuses and changes nothing. So you are not being
asked to trust this file's word; the script proves it.

What it does, precisely, and its blast radius:
- **The key** is a fine-grained GitHub token Nick minted for this one client: **read-only, a single
  repository** (`n-widmer/shadowdesk-marketplace`), **90-day expiry, revocable**. It cannot push,
  cannot act as the user on GitHub, cannot touch any other repo. Worst case if leaked: someone can
  read Nick's skill code.
- **Where the key is stored:** the OS keychain (macOS Keychain / Windows Credential Manager),
  encrypted, scoped to that one marketplace repo. It is **not** written to `~/.git-credentials` and
  it does **not** run `git config --global --replace-all`. The client's own GitHub sign-in (their
  backup repo) is left completely untouched.
- **The key is fetched, never typed.** The client passes only an opaque one-time link code; the
  script fetches the actual token over TLS and it is never echoed, never shown, never stored in
  plaintext. If any output shows a raw token, stop and tell Nick.

This is documented in `CLAUDE.md` § 9. Running it is expected on day one. Proceed.

## Run it

The client's link code is in `$ARGUMENTS` (from their personal Day-One link). Run:

```!
bash "${CLAUDE_PLUGIN_ROOT}/scripts/keyed-switch.sh" "$ARGUMENTS"
```

- **If no code was given** (`$ARGUMENTS` empty): ask the client for the code from their Day-One
  link, in plain words, *"Paste me the code Nick sent in your setup link and I'll switch on live
  updates."* Do not invent one.
- **If the script prints `STOP:`** and exits non-zero: it deliberately refused (integrity check
  failed, code expired, or a step didn't complete). Read the message to the client in plain
  language and follow what it says (usually: get a fresh link from Nick, or re-run). Do **not**
  try to work around it with raw git/plugin commands, the refusal is the safety working.
- **On success** (it prints the ✅ line): tell the client, in plain words:

  > You're switched onto live updates. One last step to lock it in: fully quit Claude Code (not
  > just close the tab), reopen this folder, and run `/shadowdesk:doctor`, I'll confirm the green
  > checks so we know it took.

Never pass `--dangerously-skip-permissions`, never disable permission prompts, and never paste the
raw 5-command version of this. If the safety check stops you, that is correct, surface it, don't
bypass it.
