#!/bin/bash

# SessionStart helper - Provides context when starting/resuming sessions

# Read JSON input from stdin with timeout
if ! INPUT=$(timeout 1 cat 2>/dev/null); then
    INPUT='{"source":"startup"}'
fi

SOURCE=$(echo "$INPUT" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('source', 'startup'))" 2>/dev/null || echo "startup")

if [[ "$SOURCE" == "compact" ]]; then
  printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":""}}'
  exit 0
fi

CONTEXT=""

case "$SOURCE" in
  startup) CONTEXT+="📍 Session Context (New Session)\n\n" ;;
  resume)  CONTEXT+="📍 Session Context (Resumed)\n\n" ;;
  clear)   CONTEXT+="📍 Session Context (Cleared)\n\n" ;;
esac

CWD=$(pwd)
CONTEXT+="Working Directory: $CWD\n\n"

if git rev-parse --git-dir >/dev/null 2>&1; then
  CONTEXT+="━━━ Git Repository ━━━\n"
  BRANCH=$(git branch --show-current 2>/dev/null || echo "detached HEAD")
  CONTEXT+="Branch: $BRANCH\n\n"

  if [[ "$SOURCE" == "startup" ]] || [[ "$SOURCE" == "resume" ]]; then
    CONTEXT+="Recent Commits:\n"
    git log --oneline --no-decorate -n 5 2>/dev/null | sed 's/^/  • /' >> /tmp/._codex_recent_commits
    cat /tmp/._codex_recent_commits >> /dev/stdout
    rm -f /tmp/._codex_recent_commits
    CONTEXT+="\n"
  fi

  if STATUS=$(git status --short 2>/dev/null); then
    if [[ -n "$STATUS" ]]; then
      MODIFIED=$(echo "$STATUS" | grep -c "^ M" 2>/dev/null || echo 0)
      STAGED=$(echo "$STATUS" | grep -c "^M" 2>/dev/null || echo 0)
      UNTRACKED=$(echo "$STATUS" | grep -c "^??" 2>/dev/null || echo 0)
      CONTEXT+="Git Status:\n"
      [[ $MODIFIED -gt 0 ]] && CONTEXT+="  • $MODIFIED file(s) modified\n"
      [[ $STAGED -gt 0 ]]   && CONTEXT+="  • $STAGED file(s) staged\n"
      [[ $UNTRACKED -gt 0 ]]&& CONTEXT+="  • $UNTRACKED untracked file(s)\n"
      CONTEXT+="\n"
    fi
  fi

  STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')
  if [[ $STASH_COUNT -gt 0 ]]; then
    CONTEXT+="Stash: $STASH_COUNT stashed change(s)\n\n"
  fi
fi

CONTEXT+="━━━ Project Info ━━━\n"
PROJECT_TYPES=()
[[ -f "package.json" ]] && PROJECT_TYPES+=("Node.js")
[[ -f "tsconfig.json" ]] && PROJECT_TYPES+=("TypeScript")
([[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]]) && PROJECT_TYPES+=("Python")
[[ -f "Cargo.toml" ]] && PROJECT_TYPES+=("Rust")
[[ -f "go.mod" ]] && PROJECT_TYPES+=("Go")
([[ -f "next.config.js" ]] || [[ -f "next.config.ts" ]] || [[ -f "next.config.mjs" ]]) && PROJECT_TYPES+=("Next.js")
([[ -f "vite.config.js" ]] || [[ -f "vite.config.ts" ]]) && PROJECT_TYPES+=("Vite")

if [[ ${#PROJECT_TYPES[@]} -gt 0 ]]; then
  CONTEXT+="Project Type: ${PROJECT_TYPES[*]}\n"
else
  CONTEXT+="Project Type: Unknown\n"
fi

CONFIG_FILES=()
for file in package.json tsconfig.json next.config.* vite.config.* tailwind.config.* .env.example README.md; do
  matches=($file)
  for match in "${matches[@]}"; do
    [[ -f "$match" ]] && CONFIG_FILES+=("$match") && break
  done
done

if [[ ${#CONFIG_FILES[@]} -gt 0 ]]; then
  CONTEXT+="\nKey Files: ${CONFIG_FILES[*]}\n"
fi

CONTEXT+="\n"

printf '%s' "$CONTEXT"

STATUSLINE_SCRIPT="$HOME/.codex/hooks/statusline.sh"
if [[ -x "$STATUSLINE_SCRIPT" ]]; then
  printf '\n'
  if [[ -n "$INPUT" ]]; then
    printf '%s' "$INPUT" | bash "$STATUSLINE_SCRIPT"
  elif command -v jq >/dev/null 2>&1; then
    jq -n --arg current_dir "$CWD" '{model:{display_name:"Codex"}, workspace:{current_dir:$current_dir}, cost:{total_api_duration_ms:0,total_cost_usd:0}}' \
      | bash "$STATUSLINE_SCRIPT"
  else
    printf '%s' "{\"model\":{\"display_name\":\"Codex\"},\"workspace\":{\"current_dir\":\"$CWD\"},\"cost\":{\"total_api_duration_ms\":0,\"total_cost_usd\":0}}" \
      | bash "$STATUSLINE_SCRIPT"
  fi
fi

exit 0
