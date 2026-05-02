#!/usr/bin/env node
/**
 * detect-changes.js
 *
 * Used by GitHub Actions to determine which Cloud Functions need redeployment
 * based on what files changed in the current push.
 *
 * Outputs two GitHub Actions outputs:
 *   deploy_all  — "true" if shared deps changed (redeploy everything)
 *   functions   — comma-separated list like "onHealthSnapshotWrite,ayurveda"
 *                 (empty string if only non-backend files changed)
 *
 * Usage (in CI):
 *   node backend/scripts/detect-changes.js
 *   → writes to $GITHUB_OUTPUT automatically
 *
 * Local usage:
 *   CHANGED_FILES="backend/functions/ayurveda.js" node backend/scripts/detect-changes.js
 */

import { readFileSync } from "fs";
import { execSync } from "child_process";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BACKEND_DIR = join(__dirname, "..");
const INDEX_JS    = join(BACKEND_DIR, "index.js");

// ── Build file → function names map from index.js ────────────────────────────

function buildFunctionMap() {
    const src = readFileSync(INDEX_JS, "utf8");
    const map = {}; // { "functions/ayurveda.js": ["onHealthSnapshotWrite", ...] }

    // Match: export { fn1, fn2, ... } from "./functions/file.js";
    // Also handles multi-line exports and comments after function names
    const exportPattern = /export\s*\{([^}]+)\}\s*from\s*["']\.\/([^"']+)["']/gs;
    let match;
    while ((match = exportPattern.exec(src)) !== null) {
        const names = match[1]
            .split(",")
            .map(n => n.replace(/\/\/.*$/, "").trim()) // strip inline comments
            .filter(n => n.length > 0 && !n.includes(" ")); // filter malformed
        const file = match[2]; // e.g. "functions/ayurveda.js"
        map[file] = (map[file] || []).concat(names);
    }
    return map;
}

// ── Determine changed backend files ──────────────────────────────────────────

function getChangedFiles() {
    // Allow override for local testing
    if (process.env.CHANGED_FILES) {
        return process.env.CHANGED_FILES.split("\n").filter(Boolean);
    }
    try {
        const out = execSync("git diff --name-only HEAD~1 HEAD -- backend/", { encoding: "utf8" });
        return out.split("\n").filter(Boolean);
    } catch {
        // First commit or no parent: treat as deploy all
        return ["backend/lib/FORCE_FULL_DEPLOY"];
    }
}

// ── Classify changes ─────────────────────────────────────────────────────────

// Any change to these triggers a full redeploy (all functions import them)
const SHARED_PATHS = [
    "backend/lib/",
    "backend/index.js",
    "backend/package.json",
    "backend/package-lock.json",
];

function classify(changedFiles) {
    const isShared = changedFiles.some(f =>
        SHARED_PATHS.some(shared => f.startsWith(shared))
    );
    if (isShared) return { deployAll: true, functions: [] };

    const functionMap = buildFunctionMap();
    const functionsToDeploy = new Set();

    for (const file of changedFiles) {
        // Normalize: "backend/functions/ayurveda.js" → "functions/ayurveda.js"
        const relPath = file.replace(/^backend\//, "");
        if (functionMap[relPath]) {
            for (const fn of functionMap[relPath]) functionsToDeploy.add(fn);
        }
    }

    return { deployAll: false, functions: [...functionsToDeploy] };
}

// ── Output ───────────────────────────────────────────────────────────────────

const changedFiles = getChangedFiles();
console.error("Changed backend files:", changedFiles);

const { deployAll, functions } = classify(changedFiles);

console.error("deploy_all:", deployAll);
console.error("functions:", functions);

// Write GitHub Actions outputs
const output = process.env.GITHUB_OUTPUT;
if (output) {
    const fs = await import("fs");
    fs.appendFileSync(output, `deploy_all=${deployAll}\n`);
    fs.appendFileSync(output, `functions=${functions.join(",")}\n`);
} else {
    // Local: just print
    console.log(`deploy_all=${deployAll}`);
    console.log(`functions=${functions.join(",")}`);
}
