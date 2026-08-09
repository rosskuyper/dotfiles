#!/bin/sh
input=$(cat)
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty')
used_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cur_input=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // 0')
cur_cache_create=$(echo "$input" | jq -r '.context_window.current_usage.cache_creation_input_tokens // 0')
cur_cache_read=$(echo "$input" | jq -r '.context_window.current_usage.cache_read_input_tokens // 0')
model_name=$(echo "$input" | jq -r '.model.display_name // empty')
fast_mode=$(echo "$input" | jq -r '.fast_mode // false')
cost_usd=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')

# Solarized-style ANSI colors (256-color)
bold='\033[1m'
reset='\033[0m'
orange='\033[38;5;166m'
yellow='\033[38;5;136m'
green='\033[38;5;64m'
violet='\033[38;5;61m'
blue='\033[38;5;33m'
white='\033[38;5;15m'
cyan='\033[38;5;37m'

# Username
user=$(whoami)

# Working directory: abbreviate $HOME to ~
if [ -n "$cwd" ]; then
  display_dir=$(echo "$cwd" | sed "s|^$HOME|~|")
else
  display_dir=$(pwd | sed "s|^$HOME|~|")
fi

# Git branch and status (skip optional locks to avoid contention)
git_info=""
if git --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git --no-optional-locks symbolic-ref --quiet --short HEAD 2>/dev/null \
    || git --no-optional-locks describe --all --exact-match HEAD 2>/dev/null \
    || git --no-optional-locks rev-parse --short HEAD 2>/dev/null \
    || echo '(unknown)')
  s=""
  if ! git --no-optional-locks diff --quiet --ignore-submodules --cached 2>/dev/null; then
    s="${s}+"
  fi
  if ! git --no-optional-locks diff-files --quiet --ignore-submodules -- 2>/dev/null; then
    s="${s}!"
  fi
  if [ -n "$(git --no-optional-locks ls-files --others --exclude-standard 2>/dev/null)" ]; then
    s="${s}?"
  fi
  if git --no-optional-locks rev-parse --verify refs/stash >/dev/null 2>&1; then
    s="${s}\$"
  fi
  status_str=""
  [ -n "$s" ] && status_str=" [${s}]"
  git_info=$(printf " ${white}on ${violet}%s${blue}%s${reset}" "$branch" "$status_str")
fi

# Build the PS1-style line (single line, no trailing $ )
printf "${bold}${orange}%s${reset}${white} in ${green}%s${reset}%s" \
  "$user" "$display_dir" "$git_info"

# Current model (with a marker when fast mode is on)
if [ -n "$model_name" ]; then
  [ "$fast_mode" = "true" ] && model_name="${model_name} \xe2\x9a\xa1"
  printf "${white} | ${cyan}%b${reset}" "$model_name"
fi

# Append context window usage if available
if [ -n "$used_pct" ]; then
  used_tokens=$((cur_input + cur_cache_create + cur_cache_read))
  if [ "$used_tokens" -ge 1000 ]; then
    abbreviated=$(awk "BEGIN { printf \"%.1fk\", $used_tokens / 1000 }")
  else
    abbreviated="${used_tokens}"
  fi
  pct_fmt=$(printf "%.1f%%" "$used_pct")
  printf "${white} | ${yellow}%s${reset} (%s)" "$abbreviated" "$pct_fmt"
fi

# Session cost so far
if [ -n "$cost_usd" ]; then
  printf "${white} | ${green}\$%.2f${reset}" "$cost_usd"
fi

printf "${reset}"