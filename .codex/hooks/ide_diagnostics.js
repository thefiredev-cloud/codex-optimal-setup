#!/usr/bin/env node

const fs = require('fs');
const { execSync } = require('child_process');

/**
 * PostToolUse helper: Run IDE diagnostics and auto-fix issues
 * Triggers after Edit, Write, or MultiEdit operations
 */

try {
  const input = JSON.parse(fs.readFileSync(0, 'utf8'));
  const { tool_input, cwd } = input;
  
  // Extract file path based on tool type
  let filePath = tool_input?.file_path || tool_input?.filePath;
  
  if (!filePath) {
    // For MultiEdit, process all files
    if (tool_input?.edits) {
      const files = tool_input.edits.map(e => e.file_path || e.filePath).filter(Boolean);
      filePath = files[0]; // Process first file for now
    }
  }

  if (!filePath) {
    process.exit(0);
  }

  // Change to project directory
  if (cwd) {
    process.chdir(cwd);
  }

  const ext = filePath.split('.').pop();
  const isTypeScript = ['ts', 'tsx'].includes(ext);
  const isJavaScript = ['js', 'jsx', 'mjs'].includes(ext);
  const isCodeFile = isTypeScript || isJavaScript;

  if (!isCodeFile) {
    process.exit(0);
  }

  console.log(`Running diagnostics on ${filePath}...`);

  // Check if file exists
  if (!fs.existsSync(filePath)) {
    console.error(`File not found: ${filePath}`);
    process.exit(1);
  }

  const errors = [];
  const fixes = [];

  // Run ESLint if available
  try {
    execSync(`npx eslint \"${filePath}\" --fix`, { 
      stdio: 'pipe',
      timeout: 10000 
    });
    fixes.push('ESLint auto-fix applied');
  } catch (err) {
    if (err.stdout) {
      const output = err.stdout.toString();
      if (output.includes('error') || output.includes('warning')) {
        errors.push(`ESLint issues: ${output.substring(0, 200)}`);
      }
    }
  }

  // Run TypeScript compiler if TS file
  if (isTypeScript) {
    try {
      const result = execSync(`npx tsc --noEmit \"${filePath}\"`, { 
        stdio: 'pipe',
        timeout: 15000 
      }).toString();
      
      if (result) {
        console.log('TypeScript check passed');
      }
    } catch (err) {
      if (err.stdout) {
        const output = err.stdout.toString();
        errors.push(`TypeScript errors: ${output.substring(0, 300)}`);
      }
    }
  }

  // Output results
  if (fixes.length > 0) {
    console.log('\n✓ Auto-fixes applied:');
    fixes.forEach(fix => console.log(`  - ${fix}`));
  }

  if (errors.length > 0) {
    console.error('\n✗ Issues found that need manual attention:');
    errors.forEach(err => console.error(`  ${err}`));
    
    // Exit code 2 = show to calling agent for fixing
    process.exit(2);
  }

  console.log('✓ All diagnostics passed');
  process.exit(0);

} catch (error) {
  console.error('Hook execution error:', error.message);
  process.exit(1);
}
