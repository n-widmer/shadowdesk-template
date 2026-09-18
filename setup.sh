#!/usr/bin/env bash
# setup — is this ShadowDesk OS for Claude Code or for Codex? Works it out, then sets the folder up for it.
#
#   bash setup.sh                        say which agent this folder is for, and what's installed
#   bash setup.sh <KEY_CODE>             same, and for Codex: convert the folder + install the toolkit
#   bash setup.sh --agent codex|claude [<KEY_CODE>]    decide it yourself
#
# How it decides, first match wins:
#   1. --agent
#   2. the agent running this command. Codex sets CODEX_THREAD_ID in every command it runs; Claude Code
#      sets CLAUDECODE=1. (Verified 09/18/26. Both set means one agent launched the other: ambiguous.)
#   3. what is installed on this computer (a plain terminal, no agent running). One found: that one.
#      Both or neither: stop and ask which one the client will use.
#
# Last two lines of output are for the agent reading them:
#   AGENT=codex|claude
#   NEXT=<the day-one file to follow now>
set -euo pipefail
cd "$(dirname "$0")"

die() { echo "STOP: $*" >&2; exit 1; }
[ -f SKILLS.md ] && [ -d references ] || die "run this from the top of your ShadowDesk folder."

AGENT=""; CODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --agent) AGENT="${2:-}"; shift 2 ;;
    *) CODE="$1"; shift ;;
  esac
done
case "$AGENT" in ""|claude|codex) ;; *) die "--agent must be claude or codex" ;; esac

