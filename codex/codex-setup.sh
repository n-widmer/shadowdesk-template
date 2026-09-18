#!/usr/bin/env bash
# codex-setup — turn a cloned ShadowDesk folder into a CODEX folder.
#
# The clone ships for Claude Code: instructions in CLAUDE.md, a .claude/ folder with Claude-only
# skills, settings and the Claude key script. Codex reads none of it, so leaving it there gives the
# client a folder full of files their agent ignores, and two competing instruction files.
#
#   CLAUDE.md          -> AGENTS.md written (what Codex reads); CLAUDE.md moved to a backup
#   .claude/skills/*   -> any skill the client made moves to .agents/skills/ (day-one stays behind:
#                         it installs a Claude plugin). begin-session and capture-voice arrive
#                         Codex-ready from codex-switch.sh.
#   .claude/           -> moved to ~/.shadowdesk/claude-backup-<time>/, never deleted
#   SKILLS.md, CONNECTIONS.md, references/, learn/ -> Claude wording changed to Codex wording
#
# Run it from inside the shadowdesk folder, once, before codex-switch.sh --here:
#   bash codex/codex-setup.sh
set -euo pipefail

die() { echo "STOP: $*" >&2; exit 1; }

[ -f SKILLS.md ] && [ -d references ] || die "run this from inside the shadowdesk folder (cd there first)."

BASE="${USERPROFILE:+$(cygpath "$USERPROFILE" 2>/dev/null || printf '%s' "${USERPROFILE//\\//}")}"
BASE="${BASE:-$HOME}"
BACKUP="$BASE/.shadowdesk/claude-backup-$(date +%Y%m%d-%H%M%S)"

# AGENTS.md is the whole point: Codex reads it, CLAUDE.md it ignores.
if [ -f AGENTS.md ]; then
  echo "kept:    AGENTS.md (already here, not touched)"
elif [ -f codex/AGENTS.md ]; then
  cp codex/AGENTS.md AGENTS.md
  echo "created: AGENTS.md"
else
  curl -fsSL -o AGENTS.md \
    https://raw.githubusercontent.com/n-widmer/shadowdesk-template/main/codex/AGENTS.md \
    || die "could not get AGENTS.md. Check the internet connection."
  echo "created: AGENTS.md (downloaded)"
fi

# Skills the client built while on Claude keep working in Codex: same file format.
mkdir -p .agents/skills memory
[ -f memory/MEMORY.md ] || printf '# Memory\n' > memory/MEMORY.md
if [ -d .claude/skills ]; then
  for dir in .claude/skills/*/; do
    [ -f "$dir/SKILL.md" ] || continue
    name="$(basename "$dir")"
    [ "$name" = "day-one" ] && continue
    if [ ! -d ".agents/skills/$name" ]; then
      cp -R "$dir" ".agents/skills/$name"
      echo "kept:    $name -> .agents/skills/"
    fi
  done
fi

# Move, never delete: anything the client had in .claude/ can be recovered from the backup.
if [ -d .claude ] || [ -f CLAUDE.md ]; then
  mkdir -p "$BACKUP"
  if [ -d .claude ]; then mv .claude "$BACKUP/.claude"; echo "moved:   .claude/ -> $BACKUP"; fi
  if [ -f CLAUDE.md ]; then mv CLAUDE.md "$BACKUP/CLAUDE.md"; echo "moved:   CLAUDE.md -> $BACKUP"; fi
fi

# The client's own docs still talk about Claude. Same wording rules the skills get at build time.
translated=0
for f in SKILLS.md CONNECTIONS.md README.md $(find references learn -type f -name '*.md' 2>/dev/null); do
  [ -f "$f" ] || continue
  before="$(cat "$f")"
  perl -pi -e '
    s#`?/shadowdesk:update`?#`bash ~/.shadowdesk/codex-switch.sh`#g;
    s#`?/shadowdesk:adapt( [a-z<>-]+)?`?#Nick\x27s adapt step (not in Codex yet)#g;
    s#`/shadowdesk:`#`\$`#g;
    s#/shadowdesk:([a-z0-9-]+)#\$$1#g;
    s#\.claude/skills/#.agents/skills/#g;
    s#CLAUDE\.md#AGENTS.md#g;
    s#Claude desktop app#ChatGPT desktop app#g;
    s#Claude Code#Codex#g;
    s#\bClaude\b#Codex#g;
  ' "$f"
  [ "$before" = "$(cat "$f")" ] || translated=$((translated + 1))
done
echo "updated: $translated doc(s) now say Codex instead of Claude"

echo
echo "Done. Next: bash ~/codex-switch.sh --here <code>, then fill in section 1 of AGENTS.md."
