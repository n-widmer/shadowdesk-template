#!/usr/bin/env bash
# probe2.sh - AIOS Windows dry run, stage 3. Runs under Git Bash, the shell day-one assumes.
# Exercises the clone + the plugin's own scripts, and the credential path keyed-switch.sh
# flags as "cannot rehearse from a Mac".
exec > >(tee -a /c/aios/probe2.log) 2>&1

section() { echo; echo "=== $* ==="; }

section "shell identity (day-one's silent OS + shell detect)"
echo "uname -s        : $(uname -s)"
echo "uname -a        : $(uname -a)"
echo "MSYSTEM         : ${MSYSTEM:-<unset>}"
echo "HOME            : $HOME"
echo "USERPROFILE     : ${USERPROFILE:-<unset>}"
echo "CLAUDE_CODE_ENTRYPOINT: ${CLAUDE_CODE_ENTRYPOINT:-<unset>}"

section "CLAUDE.md section 7 timestamp rule (bare date, never TZ-overridden)"
echo "date            : $(date '+%m/%d/%y - %H:%M %Z')"
echo "date -u         : $(date -u '+%m/%d/%y - %H:%M %Z')"
echo "TZ env          : ${TZ:-<unset>}"
echo "tzutil          : $(cmd.exe /c tzutil /g 2>/dev/null | tr -d '\r')"
echo "(the MSYS2 gotcha: TZ=... silently returns GMT. Confirm bare date shows a real local zone.)"

section "clone the ShadowDesk OS the way a client does"
cd "$HOME" || exit 1
rm -rf shadowdesk
GIT_TERMINAL_PROMPT=0 git clone https://github.com/n-widmer/shadowdesk-template.git shadowdesk
cd shadowdesk || exit 1
echo "HEAD: $(git rev-parse --short HEAD)"
echo "origin: $(git remote get-url origin)"

section "bundle present?"
ls -la .shadowdesk/.claude-plugin/marketplace.json 2>&1
ls .shadowdesk/plugins/shadowdesk/scripts/

section "line endings (a CRLF checkout breaks bash scripts and the keyed sha256)"
echo "core.autocrlf   : $(git config --get core.autocrlf || echo '<unset>')"
echo ".gitattributes  :"; cat .gitattributes 2>/dev/null
echo "--- every .sh in the clone ---"
crlf_count=0
while IFS= read -r f; do
  if grep -qU $'\r' "$f" 2>/dev/null; then echo "CRLF  $f"; crlf_count=$((crlf_count+1)); else echo "lf    $f"; fi
done < <(find . -name '*.sh' -not -path './.git/*' | sort)
echo "scripts with CRLF: $crlf_count"

section "keyed-switch.sh integrity (the sha256 /shadowdesk:key verifies against shadowdesk.ai)"
sha256sum .shadowdesk/plugins/shadowdesk/scripts/keyed-switch.sh 2>/dev/null \
  || openssl dgst -sha256 .shadowdesk/plugins/shadowdesk/scripts/keyed-switch.sh
echo "(must byte-match the Mac checkout, or every keyed install correctly refuses)"

section "plugin scripts run under Windows node"
node .shadowdesk/plugins/shadowdesk/scripts/print-config.mjs; echo "  -> exit $?"
node .shadowdesk/plugins/shadowdesk/scripts/seed-config.mjs; echo "  -> exit $?"
echo '{"cwd":"'"$PWD"'"}' | node .shadowdesk/plugins/shadowdesk/scripts/backup.mjs sync; echo "  -> backup sync exit $?"
echo '{"cwd":"'"$PWD"'"}' | node .shadowdesk/plugins/shadowdesk/scripts/auto-update.mjs; echo "  -> auto-update exit $?"

section "keyed-doctor.sh under Git Bash"
bash .shadowdesk/plugins/shadowdesk/scripts/keyed-doctor.sh; echo "  -> exit $?"

