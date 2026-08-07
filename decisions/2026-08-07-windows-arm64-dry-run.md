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
4. **Claude Code CLI** — `npm i -g @anthropic-ai/claude-code` → 2.1.224, functional.
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

### C. npm now skips the Claude Code postinstall — affects every fresh install

npm 11.17 emitted:

```
npm warn allow-scripts 1 package has install scripts not yet covered by allowScripts:
npm warn allow-scripts   @anthropic-ai/claude-code@2.1.224 (postinstall: node install.cjs)
```

Confirmed skipped: `install.cjs` ships in the package but produced no vendor/native artifacts.
The CLI still works — `--version`, `--help`, and all `plugin` subcommands behave — so day-one is
not blocked. But this is new npm behavior that will hit every client, and it is worth deciding
deliberately whether day-one should pass `--allow-scripts=@anthropic-ai/claude-code` or move to
the native installer.

### D. `detect_helper`'s exec-path probe never fires on Windows — robustness note

GCM lives at `/clangarm64/bin/git-credential-manager` (on PATH), **not** in
`git --exec-path` (`C:/Program Files/Git/clangarm64/libexec/git-core`). Only the `command -v`
fallback finds it. Detection works today; just know the exec-path branch is dead weight there and
the PATH branch is load-bearing.

### E. `bash` is not on the Windows system PATH

Git Bash is at `C:\Program Files\Git\bin\bash.exe` and nothing puts it on PATH. day-one already
covers this with `CLAUDE_CODE_GIT_BASH_PATH` — this confirms that guidance is necessary, not
belt-and-braces.

## Not covered

Signing Claude Code into a paid account needs Nick's own credential, so these remain untested:

- the `/day-one` chat flow itself
- `/shadowdesk:key <code>` end to end with a real minted key
- `/shadowdesk:doctor` reaching all-green

The VM is one sign-in away from all three. Everything mechanical underneath them is verified.

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
