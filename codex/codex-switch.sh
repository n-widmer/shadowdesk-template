#!/usr/bin/env bash
# codex-switch — install (or update) the paid ShadowDesk toolkit for a CODEX client.
#
# The Claude path installs a Claude Code plugin. Codex reads the same Agent Skills format from
# .agents/skills, so this copies skills there. The skills are already written for Codex: the
# publish step (AIOS-plugin/build.mjs) builds a Codex edition next to the Claude plugin in the
# private repo and refuses to ship it if any Claude-only wording is left. This script only copies
# that edition and fills in the paths that differ per machine.
#
# Secrets: the client's CODE is saved (reusable, revocable, not a token). The GitHub token is
# fetched fresh each run, handed to git through the environment (never argv, never .git/config,
# never a credential helper), and dropped when the clone finishes.
#
#   bash codex-switch.sh <code>          first install, saves the code
#   bash codex-switch.sh                 update, reuses the saved code
#   bash codex-switch.sh --here [code]   install into ./.agents/skills (this project, backed up with
#                                        it) instead of ~/.agents/skills, and keep updating there
set -euo pipefail

API="${SHADOWDESK_KEY_API:-https://www.shadowdesk.ai/api/key}"
REPO_URL="${SHADOWDESK_MKT_URL:-https://github.com/n-widmer/shadowdesk-marketplace.git}"
REF="${SHADOWDESK_MKT_REF:-}"   # test a staged branch before it reaches main

die() { echo "STOP: $*" >&2; exit 1; }

# Windows: Git Bash's $HOME is usually %USERPROFILE%, but a set HOME env var wins. Codex reads the
# real user profile, so prefer USERPROFILE when it is present.
base_dir() {
  if [ -n "${USERPROFILE:-}" ]; then
    if command -v cygpath >/dev/null 2>&1; then cygpath "$USERPROFILE"; else printf '%s' "${USERPROFILE//\\//}"; fi
  else
    printf '%s' "$HOME"
  fi
}
# Paths written INTO skill files must work from PowerShell and Node too, not just Git Bash:
# C:/Users/... (cygpath -m) does, /c/Users/... does not.
native() { if command -v cygpath >/dev/null 2>&1; then cygpath -m "$1"; else printf '%s' "$1"; fi; }
# sed replacement text: escape the characters sed treats specially (a Windows name can hold &).
sed_escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

BASE="$(base_dir)"
STATE="$BASE/.shadowdesk"
TOOLKIT="$STATE/toolkit"
DATA="$STATE/data"
GLOBAL_SKILLS="$BASE/.agents/skills"
KEYFILE="$STATE/key"
TARGETFILE="$STATE/skills-dir"
MANIFEST="$STATE/installed-skills"
MARK=".shadowdesk-managed"

# --- where the skills go -------------------------------------------------------------------------
if [ "${1:-}" = "--here" ]; then
  shift
  # Only ever pin to a ShadowDesk folder. Run from a subfolder or anywhere else, this used to plant a
  # second full copy there and move all future updates to it.
  # SKILLS.md + references/ only exist at the root. AGENTS.md alone is not enough: client subfolders
  # get their own AGENTS.md.
  if [ ! -f SKILLS.md ] || [ ! -d references ]; then
    die "run --here from the top of your ShadowDesk folder (the one with SKILLS.md). You are in: $(pwd)"
  fi
  [ "$(pwd -P)" != "$(cd "$BASE" && pwd -P)" ] || die "--here was run from your home folder, not your ShadowDesk folder."
  SKILLS="$(pwd)/.agents/skills"
elif [ -f "$TARGETFILE" ]; then
  SKILLS="$(cat "$TARGETFILE")"
else
  SKILLS="$GLOBAL_SKILLS"
fi
PREVIOUS_SKILLS="$( [ -f "$TARGETFILE" ] && cat "$TARGETFILE" || printf '%s' "$GLOBAL_SKILLS")"

CODE="${1:-}"
if [ -z "$CODE" ] && [ -f "$KEYFILE" ]; then CODE="$(cat "$KEYFILE")"; fi

command -v git >/dev/null 2>&1 || die "Git is not installed. Install Git first, then re-run."
command -v curl >/dev/null 2>&1 || die "curl is not available. On Windows use Git Bash, not PowerShell."

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT INT TERM HUP

# --- download the Codex edition -------------------------------------------------------------------
export GIT_TERMINAL_PROMPT=0 GIT_ASKPASS= SSH_ASKPASS=
if [ -n "${SHADOWDESK_MKT_URL:-}" ]; then
  # Test harness: a local copy of the private repo, no key exchange.
  git -c core.autocrlf=false -c core.eol=lf clone --quiet --depth 1 ${REF:+--branch=$REF} "$REPO_URL" "$TMP/mkt" \
    || die "could not read the test marketplace at $REPO_URL"
