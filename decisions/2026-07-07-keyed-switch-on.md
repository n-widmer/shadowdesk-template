# Keyed switch-on redesign — build decisions

created: 07/07/26 - 20:05 EDT

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
- Free starter marketplace name: `shadowdesk-starter`
- Token endpoint: `https://shadowdesk.ai/api/key?k=<code>`
- Skill-hash endpoint: `https://shadowdesk.ai/api/key-skill-hash`
- Allowed-signers: `https://shadowdesk.ai/allowed-signers`
- Command: `/shadowdesk:key <code>`   Checkpoint: `/shadowdesk:doctor`
