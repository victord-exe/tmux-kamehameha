#!/usr/bin/env node

import { execSync } from "child_process";
import { readFileSync, writeFileSync, statSync, existsSync, readdirSync, unlinkSync } from "fs";
import { tmpdir, homedir } from "os";
import { join, basename } from "path";

// --- Palette: Tokyo Night + acento naranja, la misma de ~/.tmux.conf ---
const hex = (h) => h.match(/\w\w/g).map((x) => parseInt(x, 16)).join(";");
const fg = (h) => `\x1b[38;2;${hex(h)}m`;
const bg = (h) => `\x1b[48;2;${hex(h)}m`;
const COLORS = {
  orange: fg("ff9e64"),
  blue: fg("7aa2f7"),
  text: fg("c0caf5"),
  dim: fg("a9b1d6"),
  track: fg("545c7e"),
  green: fg("9ece6a"),
  yellow: fg("e0af68"),
  red: fg("f7768e"),
  bold: "\x1b[1m",
  reset: "\x1b[0m",
};
const SEP = `${COLORS.dim}  \u00b7  ${COLORS.reset}`;

function colorForPct(pct) {
  if (pct >= 90) return COLORS.red;
  if (pct >= 70) return COLORS.yellow;
  return COLORS.green;
}

// --- Progress bar: tramo lleno en color, pista en surface ---
function progressBar(pct, width = 20, color = "") {
  pct = Math.max(0, Math.min(100, Math.floor(pct)));
  const filled = Math.round((pct * width) / 100);
  const empty = width - filled;
  return `${color}${"\u2501".repeat(filled)}${COLORS.track}${"\u2501".repeat(empty)}${COLORS.reset}`;
}

// --- Time remaining ---
function timeRemaining(resetIso) {
  if (!resetIso || resetIso === "null") return "?";
  const diff = Math.floor((new Date(resetIso).getTime() - Date.now()) / 1000);
  if (diff <= 0) return "0m";
  const days = Math.floor(diff / 86400);
  const hours = Math.floor((diff % 86400) / 3600);
  const mins = Math.floor((diff % 3600) / 60);
  if (days > 0) return `${days}d${hours}h`;
  if (hours > 0) return `${hours}h${mins}m`;
  return `${mins}m`;
}

// --- OAuth token ---
// Priority: env var > credentials file > macOS Keychain
function getOAuthToken() {
  // 1. Environment variable (highest priority, same as Claude Code)
  if (process.env.CLAUDE_CODE_OAUTH_TOKEN) {
    return process.env.CLAUDE_CODE_OAUTH_TOKEN;
  }

  // 2. Credentials file (Linux/Windows primary, macOS sometimes)
  try {
    const credsPath = join(homedir(), ".claude", ".credentials.json");
    if (existsSync(credsPath)) {
      const creds = JSON.parse(readFileSync(credsPath, "utf-8"));
      const oauth = creds.claudeAiOauth ?? {};
      const token = oauth.accessToken ?? creds.accessToken ?? null;
      const expiresAt = oauth.expiresAt ?? creds.expiresAt ?? null;
      const exp = typeof expiresAt === "number" ? expiresAt : expiresAt ? new Date(expiresAt).getTime() : null;
      if (token && (!exp || exp > Date.now())) return token;
    }
  } catch {
    // fall through
  }

  // 3. Cached token file (fallback when Keychain is locked/slow)
  const tokenCachePath = join(homedir(), ".claude", ".cached-token.json");
  function cacheToken(token, expiresAt) {
    try { writeFileSync(tokenCachePath, JSON.stringify({ token, expiresAt }), { mode: 0o600 }); } catch { /* best-effort */ }
  }
  function readCachedToken() {
    try {
      if (!existsSync(tokenCachePath)) return null;
      const { token, expiresAt } = JSON.parse(readFileSync(tokenCachePath, "utf-8"));
      const exp = typeof expiresAt === "number" ? expiresAt : expiresAt ? new Date(expiresAt).getTime() : null;
      return token && (!exp || exp > Date.now()) ? token : null;
    } catch { return null; }
  }

  // 4. macOS Keychain (macOS deletes the credentials file after login)
  if (process.platform === "darwin") {
    try {
      const credsJson = execSync(
        'security find-generic-password -s "Claude Code-credentials" -w',
        { stdio: ["pipe", "pipe", "pipe"], timeout: 3000 }
      ).toString();
      const creds = JSON.parse(credsJson);
      const oauth = creds.claudeAiOauth ?? {};
      const token = oauth.accessToken ?? creds.accessToken ?? null;
      const expiresAt = oauth.expiresAt ?? creds.expiresAt ?? null;
      const exp = typeof expiresAt === "number" ? expiresAt : expiresAt ? new Date(expiresAt).getTime() : null;
      if (token && (!exp || exp > Date.now())) {
        cacheToken(token, expiresAt);
        return token;
      }
    } catch {
      // Keychain locked/timeout — try cached token
      const cached = readCachedToken();
      if (cached) return cached;
    }
  }

  // 5. Cached token as last resort (Keychain failed or non-macOS)
  return readCachedToken();
}

