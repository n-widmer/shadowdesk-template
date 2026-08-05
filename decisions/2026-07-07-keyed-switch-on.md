# Keyed switch-on redesign — build decisions

created: 07/07/26 - 20:05 EDT
updated: 08/05/26 - 14:19 EDT

Implements `ShadowDesk/KEYED-ONBOARDING-REDESIGN.md` (3-agent brainstorm output). This file
records the decisions the build locked, INCLUDING two facts the brainstorm couldn't know that
changed the trust design. Do not re-litigate without re-reading both.

## The refusal we are killing
The old keyed switch-on was 5 raw shell commands pasted into the client's Claude chat. The
client's own Claude refused it as credential-theft (undocumented, plaintext token to disk,
`git config --global --replace-all` stomp, unknown marketplace). Correct refusal. See
`ShadowDesk/KEYED-CLIENT-ONBOARDING.md` (old) for what we are replacing.

## Two grounding facts that reshaped the trust anchor
1. **day-one repoints `origin`** to the client's own private backup repo (the "turn on the
   backup" step). So "verify `git remote get-url origin` == template URL" only holds BEFORE that.
2. **day-one runs `rm -rf .git`** (SKILL.md line ~123) to detach the template, then `git init`.
   This DELETES the template's entire git history — root commit, any signed commits, origin. Any
   trust anchor that reads git history is destroyed the moment the backup step runs.

## Locked trust design (survives both facts)
- **PRIMARY integration point: `/shadowdesk:key` runs at the START of day-one, BEFORE the backup
  step's `rm -rf .git`.** In that window the clone is pristine, straight from
  `github.com/n-widmer/shadowdesk-template` over TLS, with full history. Strongest provenance.
- **Order-independent programmatic anchor: content-integrity hash-pin.** The switch script
  sha256's ITSELF and compares against a value served by `shadowdesk.ai` over TLS (anchored
  OUTSIDE the repo, so a repo-tamperer can't move it). Works pristine OR detached (survives
  `rm -rf .git`), so a later re-key (token renewal on an already-detached client repo) still
  verifies.
- **Pristine bonus checks (belt + suspenders, non-fatal if absent):** if the template root commit
  `478202a5369132a28309f0495c087628e4a45cfb` is reachable, assert it (proves descent from Nick's
  template); if `origin` still equals the template URL, note it; if Nick-SSH-signed commits are
  present, verify the key-command commit.
- **Honest residual (documented, accepted):** any in-repo check can be removed by whoever controls
  the repo, so this does not stop a sophisticated attacker who fully impersonates Nick's
  distribution channel. That threat is out of scope for the product's real risk, which is
  (a) churn from a refusal and (b) token leakage — both addressed. The content-hash + documented
  first-party command give a well-informed Claude concrete, non-prose reasons to proceed.

## Locked storage design (no scary disk write — the other half of killing the refusal)
- **Primary: OS keychain**, git-native. `osxkeychain` (Mac, ships with Xcode CLT git) / `manager`
  (Windows GCM, ships with Git for Windows). Configured as
  `credential.https://github.com/n-widmer/shadowdesk-marketplace.helper <helper>` — additive and
  URL-scoped, NEVER `--replace-all`, plus `...useHttpPath=true` so the marketplace credential is
  keyed to the full path and does NOT collide with the client's OWN `github.com/<client>/shadowdesk`
  backup credential. Stored via `git credential approve` on stdin; token then `unset`.
- **Fallback (only if no keychain helper resolvable): a dedicated 600 file scoped to the
  marketplace URL** via `credential.<url>.helper "store --file=$HOME/.shadowdesk/keyed-credentials"`
  in a 700 dir — NOT the global `~/.git-credentials`, NOT `--replace-all`. Isolated, bounded
  blast radius (read-only single-repo 90-day token). Abort rather than ever writing the global file.
- The rehearsal harness decides keychain-vs-fallback empirically per OS (does keychain both
  authenticate the marketplace AND leave the client's own github.com cred untouched).

### Isolation — the real crux, RESOLVED + TESTED (07/07 on this Mac)
Testing found the isolation is the hard part, and was a LATENT BUG even in the old "rehearsed-green"
flow (it only passed because the rehearsal used a CLEAN credential env). Findings:
- **Authenticated marketplace URL** (`marketplace add https://x-access-token:TOKEN@github.com/...`)
  is REJECTED: it leaks the token in plaintext in `claude plugin marketplace list` output AND
  persists it in `~/.claude/settings.json`. Never do this.
- **Global git credential helpers COLLIDE:** the client's own global github.com credential (their
  backup repo) is offered for the marketplace repo first, so `marketplace add`/`update` would auth
  as the client and fail. A global url-scoped empty-reset does NOT reliably clear a same-file
  generic helper (verified failing on git 2.50).
