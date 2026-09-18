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

# --- what is installed (best effort: a folder, an editor extension, an app, or a command) -------------
has_claude=""; has_codex=""
{ [ -d "$HOMEDIR/.claude" ] || command -v claude >/dev/null 2>&1 \
  || ls -d "$HOMEDIR"/.vscode/extensions/anthropic.claude-code-* >/dev/null 2>&1 \
  || [ -d "${SHADOWDESK_APPS_DIR:-/Applications}/Claude.app" ] || [ -d "${LOCALAPPDATA:-/nonexistent}/AnthropicClaude" ]; } && has_claude=1
{ [ -d "$HOMEDIR/.codex" ] || command -v codex >/dev/null 2>&1 \
  || ls -d "$HOMEDIR"/.vscode/extensions/openai.chatgpt-* >/dev/null 2>&1; } && has_codex=1
yn() { [ -n "$1" ] && echo yes || echo no; }
echo "installed: Claude $(yn "$has_claude"), Codex $(yn "$has_codex")"

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