section "detect_helper: which credential helper Git for Windows actually ships here"
X="$(git --exec-path)"
echo "exec-path: $X"
for h in git-credential-manager git-credential-manager-core git-credential-wincred git-credential-store; do
  if [ -x "$X/$h" ] || [ -x "$X/$h.exe" ]; then echo "$h : in exec-path"
  elif command -v "$h" >/dev/null 2>&1; then echo "$h : on PATH"
  else echo "$h : ABSENT"; fi
done

section "credential store+resolve rehearsal (dummy token, url-scoped exactly as keyed-switch does)"
# This is the surface keyed-switch.sh calls unrehearsable from a Mac: storing is not resolving.
MKT_REPO="n-widmer/shadowdesk-marketplace"
MKT_CRED_URL="https://github.com/${MKT_REPO}.git"
DUMMY="ghp_DRYRUN_NOT_A_REAL_TOKEN_0000000000"
HELPER=""
if [ -x "$X/git-credential-manager" ] || [ -x "$X/git-credential-manager.exe" ] || command -v git-credential-manager >/dev/null 2>&1; then
  HELPER=manager
elif [ -x "$X/git-credential-manager-core" ] || [ -x "$X/git-credential-manager-core.exe" ] || command -v git-credential-manager-core >/dev/null 2>&1; then
  HELPER=manager-core
fi
echo "detect_helper would return: '${HELPER:-<empty -> private-file fallback>}'"

git config --global --replace-all "credential.${MKT_CRED_URL}.helper" ""
git config --global "credential.${MKT_CRED_URL}.useHttpPath" true
if [ -n "$HELPER" ]; then
  git config --global --add "credential.${MKT_CRED_URL}.helper" "$HELPER"
  if printf 'protocol=https\nhost=github.com\npath=%s.git\nusername=x-access-token\npassword=%s\n\n' \
       "$MKT_REPO" "$DUMMY" | git credential-"$HELPER" store 2>&1; then
    echo "store via $HELPER: OK"
  else
    echo "store via $HELPER: FAILED (keyed-switch falls back to the private file)"
  fi
else
  d="$HOME/.shadowdesk"; mkdir -p "$d"; chmod 700 "$d"
  git config --global --add "credential.${MKT_CRED_URL}.helper" "store --file=$d/keyed-credentials"
  printf 'https://x-access-token:%s@github.com/%s.git\n' "$DUMMY" "$MKT_REPO" > "$d/keyed-credentials"
  chmod 600 "$d/keyed-credentials"
  echo "stored in private file $d/keyed-credentials"
fi

echo "--- resolve test: does git hand the credential back for the marketplace url? ---"
printf 'protocol=https\nhost=github.com\npath=%s.git\n\n' "$MKT_REPO" \
  | GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS=echo git credential fill 2>&1 \
  | sed 's/^password=.*/password=<REDACTED-but-present>/'

echo "--- isolation check: an unrelated github.com url must NOT get our credential ---"
printf 'protocol=https\nhost=github.com\npath=n-widmer/shadowdesk-template.git\n\n' \
  | GIT_TERMINAL_PROMPT=0 GCM_INTERACTIVE=never GIT_ASKPASS=echo git credential fill 2>&1 \
  | sed 's/^password=.*/password=<REDACTED-but-present>/'

section "cleanup the rehearsal credential"
if [ -n "$HELPER" ]; then
  printf 'protocol=https\nhost=github.com\npath=%s.git\nusername=x-access-token\n\n' "$MKT_REPO" \
    | git credential-"$HELPER" erase 2>&1
fi
rm -f "$HOME/.shadowdesk/keyed-credentials"
git config --global --unset-all "credential.${MKT_CRED_URL}.helper" 2>/dev/null
git config --global --unset "credential.${MKT_CRED_URL}.useHttpPath" 2>/dev/null
echo "rehearsal credential removed"

echo
echo "=== probe2 complete ==="
