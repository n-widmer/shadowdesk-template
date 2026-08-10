# Windows 11 ARM64 dry run — full AIOS install path verified in a UTM VM

created: 08/07/26 - 14:06 EDT

Ran the client-facing install end to end on a clean Windows 11 machine, to close the gap
`keyed-switch.sh` flags in its own comments: *"the known-unverified surface is Windows GCM, whose
path-matching we cannot rehearse from a Mac."*

That surface now has an answer: **it works.**

## The rig

| | |
|---|---|
| Host | Apple Silicon Mac, macOS 15.7.3, UTM 4.7.5 (upgraded from 3.2.4) |
| Guest | Windows 11 Pro ARM64, 25H2, build 10.0.26200 |
| VM | `Win11-AIOS` — 6 GB RAM, 4 cores, 64 GB NVMe, UEFI, HVF hypervisor |
| Media | Official Microsoft ARM64 ISO, SHA256 `638AA2C8…EB65ADF0` verified against Microsoft's own published hash |
| Install | Fully unattended (custom `Autounattend.xml`), no clicking, OOBE skipped |
| Control | OpenSSH over a UTM port forward, `127.0.0.1:2222 → guest:22` |

## What passed

Every one of these was run on the real guest, not inferred.

1. **Git** — `winget install --id Git.Git -e` → 2.55.0.windows.3, **native ARM64**.
2. **Node** — `winget install --id OpenJS.NodeJS.LTS -e` → v24.19.0, **native arm64**
   (`process.arch` = `arm64`, not emulated x64).
3. **VS Code** — installs via winget.
4. **Claude Code CLI** — `npm i -g @anthropic-ai/claude-code` → 2.1.224, and the installed
   `bin/claude.exe` is a **native ARM64** binary (PE `0xAA64`), not a Node shim. See § C.
5. **Shell detect** — `uname -s` returns `MINGW64_NT-10.0-26200-ARM64`, `MSYSTEM=CLANGARM64`.
   day-one's `MINGW*`/`MSYS*` match fires correctly on ARM64.
6. **Timestamp rule (CLAUDE.md § 7)** — bare `date '+%m/%d/%y - %H:%M %Z'` returns
   `08/07/26 - 13:57 EDT`. Real local zone, not GMT. The rule holds on ARM64 Git Bash.
7. **Clone** — the public template clones with no credential at all.
8. **`keyed-switch.sh` integrity** — sha256 on the Windows checkout is
   `9fd0dd734d75243a1f07b5956acda777dd53e57f9969397be77f8a2f18a0c801`, byte-identical to the Mac.
   The `.gitattributes` `eol=lf` pin does its job; the provenance check will pass on Windows.
9. **Every plugin Node script** — `print-config`, `seed-config`, `backup sync`, `auto-update`,
   and `backup save --final` all run clean and exit 0. The backup hook correctly no-ops rather
   than blocking, and made no commit against Nick's template.
10. **day-one's silent toolkit install** — `claude plugin marketplace add ./.shadowdesk` then
    `claude plugin install shadowdesk@shadowdesk-starter` → **v0.14.10 installed and enabled.**
    No sign-in required for this step.

### 11. The Windows GCM path — the one that mattered

Rehearsed with a dummy token, using `keyed-switch.sh`'s exact `detect_helper` logic and URL scoping:

- `detect_helper` → `manager`; GCM **2.9.0** present at `/clangarm64/bin/git-credential-manager`
- `git credential-manager diagnose` → **7 passed, 0 failed**
- `store` → **exit 0**
- `git credential fill` for `…/shadowdesk-marketplace.git` → **returns `x-access-token` + the token**
- an unrelated `github.com` URL → **does not receive it** (falls through to prompting)

So both halves work on Windows ARM64: storing *and* resolving, with the exact-path scoping intact.

**Important caveat about how this was tested.** Run over SSH, the same sequence **fails**:

```
fatal: Unable to persist credentials with the 'wincredman' credential store.
```

That is an artifact of the test rig, not a client bug. An SSH public-key session lands in
**session 0, LogonType 3 (network)**, which has no DPAPI user key, so Windows Credential Manager
writes fail. The real client sits in **session 2, LogonType 2 (interactive)**. Re-running the
identical script inside the interactive session via a scheduled task is what produced the passes
above. Anyone re-testing this over SSH will see a false failure — use an interactive session.

## What to fix

### A. `keyed-doctor.sh` contradicts itself for free-starter clients — client-facing

A client who has not keyed yet runs `/shadowdesk:doctor` and is told both of these:

```
CHECK: FAIL  Still on the FREE starter toolkit — live updates are not on yet.
INFO: The free starter marketplace is still listed — harmless, but you can ignore it;
      you're on the paid channel now.
```

`keyed-doctor.sh:45-47` emits check 4 whenever the starter marketplace is listed, with no regard
for whether the paid channel is actually active. `doctor.md` instructs Claude to read every
CHECK/INFO line back to the client, so they hear the contradiction directly — on the exact screen
whose whole job is telling them whether the key took.

