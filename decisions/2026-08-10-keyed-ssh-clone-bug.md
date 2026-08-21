# The 08/05 keyed-marketplace failure: root cause, fix, and proof (v0.14.11)

created: 08/10/26 - 08:55 EDT

The bug that broke Anthony Massa's setup call on 08/05 — logged in Fathom as a "GitHub SSH key
conflict" — is found, fixed, shipped, and proven on a real Windows 11 ARM64 machine, including a
full rehearsal of Anthony's exact remediation path with his real key.

## Root cause (reproduced, not theorized)

`keyed-switch.sh` ran:

```
claude plugin marketplace add n-widmer/shadowdesk-marketplace
```

Given the `owner/repo` **shorthand**, the Claude CLI decides SSH-vs-HTTPS **itself, at runtime**.
On a machine with a usable GitHub SSH setup it resolves `git@github.com:…` — which silently
bypasses the HTTPS token keyed-switch just stored and scoped, and then fails because the client's
own SSH key has no access to the private marketplace repo. Reproduced verbatim in the VM:

```
Failed to add marketplace: Failed to clone marketplace repository: SSH host key is not in your
known_hosts file … Host key verification failed.
```

Two important corollaries, both verified:

- **v0.14.8 (.git-scoped credential) and v0.14.9 (verify_auth) do not fix this.** `verify_auth`
  does its own `git ls-remote` over HTTPS and passes; the flip then fails on SSH. The credential
  work was correct but aimed at a different failure.
- The earlier success on this VM was luck of the environment: with no SSH key present the CLI
  printed `SSH not configured, cloning via HTTPS` and fell back. Anthony's machine has a real
  GitHub SSH key (his own), so he hit the SSH path.

## The fix (v0.14.11, template commit b8796ec)

Pass the **explicit HTTPS url** so there is no runtime choice to make:

```
claude plugin marketplace add https://github.com/n-widmer/shadowdesk-marketplace.git
```

One line, plus the `?v=4` pin bump. Published as generation 4:

- `KEYED_SWITCH_SHA256_V4` set in Vercel, route's v4 pin added (site commit 61e9e9c), deployed to
  production. All generations verified live: bare→v1, v2, v3 unchanged; v4 serves
  `4d3a20e3cc1cec80c740f8478b7814e775e5a589a7faa641f9770ea8dc6adad8`.
- Template pushed, so the approved refresh URL
  (`raw.githubusercontent.com/n-widmer/shadowdesk-template/main/...`) now serves the v4 script —
  confirmed by hashing the download.

## Proof matrix (all on the Windows 11 ARM64 VM, interactive session, live endpoints)

| scenario | result |
|---|---|
| Anthony's v0.14.5 script, credential collision planted | fails exactly as on the call (SSH host key) |
| SSH url, no mitigation (control) | reproduces the failure |
| explicit HTTPS url with SSH keys CONFIGURED | clones clean — the fix holds on Anthony-like machines |
| v4 script, clean room, live shadowdesk.ai hash | `--check` passes, full key run green |
| **Anthony's exact path**: v0.14.5 on disk → refresh from approved URL → `--check` → `/shadowdesk:key <his real code>` → doctor | **all green, doctor 3/3 PASS** |
| his own repo (`ammassa2430/shadowdesk`) after the fix | origin untouched, no credential bleed, only the marketplace-scoped config written |

Test transcripts live on the VM at `C:\aios\*.log`. The VM was sanitized afterwards: Anthony's
PAT erased from Windows Credential Manager (verified gone), scoped config removed, starter
restored.

## What Anthony actually runs (the whole client-facing fix)

His Claude already has `key.md`'s approved refresh path. He asks Claude to refresh the switch
script (it downloads from the approved raw URL, runs `--check`), then runs
`/shadowdesk:key <his code>`, quits and reopens, `/shadowdesk:doctor`. Verified end to end above.
His hand-built Email OS from the call is untouched by this — the marketplace plugin installs
alongside it.

## Ops notes

- The hash endpoint's version map is **hardcoded in the route** (`PINS`), so a new generation
  needs BOTH the Vercel env var and a route edit + deploy. The route's own comment documents this.
- The site repo checkout on this Mac was 4 commits behind origin — the versioned-pin design only
  existed remotely. Pull before touching the site.
- GCM probe gotcha for future tests: `GCM_INTERACTIVE=never` no longer suppresses GCM's UI prompt;
  use `git -c credential.interactive=false` or probes hang forever in scheduled tasks.
- `claude plugin marketplace add <local-dir>` with the marketplace already on disk prints
  "already on disk" and succeeds — safe in reset scripts.
