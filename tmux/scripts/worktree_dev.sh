#!/usr/bin/env bash
set -euo pipefail

# worktree_dev.sh — Create a tmux window with a 3-pane layout:
#
#   ┌────────────┬────────────────────┬────────┐
#   │            │                    │        │
#   │   Nvim     │   Claude Code      │ Agents │
#   │  (~35%)    │    (~50%)          │ (~15%) │
#   │            │                    │        │
#   └────────────┴────────────────────┴────────┘
#
# Usage: worktree_dev.sh <branch-name>

# Accept optional project root as second argument (used by worktree-picker)
if [[ -n "${2:-}" ]]; then
  project_root="$2"
else
  pane_path="$(tmux display-message -p '#{pane_current_path}')"
  if ! git_common="$(git -C "$pane_path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    tmux display-message "Not in a git repository"
    exit 1
  fi
  project_root="$(cd "$git_common/.." && pwd)"
fi

branch_name="${1:-}"
if [[ -z "$branch_name" ]]; then
  tmux display-message "Branch name required"
  exit 1
fi

# Sanitize branch name for directory/window name
dir_name="${branch_name//\//-}"
worktree_dir="${project_root}/.worktrees/${dir_name}"
session="$(tmux display-message -p '#{session_name}')"

# If a window with this name already exists, just switch to it
if tmux list-windows -t "$session" -F '#{window_name}' | grep -qx "$dir_name"; then
  tmux select-window -t "${session}:=${dir_name}"
  exit 0
fi

# Create worktree if it doesn't exist
if [[ ! -d "$worktree_dir" ]]; then
  mkdir -p "${project_root}/.worktrees"
  if ! git -C "$project_root" worktree add "$worktree_dir" -b "$branch_name" &>/dev/null; then
    git -C "$project_root" worktree add "$worktree_dir" "$branch_name" &>/dev/null
  fi
fi

# --- Build all 3 panes first, then send commands ---

# Pane 1: nvim (starts as full window)
tmux new-window -n "$dir_name" -c "$worktree_dir"

# Pane 2: split right from pane 1, takes 65% (leaving 35% for nvim)
tmux split-window -h -l 65% -c "$worktree_dir"

# Pane 3: split right from pane 2, takes 30% for sidebar
tmux split-window -h -l 30% -c "$worktree_dir"

# Wait for shells to initialize before sending commands
sleep 0.5

# Send commands to each pane (pane-base-index defaults to 0)
tmux send-keys -t "${session}:=${dir_name}.0" "nvim ." Enter
tmux send-keys -t "${session}:=${dir_name}.1" "claude" Enter
tmux send-keys -t "${session}:=${dir_name}.2" "$HOME/dotfiles/tmux/agent-sidebar/agent-sidebar" Enter

# Focus on Claude Code pane (main working pane)
tmux select-pane -t "${session}:=${dir_name}.1"
