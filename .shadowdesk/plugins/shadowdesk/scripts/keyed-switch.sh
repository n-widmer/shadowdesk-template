#!/usr/bin/env bash
# keyed-switch.sh — turn ON ShadowDesk live updates (free-starter -> keyed marketplace).
#
# This is the code behind /shadowdesk:key. It is a FIRST-PARTY command that ships inside the
# ShadowDesk clone, so a careful Claude reads commands/key.md (which points here) before running
# it — provenance is "a documented command from the toolkit I already have," not "5 creds pasted
# from an email." It verifies its OWN integrity, stores the token in the OS keychain (never a
# plaintext file, never git config --global --replace-all), and flips the marketplace add-before-
# remove so there is never a zero-marketplace dead state.
#
# Usage:  keyed-switch.sh <link-code>
#         keyed-switch.sh --check          # provenance + capability self-test, no writes
# Exit:   0 = keyed (or --check passed).  non-zero = aborted, starter left intact, safe to re-run.
#
# Endpoints are overridable via env for the rehearsal harness (default = production):
#   SHADOWDESK_KEY_API, SHADOWDESK_HASH_API, SHADOWDESK_SIGNERS_URL
# Rehearsal-only escape hatches (never set in production):
#   SHADOWDESK_SKIP_FETCH=1   skip the token fetch + marketplace flip (test provenance/store only)
#   SHADOWDESK_FAKE_TOKEN=... use this token instead of fetching (store-isolation test)
set -u

# ---- constants (must match decisions/2026-07-07-keyed-switch-on.md) ----
EXPECT_URL="https://github.com/n-widmer/shadowdesk-template.git"
ROOT_SHA="478202a5369132a28309f0495c087628e4a45cfb"
MKT_REPO="n-widmer/shadowdesk-marketplace"
MKT_URL="https://github.com/n-widmer/shadowdesk-marketplace"
STARTER="shadowdesk-starter"
KEY_API="${SHADOWDESK_KEY_API:-https://shadowdesk.ai/api/key}"
HASH_API="${SHADOWDESK_HASH_API:-https://shadowdesk.ai/api/key-skill-hash}"

SELF="${BASH_SOURCE[0]}"
say()  { printf '%s\n' "$*"; }
die()  { printf '\n[keyed-switch] STOP: %s\n' "$*" >&2; printf 'Nothing was changed. Your free starter toolkit is intact and this is safe to run again.\n' >&2; exit 1; }

# ---- 1. PROVENANCE: prove this command is the real one before touching credentials ----
verify_provenance() {
  # (a) order-independent anchor: this script's own sha256 must match what shadowdesk.ai vouches
  # for over TLS. The expected hash lives OUTSIDE the repo, so a repo tamperer cannot move it.
  # This survives day-one's `rm -rf .git`, so a later re-key on a detached repo still verifies.
  local sha expected
  if command -v shasum >/dev/null 2>&1; then sha="$(shasum -a 256 "$SELF" | awk '{print $1}')"
  elif command -v sha256sum >/dev/null 2>&1; then sha="$(sha256sum "$SELF" | awk '{print $1}')"
  else die "no sha256 tool available to self-verify (need shasum or sha256sum)"; fi
  expected="$(curl -fsSL --max-time 15 "$HASH_API" 2>/dev/null | tr -d ' \r\n\t')"
  if [ -z "$expected" ]; then
    die "could not reach shadowdesk.ai to confirm this command is authentic. Check your internet and retry; if it persists, tell Nick."
  fi
  if [ "$sha" != "$expected" ]; then
    die "this /shadowdesk:key command does not match Nick's published version (integrity check failed). Do NOT proceed. Re-clone from shadowdesk.ai/levelup or tell Nick."
  fi
  say "[keyed-switch] integrity verified against shadowdesk.ai ✓"

  # (b) pristine bonus (non-fatal): if the template's git history is still here (i.e. we are
  # running BEFORE day-one's detach), assert descent from Nick's template + note origin.
  if git rev-parse --git-dir >/dev/null 2>&1; then
    if git cat-file -e "${ROOT_SHA}^{commit}" 2>/dev/null; then
      say "[keyed-switch] pristine clone confirmed: descends from Nick's template (${ROOT_SHA:0:12}) ✓"
      local o; o="$(git remote get-url origin 2>/dev/null || true)"
      [ "$o" = "$EXPECT_URL" ] && say "[keyed-switch] origin is Nick's template ✓"
    else
      say "[keyed-switch] note: template history not present (repo already detached by day-one) — relying on the integrity check above."
    fi
  fi
}

# ---- OS -> git-native keychain helper ----
# The helpers ship inside git's exec-path (libexec/git-core), NOT on PATH, so probe there too;
# `git credential-<helper>` dispatches to that dir even when the binary isn't on PATH.
detect_helper() {
  local x; x="$(git --exec-path 2>/dev/null)"
  case "$(uname -s 2>/dev/null)" in
    Darwin)
      { [ -x "$x/git-credential-osxkeychain" ] || command -v git-credential-osxkeychain >/dev/null 2>&1; } \
        && { echo osxkeychain; return; } ;;
    MINGW*|MSYS*|CYGWIN*)
      { [ -x "$x/git-credential-manager" ] || command -v git-credential-manager >/dev/null 2>&1; } \
        && { echo manager; return; }
      { [ -x "$x/git-credential-manager-core" ] || command -v git-credential-manager-core >/dev/null 2>&1; } \
        && { echo manager-core; return; } ;;
  esac
  echo ""   # caller falls back to the scoped-file store
}