else
  [ -n "$CODE" ] || die "no code. Run: bash codex-switch.sh <your-code>"
  TOKEN="$(curl -fsSL "$API?k=$CODE")" || die "that code was not accepted. Ask Nick for a fresh one."
  case "$TOKEN" in
    github_pat_*|ghp_*) ;;
    *) die "shadowdesk.ai did not return a usable key. Tell Nick." ;;
  esac
  AUTH="$(printf 'x-access-token:%s' "$TOKEN" | base64 | tr -d '\n')"
  unset TOKEN
  GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="http.https://github.com/.extraHeader" \
  GIT_CONFIG_VALUE_0="Authorization: Basic $AUTH" \
    git -c credential.helper= -c core.autocrlf=false -c core.eol=lf \
      clone --quiet --depth 1 ${REF:+--branch=$REF} "$REPO_URL" "$TMP/mkt" \
    || { unset AUTH; die "could not download the toolkit. Check the internet connection, then tell Nick."; }
  unset AUTH
fi

EDITION="$TMP/mkt/codex"
[ -d "$EDITION/skills" ] || die "the toolkit download has no Codex edition yet. Tell Nick."

# --- install --------------------------------------------------------------------------------------
rm -rf "$TOOLKIT"
mkdir -p "$TOOLKIT" "$SKILLS" "$DATA"
cp -R "$EDITION/toolkit/." "$TOOLKIT/"

R_TOOLKIT="$(sed_escape "$(native "$TOOLKIT")")"
R_SKILLS="$(sed_escape "$(native "$SKILLS")")"
R_DATA="$(sed_escape "$(native "$DATA")")"
fill() {
  find "$1" -type f \( -name '*.md' -o -name '*.json' -o -name '*.yaml' \) -exec sed -i.bak \
    -e "s|@@TOOLKIT@@|$R_TOOLKIT|g" -e "s|@@SKILLS@@|$R_SKILLS|g" -e "s|@@DATA@@|$R_DATA|g" {} +
  find "$1" -type f -name '*.bak' -delete
}
fill "$TOOLKIT"

# Skills this client switched off (`disabledSkills` in their config) are not copied, and a copy we
# installed before is removed. Without this every update brought a switched-off skill back.
DISABLED=""
if command -v node >/dev/null 2>&1 && [ -f "$DATA/config.json" ]; then
  DISABLED="$(node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));(c.disabledSkills||[]).filter(n=>typeof n==="string"&&/^[A-Za-z0-9._-]+$/.test(n)&&!n.startsWith(".")).forEach(n=>console.log(n))}catch{}' "$(native "$DATA/config.json")" 2>/dev/null | tr -d '\r' | tr '\n' ' ' || true)"
fi

