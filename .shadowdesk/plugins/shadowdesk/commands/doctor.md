---
description: Confirm your live updates are on and working. A quick green/red checklist after you switch on your key, so you know it took.
disable-model-invocation: true
allowed-tools: Bash, Read
---

# Are live updates on? (checkpoint)

Run the check, then read the results back to the client as a plain green/red list. This is
read-only, it changes nothing.

```!
bash "${CLAUDE_PLUGIN_ROOT}/scripts/keyed-doctor.sh"
```

Read the `CHECK: PASS` / `CHECK: FAIL` / `INFO:` lines above and report them in plain,
non-technical language:

- **All checks PASS:** say it warmly and stop, e.g. *"You're all set, live updates are on and
  I confirmed they're working. Every time Nick ships a new skill, yours pulls it in on its own.
  Nothing for you to do."*
- **Any check FAILs:** do NOT improvise fixes. Read the failing line's guidance to the client
  (usually: run `/shadowdesk:key <code>` with the code from their Day-One link, or fully quit and
  reopen Claude Code, or ask Nick for a fresh one-time link). If a failure mentions an expired or
  missing key, the fix is a fresh link from Nick, not a manual git or plugin command.

Never paste raw git/credential/plugin commands to "fix" a failure here; route the client back to
`/shadowdesk:key` or to Nick.