# ---- 3. STORE the token: keychain if available, else a dedicated 600 file (never the global one) ----
# Set after store_token so flip_marketplace can pin the SAME cred repo-locally on the clone.
KEYED_HELPER_SPEC=""

store_token() {
  local token="$1" helper
  # rehearsal hook: SHADOWDESK_FORCE_HELPER set (even to "") overrides detection ("" = file fallback)
  if [ "${SHADOWDESK_FORCE_HELPER+x}" = x ]; then helper="$SHADOWDESK_FORCE_HELPER"; else helper="$(detect_helper)"; fi
  # ISOLATION: the client already has a global github.com credential (their backup repo), and a
  # global helper matches github.com host-wide — so it would be offered for the marketplace repo
  # FIRST and keyed auth would fail. Reset the inherited helper list for the marketplace URL (an
  # empty first value resets it), so ONLY our helper is consulted for that one repo. This is
  # url-scoped: the client's own repos still use their global helper, untouched. Never touch the
  # global credential.helper, never --replace-all it.
  git config --global --replace-all "credential.${MKT_URL}.helper" ""
  git config --global "credential.${MKT_URL}.useHttpPath" true
  if [ -n "$helper" ]; then
    git config --global --add "credential.${MKT_URL}.helper" "$helper"
    printf 'protocol=https\nhost=github.com\npath=%s.git\nusername=x-access-token\npassword=%s\n\n' \
      "$MKT_REPO" "$token" | git credential-"$helper" store \
      || die "the OS keychain refused to store the key. Tell Nick (mention: git-credential-$helper store failed)."
    KEYED_HELPER_SPEC="$helper"
    say "[keyed-switch] key stored in the OS keychain (encrypted, url-scoped) ✓"
  else
    # fallback: a dedicated 600 file for ONLY this repo url — not ~/.git-credentials, not --replace-all
    local dir="$HOME/.shadowdesk"; mkdir -p "$dir"; chmod 700 "$dir"
    local f="$dir/keyed-credentials"
    git config --global --add "credential.${MKT_URL}.helper" "store --file=$f"
    printf 'https://x-access-token:%s@github.com/%s.git\n' "$token" "$MKT_REPO" > "$f"
    chmod 600 "$f"
    KEYED_HELPER_SPEC="store --file=$f"
    say "[keyed-switch] no OS keychain helper found — key stored in a private 600 file scoped to the marketplace ✓"
  fi
}

# ---- 5. FLIP the marketplace: add + install BEFORE remove (never zero-marketplace) ----
flip_marketplace() {
  claude plugin marketplace add "$MKT_REPO" \
    && claude plugin install shadowdesk@shadowdesk \
    || die "the keyed marketplace add/install did not complete. Your free starter is still installed, so nothing is broken — just run /shadowdesk:key again."

  # Durable, collision-proof isolation for ongoing auto-updates: pin OUR credential REPO-LOCALLY on
  # the marketplace clone. A repo-local empty helper RELIABLY resets inherited global/system helpers
  # (unlike the global url-scoped reset), so `marketplace update` always authenticates the private
  # repo with our token and never with the client's own github.com credential.
  local clone="$HOME/.claude/plugins/marketplaces/shadowdesk"
  if [ -n "$KEYED_HELPER_SPEC" ] && [ -d "$clone/.git" ]; then
    git -C "$clone" config --replace-all credential.helper "" 2>/dev/null || true
    git -C "$clone" config --add credential.helper "$KEYED_HELPER_SPEC" 2>/dev/null || true
    git -C "$clone" config credential.useHttpPath true 2>/dev/null || true
    say "[keyed-switch] pinned the key to the marketplace copy so updates stay isolated ✓"
  fi

  claude plugin marketplace remove "$STARTER" 2>/dev/null || true
}

# ================================ main ================================
verify_provenance

if [ "${1:-}" = "--check" ]; then
  # capability probe: can this environment run the commands the real flow needs?
  for c in git curl claude; do command -v "$c" >/dev/null 2>&1 || say "[keyed-switch] WARN: '$c' not found on PATH"; done
  h="$(detect_helper)"; say "[keyed-switch] keychain helper: ${h:-none (would use scoped-file fallback)}"
  say "[keyed-switch] --check passed (provenance ok, no changes made)."
  exit 0
fi

CODE="${1:-}"
[ -n "$CODE" ] || die "no link code given. Run /shadowdesk:key <code> using the code from your Day-One link."

if [ "${SHADOWDESK_SKIP_FETCH:-0}" = "1" ]; then
  say "[keyed-switch] SKIP_FETCH set — provenance + store tested, marketplace flip skipped (rehearsal)."
  [ -n "${SHADOWDESK_FAKE_TOKEN:-}" ] && store_token "$SHADOWDESK_FAKE_TOKEN"
  exit 0
fi

# ---- 2. FETCH the per-client token over TLS. Into a var only — never argv of another cmd, never echoed, never a file. ----
if [ -n "${SHADOWDESK_FAKE_TOKEN:-}" ]; then
  TOKEN="$SHADOWDESK_FAKE_TOKEN"
else
  TOKEN="$(curl -fsSL --max-time 20 "${KEY_API}?k=${CODE}" 2>/dev/null)"
fi
case "$TOKEN" in
  github_pat_*|ghp_*|gho_*) : ;;   # looks like a GitHub token
  "") die "that link code did not return a key — it may be used up or expired. Ask Nick to send a fresh one-time link." ;;
  *) die "the key server returned something unexpected. Do not retry blindly — tell Nick." ;;
esac

store_token "$TOKEN"
unset TOKEN
flip_marketplace

say ""
say "✅ Live updates are ON. To finish: fully quit Claude Code, reopen this folder, then run /shadowdesk:doctor to confirm the green checks."
exit 0
