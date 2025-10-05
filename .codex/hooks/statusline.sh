#!/bin/bash

# ANSI Color codes
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'
GRAY='\033[0;90m'

# Bright colors
BRIGHT_RED='\033[0;91m'
BRIGHT_GREEN='\033[0;92m'
BRIGHT_YELLOW='\033[0;93m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_MAGENTA='\033[0;95m'
BRIGHT_CYAN='\033[0;96m'

# Background colors
BG_RED='\033[41m'
BG_GREEN='\033[42m'
BG_YELLOW='\033[43m'
BG_BLUE='\033[44m'

# Icons/Symbols
ICON_MODEL="🤖"
ICON_FOLDER="📁"
ICON_GIT="⎇"
ICON_TOKENS="💾"
ICON_TIME="⏱️"
ICON_COST="💰"
ICON_BURN="🔥"
ICON_WINDOW="⏳"
ICON_STYLE="🎨"

# Read JSON input from stdin
json_input=$(cat)

# Parse JSON fields using jq (with fallbacks for missing fields)
model=$(echo "$json_input" | jq -r '.model.display_name // "Unknown"')
model_id=$(echo "$json_input" | jq -r '.model.id // ""')
current_dir=$(echo "$json_input" | jq -r '.workspace.current_dir // .cwd // "~"')
session_id=$(echo "$json_input" | jq -r '.session_id // ""')
output_style=$(echo "$json_input" | jq -r '.output_style.name // "default"')
transcript_path=$(echo "$json_input" | jq -r '.transcript_path // ""')

# Get usage metrics (format‑agnostic)
total_duration_ms=$(echo "$json_input" | jq -r '.cost.total_duration_ms // .total_duration_ms // 0')
total_api_duration_ms=$(echo "$json_input" | jq -r '.cost.total_api_duration_ms // .total_api_duration_ms // 0')
total_cost_usd=$(echo "$json_input" | jq -r '.cost.total_cost_usd // .total_cost_usd // 0')
total_lines_added=$(echo "$json_input" | jq -r '.cost.total_lines_added // .total_lines_added // 0')
total_lines_removed=$(echo "$json_input" | jq -r '.cost.total_lines_removed // .total_lines_removed // 0')

# Parse token usage from transcript file
total_input_tokens=0
total_output_tokens=0
total_cache_creation_tokens=0
total_cache_read_tokens=0

if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    while IFS= read -r line; do
        input_tokens=$(echo "$line" | jq -r '.usage.input_tokens // 0' 2>/dev/null)
        output_tokens=$(echo "$line" | jq -r '.usage.output_tokens // 0' 2>/dev/null)
        cache_creation_tokens=$(echo "$line" | jq -r '.usage.cache_creation_input_tokens // 0' 2>/dev/null)
        cache_read_tokens=$(echo "$line" | jq -r '.usage.cache_read_input_tokens // 0' 2>/dev/null)

        total_input_tokens=$((total_input_tokens + input_tokens))
        total_output_tokens=$((total_output_tokens + output_tokens))
        total_cache_creation_tokens=$((total_cache_creation_tokens + cache_creation_tokens))
        total_cache_read_tokens=$((total_cache_read_tokens + cache_read_tokens))
    done < "$transcript_path"
fi

total_tokens=$((total_input_tokens + total_output_tokens + total_cache_creation_tokens + total_cache_read_tokens))

# Context window percentage (assume 200k)
context_window=200000
if [ $total_tokens -gt 0 ] && [ $context_window -gt 0 ]; then
    context_percentage=$(echo "scale=1; ($total_tokens / $context_window) * 100" | bc -l)
else
    context_percentage="0.0"
fi

# Burn rate ($/hr)
burn_rate="0.00"
if [ "$total_api_duration_ms" -ne 0 ] && (( $(echo "$total_cost_usd > 0" | bc -l) )); then
    hours=$(echo "scale=6; $total_api_duration_ms / 3600000" | bc -l)
    burn_rate=$(echo "scale=2; $total_cost_usd / $hours" | bc -l)
fi

# 5‑hour window remaining
window_hours=5
if [ "$total_api_duration_ms" -ne 0 ]; then
    used_hours=$(echo "scale=2; $total_api_duration_ms / 3600000" | bc -l)
    remaining_hours=$(echo "scale=2; $window_hours - $used_hours" | bc -l)
    if (( $(echo "$remaining_hours < 0" | bc -l) )); then
        window_display="OVER"
    else
        hours_int=$(echo "$remaining_hours" | cut -d'.' -f1)
        minutes=$(echo "scale=0; ($remaining_hours - $hours_int) * 60" | bc -l | cut -d'.' -f1)
        window_display="${hours_int}h${minutes}m"
    fi
else
    window_display="5h0m"
fi

# API duration pretty
if [ "$total_api_duration_ms" -ne 0 ]; then
    duration_seconds=$((total_api_duration_ms / 1000))
    duration_ms=$((total_api_duration_ms % 1000))
    if [ $duration_seconds -ge 3600 ]; then
        hours=$((duration_seconds / 3600))
        minutes=$(((duration_seconds % 3600) / 60))
        seconds=$((duration_seconds % 60))
        duration="${hours}h${minutes}m${seconds}s"
    elif [ $duration_seconds -ge 60 ]; then
        minutes=$((duration_seconds / 60))
        seconds=$((duration_seconds % 60))
        duration="${minutes}m${seconds}s"
    else
        duration="${duration_seconds}.$(printf "%03d" $duration_ms)s"
    fi
else
    duration="0s"
fi

# Cost pretty
if (( $(echo "$total_cost_usd < 1" | bc -l) )); then
    cost_cents=$(echo "$total_cost_usd * 100" | bc -l | xargs printf "%.1f")
    cost_display="${cost_cents}¢"
else
    cost_display=$(echo "$total_cost_usd" | xargs printf "$%.2f")
fi

# Normalize current dir
current_dir=$(echo "$current_dir" | sed "s|^$HOME|~|")
dir_parts=$(echo "$current_dir" | tr '/' '\n')
dir_count=$(echo "$dir_parts" | wc -l)
if [ $dir_count -gt 4 ]; then
    last_parts=$(echo "$current_dir" | rev | cut -d'/' -f1-3 | rev)
    current_dir=".../$last_parts"
fi

# Git info
git_info=""
repo_name=""
if command -v git &> /dev/null; then
    cd "$current_dir" 2>/dev/null || true
    if git rev-parse --git-dir &> /dev/null; then
        branch=$(git branch --show-current 2>/dev/null || git rev-parse --abbrev-ref HEAD 2>/dev/null)
        remote_url=$(git config --get remote.origin.url 2>/dev/null)
        if [ -n "$remote_url" ]; then
            repo_name=$(echo "$remote_url" | sed -E 's|.*/([^/]+)(\.git)?$|\1|' | sed 's/\.git$//')
        fi
        if [ -n "$repo_name" ] && [ -n "$branch" ]; then
            git_info=" | $repo_name:$branch"
        elif [ -n "$branch" ]; then
            git_info=" | git:$branch"
        fi
    fi
fi

# Model display
if [[ "$model_id" == *"opus-4"* ]] || [[ "$model" == *"Opus"* ]]; then
    model_display="Op. 4.1"
    model_color="${BRIGHT_MAGENTA}"
else
    model_display="${model}"
    model_color="${BRIGHT_CYAN}"
fi

# Token display + colors
if [ $total_tokens -gt 1000 ]; then
    tokens_display="$(echo "scale=1; $total_tokens / 1000" | bc -l)k"
else
    tokens_display="$total_tokens"
fi

context_pct_num=$(echo "$context_percentage" | cut -d'.' -f1)
if [ "$context_pct_num" -ge 80 ]; then
    context_color="${BRIGHT_RED}"
    context_icon="⚠️"
elif [ "$context_pct_num" -ge 60 ]; then
    context_color="${BRIGHT_YELLOW}"
    context_icon="⚡"
else
    context_color="${BRIGHT_GREEN}"
    context_icon="✓"
fi

if [ "$window_display" = "OVER" ]; then
    window_color="${BRIGHT_RED}${BOLD}"
    window_text="OVER LIMIT"
elif [[ "$window_display" =~ ^0h ]]; then
    window_color="${BRIGHT_YELLOW}"
    window_text="${window_display}"
else
    window_color="${GREEN}"
    window_text="${window_display}"
fi

cost_value=$(echo "$total_cost_usd" | bc -l)
if (( $(echo "$cost_value >= 10" | bc -l) )); then
    cost_color="${BRIGHT_RED}"
elif (( $(echo "$cost_value >= 1" | bc -l) )); then
    cost_color="${YELLOW}"
else
    cost_color="${GREEN}"
fi

# Build status line
status_line=""
status_line="${status_line}${ICON_MODEL} ${model_color}${BOLD}${model_display}${RESET}"
status_line="${status_line} ${GRAY}│${RESET} ${ICON_FOLDER} ${CYAN}${current_dir}${RESET}"
if [ -n "$git_info" ]; then
    repo_branch=$(echo "$git_info" | sed 's/ | //')
    status_line="${status_line} ${GRAY}│${RESET} ${ICON_GIT} ${BLUE}${repo_branch}${RESET}"
fi
status_line="${status_line} ${GRAY}│${RESET} ${ICON_TOKENS} ${context_color}${tokens_display}/200k${RESET} ${GRAY}(${context_color}${context_percentage}%${RESET}${GRAY})${RESET} ${context_icon}"
status_line="${status_line} ${GRAY}│${RESET} ${ICON_TIME} ${BRIGHT_YELLOW}${duration}${RESET}"
status_line="${status_line} ${GRAY}│${RESET} ${ICON_COST} ${cost_color}${cost_display}${RESET}"
if (( $(echo "$burn_rate > 5" | bc -l) )); then
    burn_color="${BRIGHT_RED}"
elif (( $(echo "$burn_rate > 1" | bc -l) )); then
    burn_color="${YELLOW}"
else
    burn_color="${GREEN}"
fi
status_line="${status_line} ${GRAY}│${RESET} ${ICON_BURN} ${burn_color}\$${burn_rate}/hr${RESET}"
status_line="${status_line} ${GRAY}│${RESET} ${ICON_WINDOW} ${window_color}${window_text}${RESET}"
if [ "$output_style" != "default" ]; then
    status_line="${status_line} ${GRAY}│${RESET} ${ICON_STYLE} ${MAGENTA}${output_style}${RESET}"
fi

echo -e "${status_line}${RESET}"

