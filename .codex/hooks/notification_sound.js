#!/usr/bin/env node

const { exec } = require('child_process');
const os = require('os');

/**
 * Stop helper: Play notification sound when task completes
 * Cross-platform support for macOS, Linux, and Windows
 */

function getSoundConfig() {
  const platform = os.platform();

  switch (platform) {
    case 'darwin': // macOS
      return {
        command: 'afplay',
        soundFile: '/System/Library/Sounds/Submarine.aiff'
      };

    case 'linux':
      return {
        command: 'paplay',
        soundFile: '/usr/share/sounds/freedesktop/stereo/complete.oga'
      };

    case 'win32': // Windows
      return {
        command: 'powershell',
        soundFile: '-c (New-Object Media.SoundPlayer "C:\\Windows\\Media\\tada.wav").PlaySync()'
      };

    default:
      return null;
  }
}

function playSound() {
  const config = getSoundConfig();
  
  if (!config) {
    // Unsupported platform - fail silently
    process.exit(0);
    return;
  }

  const { command, soundFile } = config;
  const fullCommand = soundFile.includes('powershell') 
    ? `${command} ${soundFile}`
    : `${command} "${soundFile}"`;

  exec(fullCommand, (error) => {
    if (error && process.env.DEBUG) {
      console.error('Sound playback failed:', error.message);
    }
    process.exit(0);
  });
}

try {
  playSound();
} catch (error) {
  // Silent fail - don't interrupt workflow
  process.exit(0);
}
