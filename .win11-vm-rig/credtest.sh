#!/usr/bin/env bash
# Same rehearsal as probe2, but executed inside the INTERACTIVE desktop session.
exec > /c/aios/credtest.log 2>&1
echo "session check: whoami=$(whoami)"
MKT_REPO="n-widmer/shadowdesk-marketplace"
MKT_CRED_URL="https://github.com/${MKT_REPO}.git"
DUMMY="ghp_DRYRUN_NOT_A_REAL_TOKEN_0000000000"
X="$(git --exec-path)"

echo "=== detect_helper (verbatim logic from keyed-switch.sh) ==="
HELPER=""
case "$(uname -s 2>/dev/null)" in
  MINGW*|MSYS*|CYGWIN*)
    { [ -x "$X/git-credential-manager" ] || command -v git-credential-manager >/dev/null 2>&1; } && HELPER=manager
    if [ -z "$HELPER" ]; then
      { [ -x "$X/git-credential-manager-core" ] || command -v git-credential-manager-core >/dev/null 2>&1; } && HELPER=manager-core
    fi ;;
esac
echo "detect_helper -> '${HELPER}'"
echo "gcm path: $(command -v git-credential-manager 2>/dev/null || echo none)"
echo "gcm version: $(git-credential-manager --version 2>&1 | head -1)"

echo
echo "=== gcm diagnose (credential store availability) ==="
git-credential-manager diagnose 2>&1 | grep -iE "credential store|store =|error|fail|Windows|DPAPI" | head -20

echo
echo "=== STORE via ${HELPER} (this is the step that failed over SSH) ==="
git config --global --replace-all "credential.${MKT_CRED_URL}.helper" ""
git config --global "credential.${MKT_CRED_URL}.useHttpPath" true
git config --global --add "credential.${MKT_CRED_URL}.helper" "$HELPER"
printf 'protocol=https\nhost=github.com\npath=%s.git\nusername=x-access-token\npassword=%s\n\n' \
  "$MKT_REPO" "$DUMMY" | git credential-"$HELPER" store 2>&1
echo "store exit=$?"

echo
echo "=== RESOLVE: does git hand it back for the marketplace url? ==="
printf 'protocol=https\nhost=github.com\npath=%s.git\n\n' "$MKT_REPO" \
  | GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git credential fill 2>&1 \
  | sed 's/^password=.*/password=<PRESENT>/'

echo
echo "=== ISOLATION: an unrelated github.com url must NOT get our credential ==="
printf 'protocol=https\nhost=github.com\npath=n-widmer/shadowdesk-template.git\n\n' \
  | GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never git credential fill 2>&1 \
  | sed 's/^password=.*/password=<PRESENT>/'

echo
echo "=== CLEANUP ==="
printf 'protocol=https\nhost=github.com\npath=%s.git\nusername=x-access-token\n\n' "$MKT_REPO" \
  | git credential-"$HELPER" erase 2>&1
git config --global --unset-all "credential.${MKT_CRED_URL}.helper" 2>/dev/null
git config --global --unset "credential.${MKT_CRED_URL}.useHttpPath" 2>/dev/null
echo "done"
