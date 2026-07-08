#!/usr/bin/env bash
# keyed-doctor.sh — the "did live updates actually turn on?" checkpoint behind /shadowdesk:doctor.
# Read-only: it inspects state and (optionally) does one authenticated marketplace refresh to prove
# the key works. It NEVER changes install state and NEVER prints a token. Always exits 0; the
# command reads the CHECK: lines and reports green/red to the client in plain language.
set -u
MKT_REPO="n-widmer/shadowdesk-marketplace"
pass() { printf 'CHECK: PASS  %s\n' "$*"; }
fail() { printf 'CHECK: FAIL  %s\n' "$*"; }
info() { printf 'INFO: %s\n' "$*"; }

# 1. Is the plugin installed, and from the KEYED marketplace (not the free starter)?
inst="$(claude plugin list 2>/dev/null | grep -i 'shadowdesk@' || true)"
if printf '%s' "$inst" | grep -qi 'shadowdesk@shadowdesk\b'; then
  pass "ShadowDesk plugin is installed from the paid marketplace (live updates channel)."
elif printf '%s' "$inst" | grep -qi 'shadowdesk@shadowdesk-starter'; then
  fail "Still on the FREE starter toolkit — live updates are not on yet. Run /shadowdesk:key <code> with the code from your Day-One link."
else
  fail "The ShadowDesk plugin isn't showing as installed. Fully quit Claude Code, reopen this folder, and try again."
fi

# 2. Is the keyed marketplace registered from GitHub (not a local directory)?
mkt="$(claude plugin marketplace list 2>/dev/null || true)"
if printf '%s' "$mkt" | grep -qiE "GitHub \(${MKT_REPO}\)|${MKT_REPO}"; then
  pass "Your live-updates marketplace is connected to Nick's GitHub."
else
  fail "The live-updates marketplace isn't connected yet. Run /shadowdesk:key <code>, then fully quit and reopen Claude Code."
fi

# 3. Does an authenticated refresh actually work? (proves the key is valid and ongoing updates will pull.)
if printf '%s' "$mkt" | grep -qiE "${MKT_REPO}"; then
  if claude plugin marketplace update shadowdesk >/dev/null 2>&1; then
    pass "Checked for updates successfully — your key works and updates will pull on their own."
  else
    fail "Couldn't refresh from the marketplace — the key may be expired or not stored. Ask Nick for a fresh one-time link and run /shadowdesk:key again."
  fi
else
  info "Skipped the live update test until the marketplace is connected."
fi

# 4. Free starter removed? (nice-to-have; not a failure if still present)
if printf '%s' "$mkt" | grep -qi 'shadowdesk-starter'; then
  info "The free starter marketplace is still listed — harmless, but you can ignore it; you're on the paid channel now."
fi
exit 0
