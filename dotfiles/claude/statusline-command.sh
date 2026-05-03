#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract data from JSON
current_dir=$(echo "$input" | jq -r '.workspace.current_dir')
model=$(echo "$input" | jq -r '.model.display_name')

# Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# Icons (Nerd Font)
FOLDER_ICON=$'\uf07c'
BRANCH_ICON=$'\ue0a0'
MODEL_ICON=$'\uf121'
SEP='│'

# Get shell PS1 components
username=$(whoami)
hostname=$(cat /etc/hostname 2>/dev/null || echo "localhost")
dir_basename=$(basename "$current_dir")

# Get git branch (if in a git repository)
cd "$current_dir" 2>/dev/null
git_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

# Computer name
COMPUTER_NAME="UM880"
COMPUTER_ICON=$'\uf108'

# Build the status line with icons and colors
if [ -n "$git_branch" ]; then
    printf "${CYAN}${COMPUTER_ICON} %s${RESET} ${SEP} ${YELLOW}${FOLDER_ICON} %s${RESET} ${SEP} ${GREEN}${BRANCH_ICON} %s${RESET} ${SEP} ${MAGENTA}${MODEL_ICON} %s${RESET}" "$COMPUTER_NAME" "$dir_basename" "$git_branch" "$model"
else
    printf "${CYAN}${COMPUTER_ICON} %s${RESET} ${SEP} ${YELLOW}${FOLDER_ICON} %s${RESET} ${SEP} ${MAGENTA}${MODEL_ICON} %s${RESET}" "$COMPUTER_NAME" "$dir_basename" "$model"
fi