HOMEDIR="${USERPROFILE:+$(cygpath "$USERPROFILE" 2>/dev/null || printf '%s' "${USERPROFILE//\\//}")}"
HOMEDIR="${HOMEDIR:-$HOME}"

# --- what is installed: any trace at all, and say which ones ---------------------------------------------
# An agent counts as installed if ANY of these exist. Each hit is reported, so on a call you can see why.
shopt -s nullglob
L="${LOCALAPPDATA:-/nonexistent}"; R="${APPDATA:-/nonexistent}"; A="${SHADOWDESK_APPS_DIR:-/Applications}"
[ -n "${LOCALAPPDATA:-}" ] && command -v cygpath >/dev/null 2>&1 && L="$(cygpath "$LOCALAPPDATA")"
[ -n "${APPDATA:-}" ] && command -v cygpath >/dev/null 2>&1 && R="$(cygpath "$APPDATA")"
any() { local p; for p in "$@"; do [ -e "$p" ] && return 0; done; return 1; }
EDITORS=(.vscode .vscode-insiders .vscode-oss .cursor .windsurf)
ext() { local d out=(); for d in "${EDITORS[@]}"; do out+=("$HOMEDIR/$d/extensions/$1"*); done; any ${out[@]+"${out[@]}"}; }
NPM_ROOT="$(npm root -g 2>/dev/null || true)"
claude_seen=""; codex_seen=""
c() { claude_seen="${claude_seen:+$claude_seen, }$1"; }
x() { codex_seen="${codex_seen:+$codex_seen, }$1"; }

[ -n "${CLAUDECODE:-}${CLAUDE_CODE_ENTRYPOINT:-}" ]                && c "running now"
command -v claude >/dev/null 2>&1                                  && c "claude command"
any "$HOMEDIR/.claude" "$HOMEDIR/.claude.json"                     && c "Claude Code settings"
any "$HOMEDIR/.local/bin/claude"* "$HOMEDIR/.claude/local" \
    /opt/homebrew/Caskroom/claude-code /usr/local/Caskroom/claude-code \
    ${NPM_ROOT:+"$NPM_ROOT/@anthropic-ai/claude-code"}              && c "Claude Code install"
ext anthropic.claude-code-                                         && c "editor extension"
any "$A/Claude.app" "$HOMEDIR/Applications/Claude.app" "$HOMEDIR/Library/Application Support/Claude" \
    "$L/AnthropicClaude" "$R/Claude" "$L/Packages/Claude_"* "$L/Microsoft/WindowsApps/Claude.exe" \
    "$HOMEDIR/.config/Claude"                                      && c "Claude desktop app"
any "$HOMEDIR/Library/Application Support/JetBrains/"*/plugins/claude-code* \
    "$R/JetBrains/"*/plugins/claude-code*                          && c "JetBrains plugin"

[ -n "${CODEX_THREAD_ID:-}${CODEX_SESSION_ID:-}${CODEX_VERSION:-}" ] && x "running now"
command -v codex >/dev/null 2>&1                                   && x "codex command"
any "$HOMEDIR/.codex" ${CODEX_HOME:+"$CODEX_HOME"}                 && x "Codex settings"
any /opt/homebrew/Caskroom/codex /usr/local/Caskroom/codex \
    ${NPM_ROOT:+"$NPM_ROOT/@openai/codex"}                          && x "Codex install"
ext openai.chatgpt-                                                && x "editor extension"
any "$A/ChatGPT.app" "$A/Codex.app" "$HOMEDIR/Applications/ChatGPT.app" "$HOMEDIR/Applications/Codex.app" \
    "$HOMEDIR/Library/Application Support/com.openai.chat" "$HOMEDIR/Library/Application Support/com.openai.codex" \
    "$L/OpenAI" "$L/Packages/"*OpenAI* "$L/Packages/"*ChatGPT* "$L/Microsoft/WindowsApps/ChatGPT.exe" \
                                                                   && x "ChatGPT/Codex desktop app"
shopt -u nullglob

has_claude="$claude_seen"; has_codex="$codex_seen"
echo "Claude: ${claude_seen:-not found}"
echo "Codex:  ${codex_seen:-not found}"
yn() { [ -n "$1" ] && echo yes || echo no; }

# --- which one ---------------------------------------------------------------------------------------
if [ -z "$AGENT" ]; then
  running_codex="${CODEX_THREAD_ID:-${CODEX_SESSION_ID:-}}"; running_claude="${CLAUDECODE:-}"
  if [ -n "$running_codex" ] && [ -z "$running_claude" ]; then AGENT=codex; echo "running inside: Codex"
  elif [ -n "$running_claude" ] && [ -z "$running_codex" ]; then AGENT=claude; echo "running inside: Claude Code"
  elif [ -n "$running_codex" ] && [ -n "$running_claude" ]; then
    die "this is running inside both Claude Code and Codex (one started the other). Re-run with --agent claude or --agent codex."
  elif [ -n "$has_codex" ] && [ -z "$has_claude" ]; then AGENT=codex
  elif [ -n "$has_claude" ] && [ -z "$has_codex" ]; then AGENT=claude
  else
    die "can't tell which AI this folder is for (installed: Claude $(yn "$has_claude"), Codex $(yn "$has_codex")). Ask which one they'll use, then run: bash setup.sh --agent claude  or  bash setup.sh --agent codex"
  fi
fi

# --- set the folder up --------------------------------------------------------------------------------
if [ "$AGENT" = claude ]; then
  # The template ships ready for Claude Code; day-one installs the toolkit with the key.
  [ -f CLAUDE.md ] || echo "note: this folder was already converted to Codex; to switch back, restore .claude/ and CLAUDE.md from ~/.shadowdesk/claude-backup-*/"
  echo "AGENT=claude"
  echo "NEXT=.claude/skills/day-one/SKILL.md"
  exit 0
fi

# Codex: convert once, then install or update the toolkit into this folder.
if [ -d .claude ] || [ -f CLAUDE.md ]; then
  bash codex/codex-setup.sh
fi
if [ -n "$CODE" ]; then
  bash codex/codex-switch.sh --here "$CODE"
elif [ -f "$HOMEDIR/.shadowdesk/key" ]; then
  bash codex/codex-switch.sh --here
else
  die "Codex needs your setup code to install the toolkit: bash setup.sh <KEY_CODE>"
fi
echo "AGENT=codex"
echo "NEXT=.agents/skills/day-one/SKILL.md"
