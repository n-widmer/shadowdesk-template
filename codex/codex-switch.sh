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
#   bash codex-switch.sh <code>          first install, saves the code
#   bash codex-switch.sh                 update, reuses the saved code
#   bash codex-switch.sh --here [code]   install into ./.agents/skills (this project) instead of
#                                        ~/.agents/skills, and keep updating there from now on
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
GLOBAL_SKILLS="$BASE/.agents/skills"
KEYFILE="$BASE/.shadowdesk/key"
TARGETFILE="$BASE/.shadowdesk/skills-dir"

# Where the skills go. --here pins it to this project, and the choice is remembered so a plain
# update later cannot quietly scatter a second copy into the global folder.
if [ "${1:-}" = "--here" ]; then
  shift
  SKILLS="$(pwd)/.agents/skills"
  mkdir -p "$(dirname "$TARGETFILE")"
  printf '%s' "$SKILLS" > "$TARGETFILE"
elif [ -f "$TARGETFILE" ]; then
  SKILLS="$(cat "$TARGETFILE")"
else
  SKILLS="$GLOBAL_SKILLS"
fi

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

# The skills are written for Claude Code. Rewrite the mechanical parts so they point at things that
# exist in Codex: commands become $skill-names, file paths move from .claude/ to .agents/, the
# instructions file is AGENTS.md. Judgment calls (Claude's question tool, subagents, `claude mcp`)
# cannot be rewritten by sed, so AGENTS.md carries a translation table for those instead.
codexify() {
  find "$1" -type f \( -name '*.md' -o -name '*.json' \) -exec sed -i.bak \
    -e 's|/shadowdesk:update|bash ~/.shadowdesk/codex-switch.sh|g' \
    -e 's|/shadowdesk:adapt|adapt (not available in Codex yet)|g' \
    -e 's|/shadowdesk:\([a-z-]*\)|$\1|g' \
    -e 's|\.claude/skills/|.agents/skills/|g' \
    -e 's|\.claude/last-handoff\.md|.agents/last-handoff.md|g' \
    -e 's|\.claude/last-session\.md|.agents/last-session.md|g' \
    -e 's|\.claude/\.session-state\.json|.agents/.session-state.json|g' \
    -e 's|CLAUDE\.md|AGENTS.md|g' {} +
  find "$1" -type f -name '*.bak' -delete
}

# Claude-only plumbing with nothing to translate into: install-playwright runs `claude mcp add`
# (Codex gets Playwright from ~/.codex/config.toml instead), and the adapt demo demonstrates a
# command Codex does not have. Shipping them would send Codex down a dead end.
CLAUDE_ONLY="install-playwright example-adapt-demo"

installed=0; ours=""
for dir in "$TOOLKIT"/skills/*/; do
  name="$(basename "$dir")"
  case " $CLAUDE_ONLY " in *" $name "*) continue ;; esac
  rm -rf "${SKILLS:?}/$name"
  cp -R "$dir" "$SKILLS/$name"
  # Codex has no plugin root. Point the copies at the payload we just wrote.
  find "$SKILLS/$name" -type f -name '*.md' -exec \
    sed -i.bak -e "s|\${CLAUDE_PLUGIN_ROOT}|$TOOLKIT|g" -e "s|\$CLAUDE_PLUGIN_ROOT|$TOOLKIT|g" {} +
  find "$SKILLS/$name" -type f -name '*.bak' -delete
  codexify "$SKILLS/$name"
  installed=$((installed + 1)); ours="$ours $name"
done

# Codex-only extras Nick keeps next to the plugin in the private repo. They are plain skills with
# no plugin root to rewrite, and they stay behind the same key.
for dir in "$TMP/mkt/codex-extras/skills"/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  rm -rf "${SKILLS:?}/$name"
  cp -R "$dir" "$SKILLS/$name"
  installed=$((installed + 1)); ours="$ours $name"
done

# codex-setup.sh moves these two out of the old .claude/ folder. Translate them too, whichever of
# the two scripts ran first.
for name in begin-session capture-voice; do
  if [ -f "$SKILLS/$name/SKILL.md" ]; then codexify "$SKILLS/$name"; fi
done

# Remove Claude-only skills an older version of this script installed.
for name in $CLAUDE_ONLY; do rm -rf "${SKILLS:?}/$name" "${GLOBAL_SKILLS:?}/$name"; done

# Installing into a project: clear any global copy of the same skills, or Codex lists each twice
# (it does not merge skills that share a name).
if [ "$SKILLS" != "$GLOBAL_SKILLS" ] && [ -d "$GLOBAL_SKILLS" ]; then
  for name in $ours; do rm -rf "${GLOBAL_SKILLS:?}/$name"; done
fi

# The judgment-call half of the translation. Added once to the project's AGENTS.md; a client who
# edited that file keeps their edits, this only appends.
if [ "$SKILLS" != "$GLOBAL_SKILLS" ] && [ -f "$(dirname "$(dirname "$SKILLS")")/AGENTS.md" ]; then
  AGENTS_FILE="$(dirname "$(dirname "$SKILLS")")/AGENTS.md"
  grep -q 'Running skills written for Claude' "$AGENTS_FILE" || cat >> "$AGENTS_FILE" <<'EOF'

## 11. Running skills written for Claude

My skills were first written for Claude Code. When one says something that only exists there, do
the Codex equivalent instead of stopping:

| The skill says | Do this in Codex |
|---|---|
| Ask with `AskUserQuestion` | Ask me in the chat with 2 to 4 numbered options, your recommendation first |
| Invoke another skill with the Skill tool | Run that skill yourself (`$name`) |
| Hand work to a subagent / Task tool | Do it yourself, one step at a time |
| `claude mcp add ...` or `claude plugin ...` | Doesn't apply. Tools live in `~/.codex/config.toml` |
| `CLAUDE_CODE_EXECPATH` or `$CLAUDE_BIN` | Doesn't apply, skip that line |
| `~/.claude/projects/.../memory` | Doesn't exist here. Use Codex memories, or a note in this folder |
| `$key`, `$doctor`, or adapt | Don't exist in Codex. Tell me and move on |
| WebSearch / WebFetch | Use your own web search and page fetch |

Never create a `.claude/` folder here; Codex ignores it.
EOF
fi

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
