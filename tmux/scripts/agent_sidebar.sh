#!/usr/bin/env bash
set -euo pipefail

# agent_sidebar.sh — Compact, interactive agent status sidebar.
# Navigate with j/k, jump to agent with Enter, g/G for top/bottom.

interval="${AGENT_SIDEBAR_INTERVAL:-3}"
selected=0

project_name() {
  local path="$1"
  local session_name="$2"
  local common_dir

  if common_dir="$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    basename "$(cd "$common_dir/.." && pwd)"
    return
  fi

  if [[ "$path" == "$HOME" || "$path" == "$HOME/" ]]; then
    printf '%s' "$session_name"
    return
  fi

  if [[ -n "$path" && "$path" != "/" ]]; then
    basename "$path"
    return
  fi

  printf '%s' "$session_name"
}

# Global state populated by render
declare -a jump_targets=()
item_count=0

render() {
  local panes_raw pane_id pane_suffix state pane_info
  local session_name window_index window_name pane_index pane_path project
  local current_project=""
  local buf=""
  local idx=0

  jump_targets=()

  panes_raw="$(tmux show-option -gqv @agent_notify_all_panes 2>/dev/null || true)"
  panes_raw="${panes_raw#"${panes_raw%%[![:space:]]*}"}"
  panes_raw="${panes_raw%"${panes_raw##*[![:space:]]}"}"

  buf+='\033[1mAgents\033[0m\n'

  if [[ -z "$panes_raw" ]]; then
    buf+='\n\033[2mNo agents\033[0m\n'
    item_count=0
    printf '\033[H%b\033[J' "$buf"
    return
  fi

  # Collect rows: project|state|session|window_index|pane_index|pane_id|window_name
  local -a rows=()
  for pane_id in $panes_raw; do
    pane_suffix="${pane_id#%}"
    state="$(tmux show-option -gqv "@agent_notify_state_${pane_suffix}" 2>/dev/null || true)"
    pane_info="$(tmux display-message -p -t "$pane_id" '#{session_name}|#{window_index}|#{window_name}|#{pane_index}|#{pane_current_path}' 2>/dev/null || true)"
    [[ -z "$pane_info" ]] && continue
    IFS='|' read -r session_name window_index window_name pane_index pane_path <<< "$pane_info"

    project="$(project_name "$pane_path" "$session_name")"
    rows+=("${project}|${state}|${session_name}|${window_index}|${pane_index}|${pane_id}|${window_name}")
  done

  current_project=""
  while IFS='|' read -r project state session_name window_index pane_index pane_id wname; do
    if [[ "$project" != "$current_project" ]]; then
      buf+="\n\033[1m${project}\033[0m\n"
      current_project="$project"
    fi

    # Store jump target
    jump_targets+=("${session_name}|${window_index}|${pane_id}")

    # Determine display name
    local label
    if [[ -n "$wname" && "$wname" != "zsh" && "$wname" != "bash" ]]; then
      label="$wname"
    else
      label="${session_name}:${window_index}.${pane_index}"
    fi

    # Determine state text
    local state_text
    case "$state" in
      attention) state_text="! ATTN" ;;
      done)      state_text="+ DONE" ;;
      *)         state_text="~ BUSY" ;;
    esac

    if (( idx == selected )); then
      # Selected: reverse video, full-width highlight
      buf+="\033[7m ▸ ${state_text}  ${label}\033[K\033[0m\n"
    else
      # Normal: colored state
      case "$state" in
        attention) buf+="   \033[1;31m${state_text}\033[0m  ${label}\n" ;;
        done)      buf+="   \033[1;32m${state_text}\033[0m  ${label}\n" ;;
        *)         buf+="   \033[1;34m${state_text}\033[0m  ${label}\n" ;;
      esac
    fi

    idx=$((idx + 1))
  done < <(printf '%s\n' "${rows[@]}" | sort -t '|' -k1,1 -k2,2)

  item_count=${#jump_targets[@]}
  clamp_selected

  printf '\033[H%b\033[J' "$buf"
}

clamp_selected() {
  local max=$((item_count - 1))
  if (( max < 0 )); then max=0; fi
  if (( selected > max )); then selected=$max; fi
  if (( selected < 0 )); then selected=0; fi
}

jump_to_selected() {
  if (( item_count == 0 )); then return; fi
  if (( selected >= item_count )); then return; fi

  local target="${jump_targets[$selected]}"
  local session_name window_index pane_id
  IFS='|' read -r session_name window_index pane_id <<< "$target"

  tmux select-window -t "${session_name}:${window_index}"
  tmux select-pane -t "$pane_id"
}

# Hide cursor, clear screen
printf '\033[?25l\033[2J'
trap 'printf "\033[?25h"' EXIT

while true; do
  render

  if IFS= read -rsn1 -t "$interval" key; then
    case "$key" in
      j) selected=$((selected + 1)); clamp_selected ;;
      k) selected=$((selected - 1)); clamp_selected ;;
      g) selected=0 ;;
      G) selected=$((item_count - 1)); clamp_selected ;;
      '') jump_to_selected ;;  # Enter
    esac
  fi
done
