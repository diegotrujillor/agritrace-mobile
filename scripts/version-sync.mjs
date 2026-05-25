#!/usr/bin/env node
// version-sync.mjs
//
// Conservative, opt-in version stamp bumper for AgriTrace repos.
//
// Reads .github/version-sync-targets.json (relative to repo root) listing files
// to scan. For each file, only rewrites lines that EITHER:
//
//   1) carry an explicit HTML-comment marker on the same line:
//        <!-- version-sync:mobile -->     -> bumps EVERY v1.x.y token on the line
//        <!-- version-sync:backend -->    -> bumps EVERY v0.x.y token on the line
//        <!-- version-sync:current -->    -> bumps every v1.x.y AND every v0.x.y
//
//   2) match one of the very tight "canonical" patterns (configured per repo
//      via the "canonical" rules array in the target file). These should be
//      used ONLY for lines like "Versión actual: **vX.Y.Z**" — never broad.
//
// CHANGELOG entries, dated QA cycle records, memory snapshots, and historical
// feature-context sentences are all left untouched because they carry no marker.
//
// Usage:
//   node scripts/version-sync.mjs --mobile=v1.9.12 --backend=v0.6.1
//   node scripts/version-sync.mjs --mobile=v1.9.12 --backend=v0.6.1 --check
//
//   --check   Do not write files. Exit code 0 if no drift, 2 if drift detected.
//             Prints a unified summary of would-be changes.

import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { resolve, relative } from 'node:path';

const SEMVER = /v\d+\.\d+\.\d+/;
const MOBILE_TOKEN_GLOBAL = /v1\.\d+\.\d+/g;
const BACKEND_TOKEN_GLOBAL = /v0\.\d+\.\d+/g;

const MARKER_MOBILE = '<!-- version-sync:mobile -->';
const MARKER_BACKEND = '<!-- version-sync:backend -->';
const MARKER_CURRENT = '<!-- version-sync:current -->';

function parseArgs(argv) {
  const out = { check: false };
  for (const a of argv) {
    if (a === '--check') {
      out.check = true;
      continue;
    }
    const m = a.match(/^--([^=]+)=(.*)$/);
    if (m) out[m[1]] = m[2];
  }
  return out;
}

function die(msg, code = 1) {
  process.stderr.write(`version-sync: ${msg}\n`);
  process.exit(code);
}

function validateSemverTag(tag, label) {
  if (!tag) die(`missing --${label}`);
  if (!SEMVER.test(tag)) die(`invalid ${label} tag: ${tag} (expected vMAJOR.MINOR.PATCH)`);
}

function applyMarkers(line, mobile, backend) {
  // Apply HTML-comment opt-in markers. Each marker rewrites EVERY matching
  // token on the same line so that constructs like
  //   "Instalar APK v1.9.7 ... tag `v1.9.7`"
  // stay internally consistent after a bump.
  if (line.includes(MARKER_CURRENT)) {
    return line
      .replace(MOBILE_TOKEN_GLOBAL, mobile)
      .replace(BACKEND_TOKEN_GLOBAL, backend);
  }
  if (line.includes(MARKER_MOBILE)) {
    return line.replace(MOBILE_TOKEN_GLOBAL, mobile);
  }
  if (line.includes(MARKER_BACKEND)) {
    return line.replace(BACKEND_TOKEN_GLOBAL, backend);
  }
  return line;
}

function applyCanonicalRules(line, rules, mobile, backend) {
  // Canonical rules are tight regexes for known phrases like
  // "Versión actual: **vX.Y.Z**" or "Current version: **vX.Y.Z**".
  // Each rule is { pattern, flags?, replacement }, and ${MOBILE} / ${BACKEND}
  // are substituted in the replacement string.
  let current = line;
  for (const rule of rules) {
    const flags = rule.flags || '';
    if (flags.includes('g')) {
      die(`canonical rule uses global flag (forbidden): ${rule.pattern}`);
    }
    const re = new RegExp(rule.pattern, flags);
    if (!re.test(current)) continue;
    const replacement = rule.replacement
      .replaceAll('${MOBILE}', mobile)
      .replaceAll('${BACKEND}', backend);
    current = current.replace(re, replacement);
  }
  return current;
}

function processFile(repoRoot, target, mobile, backend) {
  const abs = resolve(repoRoot, target.file);
  if (!existsSync(abs)) {
    return { file: target.file, status: 'missing', changes: 0 };
  }
  const original = readFileSync(abs, 'utf-8');
  const lines = original.split('\n');
  const canonical = target.canonical || [];
  let changedLines = 0;
  const out = lines.map((line) => {
    const afterMarkers = applyMarkers(line, mobile, backend);
    const afterCanonical = applyCanonicalRules(afterMarkers, canonical, mobile, backend);
    if (afterCanonical !== line) changedLines++;
    return afterCanonical;
  });
  const updated = out.join('\n');
  return {
    file: target.file,
    status: updated === original ? 'unchanged' : 'updated',
    changes: changedLines,
    original,
    updated,
    abs,
  };
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const { mobile, backend, check } = args;
  validateSemverTag(mobile, 'mobile');
  validateSemverTag(backend, 'backend');

  const repoRoot = process.cwd();
  const configPath = resolve(repoRoot, '.github/version-sync-targets.json');
  if (!existsSync(configPath)) {
    die(`config not found at ${relative(repoRoot, configPath)}`);
  }
  const targets = JSON.parse(readFileSync(configPath, 'utf-8'));
  if (!Array.isArray(targets)) {
    die('config must be a JSON array of targets');
  }

  let totalChangedFiles = 0;
  let totalChangedLines = 0;
  const summary = [];

  for (const target of targets) {
    const result = processFile(repoRoot, target, mobile, backend);
    summary.push(result);
    if (result.status === 'updated') {
      totalChangedFiles++;
      totalChangedLines += result.changes;
      if (!check) {
        writeFileSync(result.abs, result.updated);
      }
    }
  }

  for (const r of summary) {
    if (r.status === 'updated') {
      process.stdout.write(`[${check ? 'would-update' : 'updated'}] ${r.file} (${r.changes} line${r.changes === 1 ? '' : 's'})\n`);
    } else if (r.status === 'missing') {
      process.stdout.write(`[missing]  ${r.file}\n`);
    }
  }

  process.stdout.write(`\nFiles changed: ${totalChangedFiles}  |  Lines changed: ${totalChangedLines}\n`);
  process.stdout.write(`Mobile: ${mobile}   Backend: ${backend}\n`);

  if (check && totalChangedFiles > 0) {
    process.exit(2);
  }
}

main();