- **RESOLUTION (verified):** pin the credential REPO-LOCALLY on the marketplace clone
  (`~/.claude/plugins/marketplaces/shadowdesk/.git/config`): an empty-then-add helper repo-locally
  DOES reset inherited global/system helpers, so `marketplace update` authenticates with OUR token
  and the client's own repos are untouched. Tested: marketplace-repo fill → our token; client-repo
  fill → their cred. `flip_marketplace()` does this after `marketplace add`.
- **Initial `marketplace add` clone** (before the repo-local pin exists) uses global helpers, so it
  is only collision-free if no client github credential exists yet — which is why keying must run
  BEFORE day-one's backup/publish step (client hasn't pushed → no github cred yet). This makes the
  key-before-backup ordering LOAD-BEARING, not just convenient.
- Storage stays keychain-primary (no leak in any list) with the scoped-600-file fallback; the
  repo-local pin is what guarantees ongoing-update isolation regardless of which store was used.
- Still requires a real-machine rehearsal WITH Nick's token on Mac AND Windows (osxkeychain vs GCM
  path-matching for the initial add) — this is part of P3's ship-gate.

### 08/05/26 - 14:19 EDT — CORRECTION: the "unreliable global reset" was the .git suffix all along

The 07/07 finding above ("a global url-scoped empty-reset does NOT reliably clear a same-file
generic helper, verified failing on git 2.50") was a **misdiagnosis**. The reset works fine. What
failed was the SCOPE never matching.

- git matches `credential.<url>.*` on the **exact url path**. The marketplace clone's remote is
  `https://github.com/n-widmer/shadowdesk-marketplace.git` (verified against the real clone), but
  `store_token()` scoped its config to `$MKT_URL`, which had **no `.git` suffix**. So the entire
  scoped block — the empty reset, `useHttpPath`, and our helper — never applied to the actual
  credential request. The client's own github.com helper answered instead.
- Reproduced on git 2.50.1 and fixed: with the scope corrected to `${MKT_URL}.git`, the empty reset
  DOES clear both a same-file generic helper AND the Xcode CLT system-level
  `credential.helper = osxkeychain`, and our token wins the initial `marketplace add`.
- **Why every rehearsal passed anyway:** `rehearse-keyed-v2.sh` only ever resolved credentials
  through the repo-local pin (check 4), which is applied AFTER `marketplace add` succeeds and is
  unscoped, so it was never sensitive to the suffix. The global-scope path that `marketplace add`
  actually uses was untested. It also sets `GIT_CONFIG_NOSYSTEM=1`, hiding the Xcode osxkeychain
  helper that exists on every Mac. Added as **check 5** (global url-scope, no repo-local pin,
  competing credential present) — it fails on the old script and passes on the fixed one.
- **Consequence for the load-bearing ordering above:** keying before day-one's backup step is no
  longer the only thing preventing a collision — the corrected scope beats a pre-existing github
  credential outright. Keep the ordering (it is still the cleanest state), but it is now
  defence-in-depth rather than the single point of failure.
- **Rejected while fixing:** also scoping the suffix-less url as belt-and-suspenders. Check 5
  proved it is dead config — the token is stored under `path=…marketplace.git`, so with
  `useHttpPath=true` the suffix-less scope can never resolve a credential. One exact scope only.

### 08/05/26 - 14:50 EDT — the hash pin is now VERSIONED (it had to be)

Shipping the fix above exposed a structural flaw in the pin itself. `/api/key-skill-hash` served a
single value and the script compares it exactly, so moving the pin **correctly refuses every
un-keyed client still holding the previous copy of the script** — and those clients have no
supported way to refresh it: the free starter is a frozen directory marketplace inside their clone,
`/shadowdesk:update` hard-stops at the un-keyed gate, and day-one has already run `rm -rf .git` so
there is nothing to pull from. Un-keyed client + changed script = bricked `/shadowdesk:key`.

- **Resolution:** the endpoint is keyed by generation. `?v=2` → `KEYED_SWITCH_SHA256_V2` (current),
  `?v=1` or no param → `KEYED_SWITCH_SHA256` (pre-08/05 script). The no-param default MUST stay on
  v1 forever, because scripts that shipped before versioning send no param. Unknown v → 503.
- The script pins its own generation in the `HASH_API` default (`…/key-skill-hash?v=2`). The
  rehearsal harness overrides the whole URL, so it never sees the param.
- **Shipping a new generation:** add `KEYED_SWITCH_SHA256_V<n>` in Vercel, add the line in
  `route.ts`, bump the `?v=` in the script. Retire an old generation only once no client holds it.
- Live-verified 08/05: v1 → `7f1237ca…`, v2 → `07b1e9b7…`, no-param → v1, `?v=99` → 503.

### 08/05/26 - 16:00 EDT — v0.14.9: stop assuming the store works, PROVE it (pin v3)

Anthony is on **Windows**. Everything above was verified on macOS against `osxkeychain`. Splitting
what actually carries over:

- **Carries over (high confidence):** the `.git` scope fix. `credential.<url>.*` matching is core
  git, identical on every platform. Git for Windows also ships a system-level generic
  `credential.helper = manager`, the exact analogue of the Xcode `osxkeychain` inject, and the
  scoped empty-reset clears a generic system helper — proven on Mac, same git code on Windows.
- **Does NOT carry over (unrehearsable from a Mac):** the **store → resolve round trip**. Windows
  GCM is a different implementation with its own path matching and its own GitHub auth provider;
  `git credential-manager store` succeeding does not prove `git` will hand that credential back for
  this URL. `detect_helper`'s `[ -x "$x/git-credential-manager" ]` probe also relies on MSYS `.exe`
  resolution.

Rather than ship another untested assumption onto a client call, the script now **proves it at
runtime and heals itself**:

- `verify_auth()` runs `git ls-remote` against `MKT_CRED_URL` after storing and BEFORE the flip.
  The repo is private and the client is not a collaborator, so success can only mean OUR key was
  offered. Prompts hard-disabled (`GIT_TERMINAL_PROMPT=0`, `GCM_INTERACTIVE=never`, `GIT_ASKPASS`,
  `SSH_ASKPASS`) so it can never hang on a call.
- If the keychain store does not resolve, main re-stores via the **private-file store** (plain
  `store --file=`, core git, no platform variance) and re-verifies. Only a proven key reaches the
  flip; otherwise it dies with the starter intact.
- A keychain that refuses the store no longer aborts either — it falls through to the file store.
- **This makes `detect_helper` non-critical:** a wrong or missed Windows probe now degrades to the
  file store, which is verified, instead of failing the install.

**Real-token rehearsal — the 07/07 ship-gate is CLOSED.** `verify-keyed-real-token.sh` runs
Anthony's actual minted PAT against the real private marketplace over the network: the client's own
credential cannot open the repo, our key can, the key opens nothing else of Nick's, and a bogus key
correctly fails. `verify-keyed-selfheal.sh` simulates the precise Windows-GCM failure (a helper that
accepts `store` and returns nothing on `get`) and confirms the heal path end to end with the real
token. Neither ever prints the token. **Still genuinely unverified: Windows itself.** The design no
longer depends on it being right — that is the point.

### Verification that now gates this flow
- `ShadowDesk/rehearse-keyed-v2.sh` — clean-cred, mocked pin. **Check 5 added**, covering the
  global url-scope that `marketplace add` actually uses. Fails on the old script, passes on the new.
- `ShadowDesk/verify-keyed-competing-cred.sh` — **new.** Runs against PRODUCTION shadowdesk.ai with
  `GIT_CONFIG_NOSYSTEM` deliberately NOT set, so the Xcode CLT system `credential.helper =
  osxkeychain` is live, plus a planted client github.com credential. This is the machine state the
  clean-cred rehearsal could never produce.
- `ShadowDesk/verify-keyed-real-token.sh` — **new.** Real minted PAT, real private repo, real
  network. Closes the 07/07 ship-gate.
- `ShadowDesk/verify-keyed-selfheal.sh` — **new.** Fake helper that stores but never resolves;
  proves the runtime heal path.

Run **all four** before shipping any keyed-switch change. They live under `ShadowDesk/` (gitignored,
alongside `keyed-ops/`), because the last two read a real client token.

## Locked delivery design
- Token NEVER pasted, NEVER human-visible. Client pastes only an opaque one-time link code `k`.
- `shadowdesk.ai/api/key?k=<code>` returns the per-client PAT once over TLS, then burns the code.
- Per-client gate (the `k`), never the shared `shadowdesk-2026` passcode.
- Nick mints a fine-grained PAT per client (read-only, single repo `shadowdesk-marketplace`,
  90-day), tracked in `ops/client-keys.json`, revoked on churn via `ops/revoke-client-key`.

## Constants (single source — every artifact must match these exactly)
- Template URL: `https://github.com/n-widmer/shadowdesk-template.git`
- Template root SHA: `478202a5369132a28309f0495c087628e4a45cfb`
- Keyed marketplace repo: `n-widmer/shadowdesk-marketplace`  (marketplace name: `shadowdesk`)
- Credential-scope URL: `https://github.com/n-widmer/shadowdesk-marketplace.git` — **the `.git`
  suffix is load-bearing**, see the 08/05/26 correction above. Never scope without it.
- Free starter marketplace name: `shadowdesk-starter`
- Token endpoint: `https://shadowdesk.ai/api/key?k=<code>`
- Skill-hash endpoint: `https://shadowdesk.ai/api/key-skill-hash`
- Allowed-signers: `https://shadowdesk.ai/allowed-signers`
- Command: `/shadowdesk:key <code>`   Checkpoint: `/shadowdesk:doctor`
