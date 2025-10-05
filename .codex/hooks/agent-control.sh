#!/bin/bash

# Simple agent enable/disable control
if [ -f ~/.claude/agents-disabled ]; then
  echo "❌ Agents disabled. Enable with: rm ~/.claude/agents-disabled" >&2
  exit 1
fi

if [ "$AGENTS_DISABLED" = "1" ]; then
  echo "❌ Agents disabled. Enable with: export AGENTS_DISABLED=0" >&2
  exit 1
fi

echo "🤖 Agent spawned at $(date)" >> ~/.claude/agent-usage.log
exit 0