Fix: gate check 4 on being on the paid channel (reuse the `shadowdesk@shadowdesk` result from
check 1), or reword it so it only reassures once the paid channel is confirmed.

### B. Two `.sh` files check out CRLF on Windows — latent, not currently breaking

`core.autocrlf=true` is the Git for Windows default, and `.gitattributes` pins only
`scripts/*.sh`. So these land with CRLF:

- `skills/brainstorming/scripts/start-server.sh`
- `skills/brainstorming/scripts/stop-server.sh`

I tested both invocation styles — `bash script.sh` and direct `./script.sh` through the shebang —
and **MSYS2's bash tolerates the CRLF; both ran correctly.** So this is an inconsistency and a
latent hazard, not a live break. Worth a one-line fix while it is cheap: widen the pin to
`*.sh text eol=lf`.

### C. ~~npm skips the Claude Code postinstall~~ — RETRACTED, this was a false positive

**Corrected 08/07/26 - 15:02 EDT. No action needed. Do not change day-one for this.**

npm 11.17 emits an advisory during the install:

```
npm warn allow-scripts 1 package has install scripts not yet covered by allowScripts:
npm warn allow-scripts   @anthropic-ai/claude-code@2.1.224 (postinstall: node install.cjs)
```

I first read that as the postinstall being blocked. It was not. The message is npm warning about
**future** enforcement; the script still ran. Proof:

| check | result |
|---|---|
| `bin/claude.exe` vs the `claude-code-win32-arm64` package binary | **byte-identical**, SHA256 `105B3396…C102` |
| `bin/claude.exe` PE machine type | `0xAA64` — **native ARM64** |
| runs standalone | returns `2.1.224 (Claude Code)` |

What `install.cjs` does is copy the matching native binary over a placeholder in `bin/`, so that
"`claude` execs the native binary directly — no Node.js process stays resident." That is exactly
the end state on disk, so it ran.

My original check looked for the wrong artifacts — ripgrep / `vendor/` / `*.node` — rather than
the one artifact that actually matters, the `bin/claude.exe` replacement. Lesson for re-testing:
verify a postinstall by hashing its output, not by guessing at filenames.

**The real result is a positive one:** Claude Code on Windows ARM64 installs and runs as a fully
native ARM64 binary with no resident Node process.

### D. `detect_helper`'s exec-path probe never fires on Windows — robustness note

GCM lives at `/clangarm64/bin/git-credential-manager` (on PATH), **not** in
`git --exec-path` (`C:/Program Files/Git/clangarm64/libexec/git-core`). Only the `command -v`
fallback finds it. Detection works today; just know the exec-path branch is dead weight there and
the PATH branch is load-bearing.

### E. `bash` is not on the Windows system PATH

Git Bash is at `C:\Program Files\Git\bin\bash.exe` and nothing puts it on PATH. day-one already
covers this with `CLAUDE_CODE_GIT_BASH_PATH` — this confirms that guidance is necessary, not
belt-and-braces.

## Fixes applied

### 08/07/26 - 15:02 EDT — findings A and B fixed and verified

**A. `keyed-doctor.sh`** — check 4 now only reassures once the paid channel is actually live.
Check 1 sets `on_paid`; check 4 is gated on it. Verified both directions with a stub CLI:

| state | before | after |
|---|---|---|
| free starter | FAIL "still on FREE starter" **+** INFO "you're on the paid channel now" | FAIL only — contradiction gone |
| paid channel | INFO fires | INFO still fires — no regression |

Then re-run on the real Windows VM: contradiction gone there too.

Safe to edit — only `keyed-switch.sh` is checksum-pinned (it self-verifies `$SELF`);
`keyed-doctor.sh` is not covered by any integrity check.

**B. `.gitattributes`** — added `*.sh text eol=lf` alongside the existing scripts-only rule.
`git check-attr` now reports `eol: lf` for `start-server.sh` and `stop-server.sh`, which
previously checked out CRLF on Windows.

**The check that mattered:** `keyed-switch.sh`'s sha256 is **unchanged** after the
`.gitattributes` edit — still `9fd0dd734d75243a1f07b5956acda777dd53e57f9969397be77f8a2f18a0c801`.
The broader glob is a superset of the existing pin, so the checksum the keyed flow verifies
against shadowdesk.ai is untouched. Had this changed, every keyed install would have started
refusing.

Both changes are uncommitted — Nick's call on when to commit and push to the template.

## Path B — the Claude desktop app on Windows ARM64

updated: 08/07/26 - 14:34 EDT

Everything above was the **VS Code / CLI** surface. Path B is a genuinely different surface, and
my probes confirmed I was never on it: `CLAUDE_CODE_ENTRYPOINT` came back `<unset>` throughout.
So I installed the desktop app in the same VM.

