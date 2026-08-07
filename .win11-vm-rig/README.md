# Windows 11 ARM64 dry-run rig

Scripts used for the 08/07/26 Windows verification. Findings:
[`decisions/2026-08-07-windows-arm64-dry-run.md`](../decisions/2026-08-07-windows-arm64-dry-run.md).

- `Autounattend.xml` — fully unattended Win11 ARM64 install (extends UTM's own answer file):
  partitions, installs Pro, skips OOBE, makes a local admin, runs `stage1.ps1` at first logon.
- `stage1.ps1` — first-logon bootstrap: virtio drivers via pnputil, then OpenSSH from bundled
  ARM64 binaries with a pre-authorized key. Offline-capable by design.
- `winssh` / `winpush` — run a command / push a file into the VM.
- `probe1.ps1` — installs the day-one prerequisite stack, with native-vs-emulated arch checks.
- `probe2.sh` — the AIOS probe: clone, CRLF audit, plugin scripts, credential rehearsal.
- `credtest.sh` — credential rehearsal for the **interactive** session (see below).

**No SSH key is stored here on purpose.** Generate a fresh one and re-run `stage1.ps1`'s
authorized_keys step, or pull the old one from the session scratchpad.

**Credential tests must run in the interactive desktop session**, via a scheduled task with
`-LogonType Interactive`. Over SSH they land in session 0 / LogonType 3 (network), which has no
DPAPI user key, and Windows Credential Manager writes fail with a misleading
`Unable to persist credentials with the 'wincredman' credential store`.

**Note:** the local-account password in `Autounattend.xml` is scrubbed to a placeholder.
Set your own throwaway value before rebuilding the setup ISO.
