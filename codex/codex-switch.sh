#!/usr/bin/env bash
# codex-switch — install (or update) the paid ShadowDesk toolkit for a CODEX client.
#
# The Claude path is keyed-switch.sh: it installs a Claude Code plugin from the private
# marketplace. Codex has no plugin support in the IDE extension, but it DOES read Agent Skills
# from $HOME/.agents/skills, so the same SKILL.md folders work — they just have to be copied
# there instead of installed.
#
# Deliberately stateless about secrets: the client's CODE is saved (it is not a token, it is
# already reusable, and the server can revoke it), the GitHub token is fetched fresh on every
# run and never touches disk or a credential helper. That sidesteps the whole credential
# collision class that cost days on the Claude path.
#
#   bash codex-switch.sh <code>   first install, saves the code
#   bash codex-switch.sh          update, reuses the saved code
set -euo pipefail

API="${SHADOWDESK_KEY_API:-https://www.shadowdesk.ai/api/key}"
REPO_URL="https://github.com/n-widmer/shadowdesk-marketplace.git"

die() { echo "STOP: $*" >&2; exit 1; }

# Windows: Git Bash's $HOME is usually %USERPROFILE%, but not always (a set HOME env var wins).
# Codex reads the real user profile, so prefer USERPROFILE when it is present.
base_dir() {
  if [ -n "${USERPROFILE:-}" ]; then
    if command -v cygpath >/dev/null 2>&1; then cygpath "$USERPROFILE"; else printf '%s' "${USERPROFILE//\\//}"; fi
  else
    printf '%s' "$HOME"
  fi
}

BASE="$(base_dir)"
TOOLKIT="$BASE/.shadowdesk/toolkit"
SKILLS="$BASE/.agents/skills"
KEYFILE="$BASE/.shadowdesk/key"

CODE="${1:-}"
if [ -z "$CODE" ] && [ -f "$KEYFILE" ]; then CODE="$(cat "$KEYFILE")"; fi
[ -n "$CODE" ] || die "no code. Run: bash codex-switch.sh <your-code>"

command -v git >/dev/null 2>&1 || die "Git is not installed. Install Git first, then re-run."
command -v curl >/dev/null 2>&1 || die "curl is not available. On Windows use Git Bash, not PowerShell."

TOKEN="$(curl -fsSL "$API?k=$CODE")" || die "that code was not accepted. Ask Nick for a fresh one."
case "$TOKEN" in
  github_pat_*|ghp_*) ;;
  *) die "shadowdesk.ai did not return a usable key. Tell Nick." ;;
esac

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
git -c credential.helper= -c core.askPass= clone --quiet --depth 1 \
  "https://x-access-token:$TOKEN@github.com/n-widmer/shadowdesk-marketplace.git" "$TMP/mkt" \
  || die "could not download the toolkit. Check the internet connection, then tell Nick."
unset TOKEN

SRC="$TMP/mkt/plugins/shadowdesk"
[ -d "$SRC/skills" ] || die "the toolkit download looks wrong (no skills folder). Tell Nick."

# Payload first: several skills call scripts by ${CLAUDE_PLUGIN_ROOT}, so the payload has to sit
# somewhere stable before the skill copies get rewritten to point at it.
rm -rf "$TOOLKIT"
mkdir -p "$TOOLKIT" "$SKILLS"
cp -R "$SRC/." "$TOOLKIT/"

installed=0
for dir in "$TOOLKIT"/skills/*/; do
  name="$(basename "$dir")"
  rm -rf "${SKILLS:?}/$name"
  cp -R "$dir" "$SKILLS/$name"
  # Codex has no plugin root. Point the copies at the payload we just wrote.
  find "$SKILLS/$name" -type f -name '*.md' -exec \
    sed -i.bak -e "s|\${CLAUDE_PLUGIN_ROOT}|$TOOLKIT|g" -e "s|\$CLAUDE_PLUGIN_ROOT|$TOOLKIT|g" {} +
  find "$SKILLS/$name" -type f -name '*.bak' -delete
  installed=$((installed + 1))
done

mkdir -p "$(dirname "$KEYFILE")"
printf '%s' "$CODE" > "$KEYFILE"
chmod 600 "$KEYFILE" 2>/dev/null || true

# Park a copy next to the key so updates are always the same one line, whatever folder the client
# is in and wherever they first ran this from.
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
[ "$SELF" = "$BASE/.shadowdesk/codex-switch.sh" ] || cp "$SELF" "$BASE/.shadowdesk/codex-switch.sh"

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TOOLKIT/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
echo "OK: ${installed} ShadowDesk skills installed for Codex (v${VERSION:-unknown})"
echo "    skills:  $SKILLS"
echo "    update:  bash $BASE/.shadowdesk/codex-switch.sh   (no code needed, it is saved)"
echo "    Start a new Codex chat, then type \$end-session or \$email to use one."
