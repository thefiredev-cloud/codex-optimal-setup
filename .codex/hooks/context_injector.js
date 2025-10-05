#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * UserPromptSubmit helper: Inject additional context before processing
 * Adds git status, recent changes, and environment info
 */

try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const { prompt, cwd } = input;
  
  if (!cwd) process.exit(0);
  
  const context = [];
  
  // Add current working directory info
  context.push(`Working Directory: ${cwd}`);
  
  // Try to get git branch and status
  try {
    process.chdir(cwd);
    const branch = execSync('git branch --show-current', { 
      encoding: 'utf8', 
      stdio: 'pipe' 
    }).trim();
    
    if (branch) {
      context.push(`Git Branch: ${branch}`);
      
      // Get uncommitted changes count
      const status = execSync('git status --porcelain', { 
        encoding: 'utf8',
        stdio: 'pipe' 
      });
      
      const changes = status.split('\n').filter(l => l.trim()).length;
      if (changes > 0) {
        context.push(`Uncommitted Changes: ${changes} files`);
      }
      
      // Get last commit
      try {
        const lastCommit = execSync('git log -1 --oneline', { 
          encoding: 'utf8',
          stdio: 'pipe' 
        }).trim();
        context.push(`Last Commit: ${lastCommit}`);
      } catch {}
    }
  } catch {
    // Not a git repo or git not available
  }
  
  // Check for common files that indicate project type
  const indicators = {
    'package.json': 'Node.js',
    'requirements.txt': 'Python',
    'Cargo.toml': 'Rust',
    'go.mod': 'Go',
    'pom.xml': 'Java/Maven',
    'build.gradle': 'Java/Gradle'
  };
  
  for (const [file, type] of Object.entries(indicators)) {
    if (fs.existsSync(path.join(cwd, file))) {
      context.push(`Project Type: ${type}`);
      break;
    }
  }
  
  // Check if prompt references files that don't exist
  const fileMatches = prompt?.match(/\b[\w\-./]+\.(ts|tsx|js|jsx|py|rs|go|java)\b/g);
  if (fileMatches) {
    const missing = fileMatches.filter(f => !fs.existsSync(path.join(cwd, f)));
    if (missing.length > 0) {
      context.push(`Note: Referenced files not found: ${missing.join(', ')}`);
    }
  }
  
  // Add timestamp for reference
  context.push(`Timestamp: ${new Date().toISOString()}`);
  
  // Output context
  if (context.length > 0) {
    console.log('\n--- Context ---');
    console.log(context.join('\n'));
    console.log('--- End Context ---\n');
  }
  
  process.exit(0);

} catch (error) {
  console.error('Context injection helper error:', error.message);
  process.exit(1);
}

