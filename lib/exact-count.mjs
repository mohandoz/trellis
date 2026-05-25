#!/usr/bin/env node
// lib/exact-count.mjs — opt-in Anthropic SDK token counter for conjure audit --exact.
// Reads .md and .json files under <target>/.claude/, counts tokens via the stable
// messages.countTokens API (SDK 0.98.0+), and writes the integer token count to stdout.
// Exits non-zero with an advisory to stderr when the SDK or API key is absent.

import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { execSync } from 'node:child_process';

const target = process.argv[2] || process.cwd();

// Check ANTHROPIC_API_KEY before attempting SDK import — avoids misleading error
if (!process.env.ANTHROPIC_API_KEY) {
  process.stderr.write('[--exact] ANTHROPIC_API_KEY not set — falling back to chars/4 heuristic.\n');
  process.exit(1);
}

// Safe file-reading helper — returns empty string on any error
const safe = (fn) => { try { return fn(); } catch { return ''; } };

// Collect all .md and .json files under target/.claude/
const claudeDir = join(target, '.claude');
const content = safe(() =>
  execSync(
    `find ${JSON.stringify(claudeDir)} -type f \\( -name "*.md" -o -name "*.json" \\) -print0`,
    { stdio: ['ignore', 'pipe', 'ignore'] }
  )
    .toString()
    .split('\0')
    .filter(Boolean)
    .map(f => safe(() => readFileSync(f, 'utf8')))
    .join('\n')
);

// Wrap SDK import in try/catch to handle MODULE_NOT_FOUND gracefully
let Anthropic;
try {
  const mod = await import('@anthropic-ai/sdk');
  Anthropic = mod.default;
} catch (e) {
  if (e.code === 'ERR_MODULE_NOT_FOUND' || e.code === 'MODULE_NOT_FOUND') {
    process.stderr.write('[--exact] @anthropic-ai/sdk not found — install with: npm install @anthropic-ai/sdk\n');
    process.exit(1);
  }
  process.stderr.write(`[--exact] unexpected import error: ${e.message}\n`);
  process.exit(1);
}

// Call the stable countTokens API (SDK 0.98.0+, stable namespace)
try {
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const response = await client.messages.countTokens({
    model: 'claude-sonnet-4-6',
    messages: [{ role: 'user', content: content || ' ' }],
  });
  process.stdout.write(String(response.input_tokens) + '\n');
  process.exit(0);
} catch (e) {
  process.stderr.write(`[--exact] token count failed: ${e.message}\n`);
  process.exit(1);
}
