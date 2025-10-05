#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');

/**
 * PostToolUse helper: Draft a semantic commit after edits.
 * By default, only SUGGESTS commands. If CODEX_AUTO_COMMIT=1, stages & commits.
 */

try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const { tool_input, cwd } = input;

  if (!cwd) process.exit(0);
  process.chdir(cwd);

  // Ensure we are in a git repo
  try {
    execSync('git rev-parse --git-dir', { stdio: 'pipe' });
  } catch {
    process.exit(0);
  }

  // Detect changed files
  const status = execSync('git status --porcelain', { encoding: 'utf8' });
  if (!status.trim()) process.exit(0);

  const files = status
    .split('\n')
    .filter(line => line.trim())
    .map(line => line.substring(3))
    .filter(Boolean);
  if (files.length === 0) process.exit(0);

  // Derive action + filename for message
  const filePath = tool_input?.file_path || tool_input?.filePath || files[0];
  const fileName = filePath.split('/').pop();
  const action = tool_input?.content ? 'Update' : 'Modify';

  const commitMsg = `chore: ${action} ${fileName}\n\n- Automated suggestion from Codex helper`;

  const auto = process.env.CODEX_AUTO_COMMIT === '1';
  if (!auto) {
    // Suggest commands (do not stage/commit)
    const addList = files.map(f => `'${f.replace(/'/g, "'\\''")}'`).join(' ');
    console.log('\nSuggested commit:');
    console.log(`  git add ${addList}`);
    console.log(`  git commit -m ${JSON.stringify(commitMsg)}`);
    process.exit(0);
  }

  // Auto mode: stage and commit
  files.forEach(file => {
    try {
      execSync(`git add "${file}"`, { stdio: 'pipe' });
    } catch (err) {
      console.error(`Failed to stage ${file}`);
    }
  });

  try {
    execSync(`git commit -m ${JSON.stringify(commitMsg)}`, { stdio: 'pipe' });
    console.log(`✓ Changes committed: ${commitMsg.split('\n')[0]}`);
  } catch (err) {
    if (!String(err?.message || '').includes('nothing to commit')) {
      console.error('Commit failed:', err.message);
    }
  }

  process.exit(0);

} catch (error) {
  console.error('Git commit helper error:', error.message);
  process.exit(1);
}
