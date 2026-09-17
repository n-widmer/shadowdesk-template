#!/usr/bin/env bash
# codex-setup — turn a freshly cloned ShadowDesk folder into a CODEX folder.
#
# The clone ships for Claude Code: instructions in CLAUDE.md, a .claude/ folder with Claude-only
# skills, settings and the Claude key script. Codex reads none of it, so leaving it there gives the
# client a folder full of files their agent ignores, and two competing instruction files.
#
# This keeps what ports and removes what cannot:
#   CLAUDE.md                     -> AGENTS.md (what Codex actually reads)
#   .claude/skills/begin-session  -> .agents/skills/  (plain Agent Skills, they work as-is)
#   .claude/skills/capture-voice  -> .agents/skills/
#   .claude/skills/day-one        -> removed (installs a Claude plugin, sets Claude permission modes)
#   the rest of .claude/          -> removed (settings, output styles, hooks, keyed-switch.sh)
#
# Run it from inside the shadowdesk folder, once, before the GitHub backup step:
#   bash codex/codex-setup.sh
set -euo pipefail

die() { echo "STOP: $*" >&2; exit 1; }

[ -f SKILLS.md ] && [ -d references ] || die "run this from inside the shadowdesk folder (cd there first)."

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

mkdir -p .agents/skills
for name in begin-session capture-voice; do
  if [ -d ".claude/skills/$name" ]; then
    rm -rf ".agents/skills/$name"
    cp -R ".claude/skills/$name" ".agents/skills/$name"
    echo "moved:   $name -> .agents/skills/"
  fi
done

if [ -d .claude ]; then
  rm -rf .claude
  echo "removed: .claude/ (Claude Code only)"
fi

if [ -f CLAUDE.md ]; then
  rm -f CLAUDE.md
  echo "removed: CLAUDE.md (replaced by AGENTS.md)"
fi

# SKILLS.md names every skill as /shadowdesk:<name>, which does not exist in Codex.
if [ -f SKILLS.md ] && ! grep -q 'In Codex, call a skill' SKILLS.md; then
  printf '> **In Codex, call a skill with `$name`** (for example `$email`), not `/shadowdesk:name`. Or just describe what you need.\n\n%s' "$(cat SKILLS.md)" > SKILLS.md.new
  mv SKILLS.md.new SKILLS.md
  echo "noted:   SKILLS.md now says how to call a skill in Codex"
fi

echo
echo "Done. Fill in section 1 of AGENTS.md with who they are, then run the GitHub backup step."