installed=0; ours=""
for dir in "$EDITION/skills"/*/ "$TMP/mkt/codex-extras/skills"/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  case " $DISABLED " in *" $name "*)
    if [ -d "$SKILLS/$name" ] && [ -f "$SKILLS/$name/$MARK" ]; then rm -rf "${SKILLS:?}/$name"; fi
    continue ;;
  esac
  rm -rf "${SKILLS:?}/$name"
  cp -R "$dir" "$SKILLS/$name"
  fill "$SKILLS/$name"
  : > "$SKILLS/$name/$MARK"
  installed=$((installed + 1)); ours="$ours $name"
done

# A copy is ours to delete only if we marked it, or it is an unmarked copy from the first version of
# this script (those all say ShadowDesk). Never touch a client's own same-named skill.
is_ours() { [ -f "$1/$MARK" ] || grep -qs 'ShadowDesk' "$1/SKILL.md"; }

# Skills the previous run installed that the toolkit no longer ships, plus Claude-only leftovers.
# No manifest yet means the first version installed here: the Claude-only leftovers still have to go.
for name in $(cat "$MANIFEST" 2>/dev/null) install-playwright example-adapt-demo; do
  case " $ours " in *" $name "*) continue ;; esac
  for where in "$SKILLS" "$PREVIOUS_SKILLS"; do
    if [ -d "$where/$name" ] && is_ours "$where/$name"; then rm -rf "${where:?}/$name"; fi
  done
done

# Moving to a new location (first --here, or a re-pin): clear our copies from the old one, or Codex
# lists every skill twice. It does not merge skills that share a name.
for old in "$PREVIOUS_SKILLS" "$GLOBAL_SKILLS"; do
  [ -d "$old" ] || continue
  [ "$(cd "$old" && pwd -P)" = "$(cd "$SKILLS" && pwd -P)" ] && continue
  for name in $ours install-playwright example-adapt-demo; do
    if [ -d "$old/$name" ] && is_ours "$old/$name"; then rm -rf "${old:?}/$name"; fi
  done
done

printf '%s\n' $ours > "$MANIFEST"
printf '%s' "$SKILLS" > "$TARGETFILE"
if [ -n "$CODE" ]; then
  printf '%s' "$CODE" > "$KEYFILE"
  chmod 600 "$KEYFILE" 2>/dev/null || true
fi

# In a project, AGENTS.md gets one safety-net section, once. The client's own edits are never touched.
PROJECT="$(dirname "$(dirname "$SKILLS")")"
if [ "$SKILLS" != "$GLOBAL_SKILLS" ] && [ -f "$PROJECT/AGENTS.md" ] && ! grep -q 'Running skills written for Claude' "$PROJECT/AGENTS.md"; then
  cat >> "$PROJECT/AGENTS.md" <<'EOF'

## 11. Running skills written for Claude

My skills are built for Codex, but a few instructions may still assume Claude Code. When one does,
do the Codex equivalent instead of stopping:

| The skill says | Do this in Codex |
|---|---|
| Ask with `AskUserQuestion` | Ask me in the chat with 2 to 4 numbered options, your recommendation first |
| Invoke another skill with the Skill tool | Run that skill yourself (`$name`) |
| `/name` or `/shadowdesk:name` | Means `$name` |
| `claude mcp ...` or `claude plugin ...` | Use `codex mcp list` or `/mcp`. Tools live in `~/.codex/config.toml` |
| `~/.claude/projects/.../memory` | Memory lives in `memory/` in this folder |
| `CLAUDE.md` | Means this file, `AGENTS.md` |

Never create a `.claude/` folder here; Codex ignores it.
EOF
fi

# Seed this client's config from the toolkit defaults, once. The Claude plugin does this at every
# session start (seed-config.mjs); the Codex install never did, so skills that read config found
# nothing. Only ever fills a MISSING file.
if [ ! -f "$DATA/config.json" ] && [ -f "$TOOLKIT/defaults/config.json" ]; then
  cp "$TOOLKIT/defaults/config.json" "$DATA/config.json"
fi

# Register the startup check with Codex: a SessionStart hook in this folder's .codex/hooks.json
# (home-folder installs: ~/.codex/hooks.json). It is what makes updates land on their own and
# switched-off skills stay off, the same as the Claude edition. The command never changes between
# releases, only the script it runs does, so Codex's one-time approval of the hook keeps holding.
# Any hook of the client's own in that file is kept; only our entry is replaced.
if command -v node >/dev/null 2>&1; then
  if [ "$SKILLS" != "$GLOBAL_SKILLS" ]; then HOOKS_FILE="$(dirname "$(dirname "$SKILLS")")/.codex/hooks.json"; else HOOKS_FILE="$BASE/.codex/hooks.json"; fi
  mkdir -p "$(dirname "$HOOKS_FILE")"
  node - "$(native "$HOOKS_FILE")" "$(native "$TOOLKIT/scripts/codex-session-start.mjs")" <<'NODE' || echo "note: could not register the startup check; run \$update later to add it" >&2
const fs = require("fs"), [file, script] = process.argv.slice(2);
let j = {}; try { j = JSON.parse(fs.readFileSync(file, "utf8")); } catch {}
if (!j || typeof j !== "object" || Array.isArray(j)) j = {};
j.hooks = j.hooks && typeof j.hooks === "object" ? j.hooks : {};
const ours = (g) => JSON.stringify(g || {}).includes("codex-session-start.mjs");
const cmd = `node "${script}"`;
j.hooks.SessionStart = (Array.isArray(j.hooks.SessionStart) ? j.hooks.SessionStart : []).filter((g) => !ours(g));
j.hooks.SessionStart.push({
  matcher: "startup|resume|clear|compact",
  hooks: [{ type: "command", command: cmd, commandWindows: cmd, timeout: 90, statusMessage: "ShadowDesk: checking for updates" }],
});
fs.writeFileSync(file, JSON.stringify(j, null, 2) + "\n");
NODE
fi

# A fresh install is by definition current: stamp the check time so the first session does not
# download everything again straight away.
node -e 'require("fs").writeFileSync(process.argv[1], String(Date.now()))' "$(native "$DATA/.last-autocheck")" 2>/dev/null || true
# ...and record the version just installed as already known, if nothing is recorded yet. Without it
# the startup check could only learn the version on its first run, so an update landing on that same
# first run would be silent.
node -e 'const fs=require("fs"),[cfgF,plugF]=process.argv.slice(1);let c={};try{c=JSON.parse(fs.readFileSync(cfgF,"utf8"))}catch{};const v=JSON.parse(fs.readFileSync(plugF,"utf8")).version;c.autoUpdate=c.autoUpdate||{};if(!c.autoUpdate.lastNarratedVersion){c.autoUpdate.lastNarratedVersion=v;fs.writeFileSync(cfgF,JSON.stringify(c,null,2)+"\n")}' "$(native "$DATA/config.json")" "$(native "$TOOLKIT/.claude-plugin/plugin.json")" 2>/dev/null || true

# Refresh this updater from the private repo, so fixes reach people who installed an older copy.
PARKED="$STATE/codex-switch.sh"
if [ -f "$EDITION/codex-switch.sh" ]; then
  cp "$EDITION/codex-switch.sh" "$PARKED"
else
  SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
  [ "$SELF" = "$PARKED" ] || cp "$SELF" "$PARKED"
fi

VERSION="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$TOOLKIT/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
echo "OK: ${installed} ShadowDesk skills installed for Codex (v${VERSION:-unknown})"
echo "    skills:  $SKILLS"
echo "    update:  bash ~/.shadowdesk/codex-switch.sh   (no code needed, it is saved)"
echo "    Start a new Codex chat, then type \$email or \$end-session to use one."