- **A native Windows ARM64 build exists** — `Claude-Setup-arm64.exe` (131 MB) from Anthropic's
  official download host. ARM64 clients are not stuck on x64 emulation.
- **It installs and runs native**: `arch: 'arm64'`, Electron on Node 22.19.0, app version 0.14.10.
- **It auto-updates on launch** — within a minute it had pulled `app-1.26832.0` alongside
  `app-0.14.10`. Version drift is automatic, so pinning a version in client docs will go stale.
- **The desktop app and the CLI share `~/.claude`.** After the CLI-side install, `~/.claude`
  holds `plugins/` and `settings.json`, so the `shadowdesk@shadowdesk-starter` plugin installed
  from the CLI is already visible to the desktop app. One toolkit, both surfaces.
- **`app-0.14.10\claude.exe` does NOT answer CLI subcommands.** Invoking it with `plugin list`
  launched the GUI and ignored the arguments. There is also no separate payload at
  `%LOCALAPPDATA%\claude-code`.

That last point is the operational one: `CLAUDE_CODE_EXECPATH` is set **by the app for the Claude
Code process it spawns**, so it cannot be resolved from outside a running session. This matches
how `keyed-doctor.sh:9-10` and day-one already resolve `CLAUDE_BIN` — nothing is broken — but it
does mean Path B's `plugin` commands can only be exercised from inside a signed-in desktop-app
session. There is no way to pre-verify them headlessly.

### The auto-update broke the app — verify before telling any client

Within a minute of first launch the app auto-updated 0.14.10 → 1.26832.0, and **the updated build
would not start at all**:

| build | PE arch | launch result |
|---|---|---|
| `app-0.14.10` (shipped in the installer) | ARM64 | starts, window title "Claude" |
| `app-1.26832.0` (auto-update) | ARM64 | **exits instantly, `0x80000003` STATUS_BREAKPOINT** |

Squirrel's launcher stub always runs the newest version, so every click on the shortcut hit the
crashing build and nothing opened — with no error dialog. Symptom for a client would be "I
installed Claude and it just doesn't open."

It is not an architecture mismatch: I checked the PE machine type and both builds are genuinely
ARM64. (The `arch=amd64` in Squirrel's RELEASES query string is cosmetic — it pulled from the
`win32/arm64` feed.)

**Do not treat this as a confirmed client-blocking bug yet.** It reproduces reliably in this VM,
but the VM has no real GPU (virtio-ramfb under QEMU), and an instant STATUS_BREAKPOINT in a newer
Electron is exactly the shape of a graphics/ANGLE initialization failure. It needs one launch on
real ARM64 hardware (a Snapdragon X / Surface-class machine) before it means anything about
clients. If it *does* reproduce there, it blocks Path B on ARM64 at step 2 and Nick needs to know
before the next onboarding call.

Workaround applied in the VM so it stays usable:

- renamed the broken `app-1.26832.0` to `BROKEN-app-1.26832.0`
- repointed the Desktop and Start Menu shortcuts straight at `app-0.14.10\claude.exe`
- renamed `Update.exe` → `Update.exe.disabled`, which stops Squirrel re-applying it
  (log then reads `App is not installed, not enabling auto-updates`)

All three are reversible. Note the Start Menu shortcut lives under an **Anthropic** subfolder,
not at the top level.

## Not covered

Signing Claude into a paid account needs Nick's own credential, so these remain untested:

- the `/day-one` chat flow itself
- `/shadowdesk:key <code>` end to end with a real minted key
- `/shadowdesk:doctor` reaching all-green
- **Path B specifically**: `CLAUDE_CODE_EXECPATH` resolution inside a live desktop-app session,
  and the extra `gh` install Path B calls for (the `ABCD-1234` pairing-code backup flow)

The VM is one sign-in away from all of these. Everything mechanical underneath them is verified,
on both surfaces.

## Reusing the VM

- Start: `utmctl start Win11-AIOS` (in `/Applications/UTM.app/Contents/MacOS/`)
- Shell in: `ssh -i <key> -p 2222 aios@127.0.0.1` — key at the session scratchpad,
  local account `aios`, throwaway password set at install time
- The clone under test is at `C:\Users\aios\shadowdesk`
- Credential tests **must** run in the interactive session (scheduled task), never over SSH

### UTM host gotchas worth remembering

- UTM's AppleScript API imports an attached ISO as a **hard disk**, never a CD.
- A partial `drives` update through AppleScript **replaces the entire drive list** — it silently
  deleted the boot disk once. Write the drive list into `config.plist` directly instead.
- Hardlink ISOs into the bundle's `Data/` dir so UTM reads them as bundle-local files: no
  security-scoped bookmark needed and no multi-GB duplicate.
- `utmctl start` runs the VM **headless** — no window, so no screen to look at. The guest's UEFI
  serial console (`address of serial port id 0`) is the way to see boot without a GUI.
