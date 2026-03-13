#!/usr/bin/env bash
set -euo pipefail

# toggle_sidebar.sh — Toggle the agent sidebar pane in the current window.

# Check if agent-sidebar is running in any pane of the current window
sidebar_pane="$(tmux list-panes -F '#{pane_id} #{pane_current_command}' \
  | grep 'agent-sidebar' | head -1 | awk '{print $1}' || true)"

if [[ -n "$sidebar_pane" ]]; then
  # Find Claude Code pane before killing the sidebar
  claude_pane="$(tmux list-panes -F '#{pane_id} #{pane_current_command}' \
    | grep -w 'claude' | head -1 | awk '{print $1}' || true)"
  tmux kill-pane -t "$sidebar_pane"
  if [[ -n "$claude_pane" ]]; then
    tmux select-pane -t "$claude_pane"
  fi
else
  # Split from the rightmost pane so the sidebar is always on the far right
  last_pane="$(tmux list-panes -F '#{pane_id}' | tail -1)"
  tmux split-window -h -l 22% -t "$last_pane" \
    "$HOME/dotfiles/tmux/agent-sidebar/agent-sidebar"
  # Focus stays on the new sidebar pane (split-window default)
fi