// --- Usage fetch + cache ---
const CACHE_MAX_AGE = 300;
let _pruneDone = false;

function readCache(cachePath) {
  try {
    if (existsSync(cachePath)) return JSON.parse(readFileSync(cachePath, "utf-8"));
  } catch { /* corrupted */ }
  return null;
}

const SHARED_CACHE_PATH = join(tmpdir(), "claude_usage_cache_latest.json");

async function fetchUsage(sessionId) {
  const cachePath = join(tmpdir(), `claude_usage_cache_${sessionId}.json`);
  const cached = readCache(cachePath) ?? readCache(SHARED_CACHE_PATH);

  if (cached) {
    try {
      const src = existsSync(cachePath) ? cachePath : SHARED_CACHE_PATH;
      const age = (Date.now() - statSync(src).mtimeMs) / 1000;
      if (age < CACHE_MAX_AGE) return cached;
    } catch { /* stat failed, proceed to fetch */ }
  }

  const token = getOAuthToken();
  if (!token) return cached;

  try {
    const resp = await fetch("https://api.anthropic.com/api/oauth/usage", {
      headers: {
        Authorization: `Bearer ${token}`,
        "anthropic-beta": "oauth-2025-04-20",
        "Content-Type": "application/json",
      },
      signal: AbortSignal.timeout(5000),
    });
    if (!resp.ok) {
      if (cached) writeFileSync(cachePath, JSON.stringify(cached), { mode: 0o600 });
      return cached;
    }
    const data = await resp.json();
    if (!data.five_hour && !data.seven_day) return cached;
    writeFileSync(cachePath, JSON.stringify(data), { mode: 0o600 });
    try { writeFileSync(SHARED_CACHE_PATH, JSON.stringify(data), { mode: 0o600 }); } catch { /* best-effort */ }
    // Prune stale cache files older than 24h (best-effort, once per process)
    if (!_pruneDone) {
      _pruneDone = true;
      try {
        const cutoff = Date.now() - 86400 * 1000;
        for (const f of readdirSync(tmpdir())) {
          if (!f.startsWith("claude_usage_cache_") || !f.endsWith(".json")) continue;
          if (f === "claude_usage_cache_latest.json") continue;
          const fp = join(tmpdir(), f);
          if (statSync(fp).mtimeMs < cutoff) unlinkSync(fp);
        }
      } catch { /* best-effort */ }
    }
    return data;
  } catch {
    return cached;
  }
}

// --- Git info ---
function getGitInfo(cwd) {
  if (!cwd) return null;
  try {
    let branch = execSync("git rev-parse --abbrev-ref HEAD", {
      cwd,
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 3000,
    })
      .toString()
      .trim();
    if (branch === "HEAD") {
      branch = execSync("git rev-parse --short HEAD", {
        cwd,
        stdio: ["pipe", "pipe", "pipe"],
        timeout: 3000,
      })
        .toString()
        .trim();
    }
    const dirty = execSync("git status --porcelain --untracked-files=no", {
      cwd,
      stdio: ["pipe", "pipe", "pipe"],
      timeout: 3000,
    })
      .toString()
      .trim().length > 0;
    return { branch, dirty };
  } catch {
    return null;
  }
}

