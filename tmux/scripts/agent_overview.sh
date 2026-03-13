#!/usr/bin/env bash
set -euo pipefail

interval="${AGENT_OVERVIEW_INTERVAL:-2}"
keys=(a b c d e f g h i j k l m n o p q r s t u v w x y z A B C D E F G H I J K L M N P R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9)

trim_text() {
  local value="$1"
  local max_len="$2"

  value="${value//$'\t'/ }"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"

  if (( ${#value} <= max_len )); then
    printf '%s' "$value"
    return
  fi

  printf '%s...' "${value:0:max_len-3}"
}

state_label() {
  case "$1" in
    attention) printf 'ATTN' ;;
    done) printf 'DONE' ;;
    *) printf 'BUSY' ;;
  esac
}

state_color() {
  case "$1" in
    attention) printf '\033[1;31m' ;;
    done) printf '\033[1;32m' ;;
    *) printf '\033[1;34m' ;;
  esac
}

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

last_snippet() {
  local pane_id="$1"
  local snippet

  snippet="$(
    tmux capture-pane -p -t "$pane_id" -S -20 2>/dev/null \
      | awk 'NF { line = $0 } END { print line }'
  )"

  trim_text "${snippet:-}" 110
}

render_overview() {
  local panes_raw pane_id pane_suffix state pane_info session_name window_index
  local window_name pane_index pane_path pane_title pane_active project preview
  local attention_count busy_count done_count current_project idx label key
  local -a rows=()
  local -a mappings=()

  panes_raw="$(tmux show-option -gqv @agent_notify_all_panes 2>/dev/null || true)"
  panes_raw="${panes_raw#"${panes_raw%%[![:space:]]*}"}"
  panes_raw="${panes_raw%"${panes_raw##*[![:space:]]}"}"

  attention_count=0
  busy_count=0
  done_count=0

  if [[ -n "$panes_raw" ]]; then
    for pane_id in $panes_raw; do
      pane_suffix="${pane_id#%}"
      state="$(tmux show-option -gqv "@agent_notify_state_${pane_suffix}" 2>/dev/null || true)"
      pane_info="$(tmux display-message -p -t "$pane_id" '#{session_name}|#{window_index}|#{window_name}|#{pane_index}|#{pane_current_path}|#{pane_title}|#{?pane_active,1,0}' 2>/dev/null || true)"
      IFS='|' read -r session_name window_index window_name pane_index pane_path pane_title pane_active <<< "$pane_info"

      project="$(project_name "$pane_path" "$session_name")"
      pane_title="$(trim_text "${pane_title:-}" 70)"
      preview="$(last_snippet "$pane_id")"
      rows+=("${project}|${session_name}|${window_index}|${window_name}|${pane_index}|${pane_id}|${state}|${pane_active}|${pane_title}|${pane_path}|${preview}")

      case "$state" in
        attention) attention_count=$((attention_count + 1)) ;;
        done) done_count=$((done_count + 1)) ;;
        *) busy_count=$((busy_count + 1)) ;;
      esac
    done
  fi

  printf '\033[2J\033[H'
  printf 'Agent Overview\n'
  printf 'Attention %d  Busy %d  Done %d\n\n' "$attention_count" "$busy_count" "$done_count"

  if (( ${#rows[@]} == 0 )); then
    printf 'No Codex or Claude panes were detected by tmux-agent-notify.\n\n'
    printf 'Press q to close, r to refresh.\n'
    MAP_RESULT=()
    return
  fi

  current_project=""
  idx=0
  while IFS='|' read -r project session_name window_index window_name pane_index pane_id state pane_active pane_title pane_path preview; do
    if [[ "$project" != "$current_project" ]]; then
      if [[ -n "$current_project" ]]; then
        printf '\n'
      fi
      printf '\033[1m%s\033[0m\n' "$project"
      current_project="$project"
    fi

    if (( idx >= ${#keys[@]} )); then
      break
    fi

    key="${keys[$idx]}"
    label="$(state_label "$state")"
    printf ' [%s] %s%-4s\033[0m  %s:%s.%s  %s' "$key" "$(state_color "$state")" "$label" "$session_name" "$window_index" "$pane_index" "$pane_title"
    if [[ "$pane_active" == "1" ]]; then
      printf '  *'
    fi
    printf '\n'
    if [[ -n "$preview" ]]; then
      printf '      %s\n' "$preview"
    else
      printf '      %s\n' "$(trim_text "$pane_path" 110)"
    fi

    mappings+=("${key}|${session_name}|${window_index}|${pane_id}")
    idx=$((idx + 1))
  done < <(printf '%s\n' "${rows[@]}" | sort -t '|' -k1,1 -k2,2 -k3,3n -k5,5n)

  printf '\n'
  printf 'Keys: a-z/0-9 jump, r refresh, q close.\n'
  MAP_RESULT=("${mappings[@]}")
}

jump_to_target() {
  local selected="$1"
  local mapping key session_name window_index pane_id

  for mapping in "${MAP_RESULT[@]}"; do
    IFS='|' read -r key session_name window_index pane_id <<< "$mapping"
    if [[ "$key" == "$selected" ]]; then
      tmux switch-client -t "$session_name"
      tmux select-window -t "${session_name}:${window_index}"
      tmux select-pane -t "$pane_id"
      return 0
    fi
  done

  return 1
}

pane_mode=false
case "${1:-}" in
  --once) render_overview; exit 0 ;;
  --pane) pane_mode=true ;;
esac

while true; do
  render_overview

  if IFS= read -rsn1 -t "$interval" key; then
    case "$key" in
      q)
        if ! $pane_mode; then
          exit 0
        fi
        ;;
      r) continue ;;
      *)
        if jump_to_target "$key"; then
          if ! $pane_mode; then
            exit 0
          fi
        fi
        ;;
    esac
  fi
done
