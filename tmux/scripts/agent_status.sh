#!/usr/bin/env bash
set -euo pipefail

panes_raw="$(tmux show-option -gqv @agent_notify_all_panes 2>/dev/null || true)"
panes_raw="${panes_raw#"${panes_raw%%[![:space:]]*}"}"
panes_raw="${panes_raw%"${panes_raw##*[![:space:]]}"}"

if [[ -z "$panes_raw" ]]; then
  printf 'AI 0'
  exit 0
fi

attention=0
busy=0
done_count=0
declare -a attention_labels=()

trim_label() {
  local value="$1"
  local max_len="$2"

  if (( ${#value} <= max_len )); then
    printf '%s' "$value"
    return
  fi

  printf '%s...' "${value:0:max_len-3}"
}

project_label() {
  local path="$1"
  local session_name="$2"
  local window_name="$3"
  local project

  if project="$(git -C "$path" rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"; then
    project="$(basename "$(cd "$project/.." && pwd)")"
  elif [[ "$path" == "$HOME" || "$path" == "$HOME/" ]]; then
    project="$session_name"
  else
    project="$(basename "$path")"
  fi

  if [[ -n "$window_name" && "$window_name" != "zsh" ]]; then
    printf '%s/%s' "$project" "$window_name"
    return
  fi

  printf '%s' "$project"
}

seen_labels=" "
for pane_id in $panes_raw; do
  pane_suffix="${pane_id#%}"
  state="$(tmux show-option -gqv "@agent_notify_state_${pane_suffix}" 2>/dev/null || true)"
  pane_info="$(tmux display-message -p -t "$pane_id" '#{pane_current_path}|#{session_name}|#{window_name}' 2>/dev/null || true)"
  pane_path="${pane_info%%|*}"
  pane_info="${pane_info#*|}"
  session_name="${pane_info%%|*}"
  window_name="${pane_info#*|}"

  case "$state" in
    attention)
      attention=$((attention + 1))
      if (( ${#attention_labels[@]} < 2 )); then
        label="$(project_label "$pane_path" "$session_name" "$window_name")"
        if [[ "$seen_labels" != *" $label "* ]]; then
          attention_labels+=("$(trim_label "$label" 26)")
          seen_labels+=" $label "
        fi
      fi
      ;;
    done)
      done_count=$((done_count + 1))
      ;;
    *)
      busy=$((busy + 1))
      ;;
  esac
done

segments=("AI")
if (( attention > 0 )); then
  segments+=("!${attention}")
fi
if (( busy > 0 )); then
  segments+=("~${busy}")
fi
if (( done_count > 0 )); then
  segments+=("+${done_count}")
fi
if (( attention == 0 && busy == 0 && done_count == 0 )); then
  segments+=("0")
fi

printf '%s' "${segments[0]}"
for ((i = 1; i < ${#segments[@]}; i++)); do
  printf ' %s' "${segments[$i]}"
done

if (( ${#attention_labels[@]} > 0 )); then
  printf ' | '
  printf '%s' "${attention_labels[0]}"
  for ((i = 1; i < ${#attention_labels[@]}; i++)); do
    printf ', %s' "${attention_labels[$i]}"
  done
fi