// --- Read stdin ---
const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
let input;
try {
  input = JSON.parse(Buffer.concat(chunks).toString());
} catch {
  input = {};
}

// --- Parse input ---
const model = input.model?.display_name ?? "?";
const cost = Number(input.cost?.total_cost_usd ?? 0);
const usedPct = Math.floor(input.context_window?.used_percentage ?? 0);
const dir = input.workspace?.current_dir ?? "";
const sessionId = input.session_id ?? "default";
const folder = dir ? basename(dir) : "";

// --- Line 1 ---
const sessionCost = cost.toFixed(4);
// Pill del modelo, igual a la de la sesi\u00f3n en tmux (glyphs Nerd Font)
const pill = `${COLORS.orange}\ue0b6${bg("ff9e64")}${fg("1a1b26")}${COLORS.bold}\u{F06A9} ${model}${COLORS.reset}${COLORS.orange}\ue0b4${COLORS.reset}`;
const folderStr = folder ? `${SEP}${COLORS.blue}\uf115 ${COLORS.text}${folder}${COLORS.reset}` : "";
const gitInfo = getGitInfo(dir);
let gitStr = "";
if (gitInfo) {
  const { branch, dirty } = gitInfo;
  const dirtyMark = dirty ? ` ${COLORS.orange}\u25cf${COLORS.reset}` : "";
  gitStr = `${SEP}${COLORS.blue}\ue0a0 ${COLORS.text}${branch}${COLORS.reset}${dirtyMark}`;
}
const line1 = `${pill}${folderStr}${gitStr}${SEP}${COLORS.yellow}$${sessionCost}${COLORS.reset}`;

// --- Line 2: se arma a escala s (1 = barras completas, 0.5 = mitad) para que quepa en una línea ---
const usage = await fetchUsage(sessionId);
function buildLine2(s) {
  const w = (n) => Math.max(4, Math.round(n * s));
  let out = `${COLORS.dim}ctx${COLORS.reset} ${progressBar(usedPct, w(20), colorForPct(usedPct))} ${COLORS.text}${usedPct}%${COLORS.reset}`;
  if (usage) {
    const sessUtil = Math.floor(usage.five_hour?.utilization ?? 0);
    const weekUtil = Math.floor(usage.seven_day?.utilization ?? 0);
    const sessTime = timeRemaining(usage.five_hour?.resets_at);
    const weekTime = timeRemaining(usage.seven_day?.resets_at);
    out += `${SEP}${COLORS.dim}sess${COLORS.reset} ${progressBar(sessUtil, w(10), colorForPct(sessUtil))} ${COLORS.text}${sessUtil}%${COLORS.reset} ${COLORS.dim}${sessTime}${COLORS.reset}`;
    out += `${SEP}${COLORS.dim}week${COLORS.reset} ${progressBar(weekUtil, w(20), colorForPct(weekUtil))} ${COLORS.text}${weekUtil}%${COLORS.reset} ${COLORS.dim}${weekTime}${COLORS.reset}`;
  }
  return out;
}

// --- Layout: info a la izquierda, barras pegadas a la derecha si caben en una línea ---
// El script corre sin tty, así que el ancho sale de tmux; fuera de tmux quedan las dos líneas
const visible = (s) => [...s.replace(/\x1b\[[0-9;]*m/g, "")].length;
let width = 0;
try {
  if (process.env.TMUX_PANE) {
    width = Number(execSync(`tmux display -p -t ${process.env.TMUX_PANE} '#{pane_width}'`, { stdio: ["pipe", "pipe", "pipe"], timeout: 1000 }).toString().trim());
  }
} catch { /* sin tmux */ }
const avail = width - 2 * 2 - 2; // padding: 2 de settings.json a cada lado, más margen
// Primero barras completas; si no cabe, a la mitad; si tampoco, dos líneas con barras completas
let out = null;
for (const scale of [1, 0.5]) {
  const line2 = buildLine2(scale);
  const gap = avail - visible(line1) - visible(line2);
  if (gap >= 4) { out = `${line1}${" ".repeat(gap)}${line2}\n`; break; }
}
process.stdout.write(out ?? `${line1}\n${buildLine2(1)}\n`);
