#!/usr/bin/env node

const fs = require('fs');

/**
 * PreToolUse hook: Validate tool inputs before execution
 * Prevents common mistakes and enforces best practices
 */

const VALIDATION_RULES = {
  bash: [
    {
      pattern: /\brm\s+-rf\s+\/(?!tmp|var\/tmp)/,
      message: 'BLOCKED: Dangerous rm -rf on root directory'
    },
    {
      pattern: /\bgrep\b(?!.*\|)/,
      message: 'Use "rg" (ripgrep) instead of "grep" for better performance'
    },
    {
      pattern: /\bfind\s+.*-name/,
      message: 'Use "rg --files | rg pattern" instead of "find -name"'
    },
    {
      pattern: /npm\s+install\s+(?!-g)(?!.*--save)/,
      message: 'Use "npm install --save" or "npm install --save-dev"'
    }
  ],
  edit: [
    {
      pattern: /console\.log.*(?:password|secret|key|token)/i,
      message: 'WARNING: Potential secret in console.log - review carefully'
    }
  ]
};

try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const { tool_name, tool_input } = input;
  
  // Validate Bash commands
  if (tool_name === 'Bash' && tool_input?.command) {
    const command = tool_input.command;
    const issues = [];
    
    for (const rule of VALIDATION_RULES.bash) {
      if (rule.pattern.test(command)) {
        issues.push(rule.message);
      }
    }
    
    if (issues.length > 0) {
      console.error('Command validation failed:');
      issues.forEach(issue => console.error(`  • ${issue}`));
      
      // Exit code 2 blocks the tool and shows message to Claude/Codex
      process.exit(2);
    }
  }
  
  // Validate file edits
  if (['Edit', 'Write', 'MultiEdit'].includes(tool_name)) {
    const content = tool_input?.content || '';
    const issues = [];
    
    for (const rule of VALIDATION_RULES.edit) {
      if (rule.pattern.test(content)) {
        issues.push(rule.message);
      }
    }
    
    // Check for common mistakes
    if (content.includes('TODO') || content.includes('FIXME')) {
      issues.push('File contains TODO/FIXME markers - resolve before committing');
    }
    
    if (issues.length > 0) {
      console.error('Code validation warnings:');
      issues.forEach(issue => console.error(`  • ${issue}`));
      // Don't block, just warn (exit 0)
    }
  }
  
  // Validate file paths
  const filePath = tool_input?.file_path || tool_input?.filePath;
  if (filePath) {
    // Block path traversal attempts
    if (filePath.includes('..')) {
      console.error('BLOCKED: Path traversal detected in file path');
      process.exit(2);
    }
    
    // Warn about sensitive files
    const sensitivePatterns = [
      '.env',
      '.env.local',
      '.env.production',
      'id_rsa',
      'id_ed25519',
      '.aws/credentials',
      '.ssh/'
    ];
    
    if (sensitivePatterns.some(pattern => filePath.includes(pattern))) {
      console.error('WARNING: Attempting to modify sensitive file:', filePath);
      console.error('Ensure this is intentional and secrets are not exposed');
    }
  }
  
  process.exit(0);

} catch (error) {
  console.error('Pre-tool validation error:', error.message);
  process.exit(1);
}

