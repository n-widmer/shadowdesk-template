#!/usr/bin/env node
// Session-start AUTO-UPDATE check. Replaces the pure nudge: it actually refreshes the
// marketplace catalog and compares the installed plugin version to the latest available.
// If Nick shipped a newer version, it surfaces ONE "want it?" prompt (ask-once-before-apply,
// per the design) — it never applies the update itself; the user says yes and Claude runs
// /shadowdesk:update. When there's no version bump, it falls back to the unseen-pattern
// nudge so the old behavior is preserved. Throttled to once / ~20h. ALWAYS exits 0.
import { readFileSync, writeFileSync, mkdirSync, readdirSync, existsSync } from "node:fs";
import { execSync } from "node:child_process";
import { join } from "node:path";
import { homedir } from "node:os";

const emit = (msg) => {
  try {
    process.stdout.write(JSON.stringify({
      hookSpecificOutput: { hookEventName: "SessionStart", additionalContext: msg },
    }));
  } catch {}
};

const semverGt = (a, b) => {
  const pa = String(a).split(".").map((n) => parseInt(n, 10) || 0);
  const pb = String(b).split(".").map((n) => parseInt(n, 10) || 0);
  for (let i = 0; i < 3; i++) { if ((pa[i] || 0) > (pb[i] || 0)) return true; if ((pa[i] || 0) < (pb[i] || 0)) return false; }
  return false;
};

const readVersion = (p) => { try { return JSON.parse(readFileSync(p, "utf8")).version || null; } catch { return null; } };

// Resolve the marketplace this plugin is actually installed from. It is registered as
// "shadowdesk@<marketplace>" (shadowdesk-starter for the free bundle, shadowdesk for the
// keyed channel). Refreshing the WRONG name throws, so read the real one instead of
// hardcoding it.
function resolveMarketplaceName() {
  try {
    const ip = JSON.parse(readFileSync(join(homedir(), ".claude", "plugins", "installed_plugins.json"), "utf8"));
    const key = Object.keys(ip).find((k) => k.startsWith("shadowdesk@"));
    if (key) return key.slice("shadowdesk@".length);
  } catch {}
  return null;
}

// Find the latest available plugin version from the refreshed marketplace cache (best-effort).
function latestFromCatalog(marketplace) {
  const base = join(homedir(), ".claude", "plugins", "marketplaces");
  const candidates = [];
  if (marketplace) candidates.push(join(base, marketplace, "plugins", "shadowdesk", ".claude-plugin", "plugin.json"));
  candidates.push(join(base, "shadowdesk", "plugins", "shadowdesk", ".claude-plugin", "plugin.json"));
  for (const c of candidates) { const v = readVersion(c); if (v) return v; }
  // fallback: shallow-scan marketplace dirs for any shadowdesk plugin manifest
  try {
    for (const dir of readdirSync(base)) {
      const p = join(base, dir, "plugins", "shadowdesk", ".claude-plugin", "plugin.json");
      const v = readVersion(p); if (v) return v;
    }
  } catch {}
  return null;
}

function unseenPatternCount(root, data) {
  try {
    const shipped = readdirSync(join(root, "patterns")).filter((f) => f.endsWith(".md")).map((f) => f.replace(/\.md$/, ""));
    let cfg = {}; try { cfg = JSON.parse(readFileSync(join(data, "config.json"), "utf8")); } catch {}
    const p = cfg.patterns || {};
    const seen = new Set([...(p.adopted || []), ...(p.declined || [])]);
    return shipped.filter((id) => !seen.has(id)).length;
  } catch { return 0; }
}

try {
  const data = process.env.CLAUDE_PLUGIN_DATA;
  const root = process.env.CLAUDE_PLUGIN_ROOT;
  if (!data || !root) process.exit(0);

  // throttle
  const marker = join(data, ".last-autocheck");
  const now = Date.now();
  let last = 0; try { last = parseInt(readFileSync(marker, "utf8"), 10) || 0; } catch {}
  const TWENTY_H = 20 * 60 * 60 * 1000;
  if (now - last < TWENTY_H) process.exit(0);

  // Refresh the catalog for whatever marketplace this client is actually on (keyed
  // 'shadowdesk' or free 'shadowdesk-starter'). If the name can't be resolved, or a
  // directory/offline source has nothing new to pull, the refresh throws or is skipped;
  // we swallow it and fall back to the pattern nudge.
  let installed = readVersion(join(root, ".claude-plugin", "plugin.json"));
  const marketplace = resolveMarketplaceName();
  let catalogRefreshed = false;
  if (marketplace) {
    try {
      execSync(`claude plugin marketplace update ${marketplace}`, { timeout: 30000, stdio: "ignore" });
      catalogRefreshed = true;
    } catch {}
  }

  let msg = null;
  if (catalogRefreshed) {
    const latest = latestFromCatalog(marketplace);
    if (latest && installed && semverGt(latest, installed)) {
      msg = `ShadowDesk plugin: Nick shipped an update (v${latest}, you're on v${installed}). Want me to pull it in? Say yes and I'll run /shadowdesk:update, which applies it and offers any new skills/patterns one at a time. Nothing changes without your ok, and your saved settings are never touched.`;
    }
  }

  // no version bump -> preserve the old unseen-pattern nudge
  if (!msg) {
    const unseen = unseenPatternCount(root, data);
    if (unseen > 0) {
      msg = `ShadowDesk plugin: Nick has ${unseen} new way${unseen === 1 ? "" : "s"} of working you haven't seen. Run /shadowdesk:update to review and (optionally) add ${unseen === 1 ? "it" : "them"}. Nothing changes without your yes.`;
    }
  }

  if (msg) {
    emit(msg);
    // record + stamp only after emitting, so a write failure never silences the next session
    try {
      mkdirSync(data, { recursive: true });
      writeFileSync(marker, String(now));
      const cfgPath = join(data, "config.json");
      if (existsSync(cfgPath)) {
        const cfg = JSON.parse(readFileSync(cfgPath, "utf8"));
        cfg.autoUpdate = { ...(cfg.autoUpdate || {}), lastCheckedVersion: installed, lastCheckedAt: now };
        writeFileSync(cfgPath, JSON.stringify(cfg, null, 2) + "\n");
      }
    } catch {}
  } else {
    // quiet session: still stamp so we don't recheck for 20h
    try { mkdirSync(data, { recursive: true }); writeFileSync(marker, String(now)); } catch {}
  }
} catch {}
process.exit(0);
