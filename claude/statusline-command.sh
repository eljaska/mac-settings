#!/bin/sh
input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
dir=$(basename "$cwd")
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cost=$(echo "$input" | jq -r '.cost.total_cost_usd // empty')
tokens=$(echo "$input" | jq -r '((.context_window.total_input_tokens // 0) + (.context_window.total_output_tokens // 0)) | if . > 0 then . else empty end')
session_id=$(echo "$input" | jq -r '.session_id // empty')

# Per-turn deltas: compare current totals against cached previous totals.
turn_cost=""
turn_tokens=""
if [ -n "$session_id" ] && [ -n "$cost" ] && [ -n "$tokens" ]; then
  delta_dir="${HOME}/.cache/claude-statusline"
  mkdir -p "$delta_dir" 2>/dev/null
  delta_file="${delta_dir}/session_${session_id}"
  prev_cost=0
  prev_tokens=0
  if [ -f "$delta_file" ]; then
    prev_cost=$(awk -F'\t' '{print $1; exit}' "$delta_file")
    prev_tokens=$(awk -F'\t' '{print $2; exit}' "$delta_file")
  fi
  turn_cost=$(awk -v c="$cost" -v p="$prev_cost" 'BEGIN {d=c-p; if (d>0.001) printf "%.2f", d}')
  turn_tokens=$(awk -v t="$tokens" -v p="$prev_tokens" 'BEGIN {d=t-p; if (d>0) printf "%.0f", d}')
  printf '%s\t%s\n' "$cost" "$tokens" > "$delta_file"
fi

# Resolve VCS ref:
#   1. Real git branch
#   2. jj bookmark on @
#   3. jj parent has bookmark (↳ indicator)
#   4. jj change ID
#   5. Detached git SHA
vcs_ref=""
if [ -n "$cwd" ] && git -C "$cwd" rev-parse --git-dir >/dev/null 2>&1; then
  # Case 1: real git branch
  git_branch=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false symbolic-ref --short HEAD 2>/dev/null)
  if [ -n "$git_branch" ]; then
    vcs_ref="git: ${git_branch}"
  elif command -v jj >/dev/null 2>&1; then
    jj_change=$(jj -R "$cwd" log --no-graph -r @ -T 'change_id.shortest(8)' 2>/dev/null)
    if [ -n "$jj_change" ]; then
      jj_bookmark=$(jj -R "$cwd" log --no-graph -r @ -T 'bookmarks.map(|b| b.name()).join(" ")' 2>/dev/null)
      # Strip trailing * (unpushed indicator)
      jj_bookmark="${jj_bookmark%\*}"
      if [ -n "$jj_bookmark" ]; then
        # Case 2: @ is on a bookmark
        vcs_ref="jj: ${jj_bookmark}"
      else
        # @ has no bookmark — check the direct parent. Common after
        # `jj new <bookmark>`. Trailing ↳ means "working on a child of this".
        jj_parent_bookmark=$(jj -R "$cwd" log --no-graph -r '@-' -T 'bookmarks.map(|b| b.name()).join(" ")' 2>/dev/null)
        jj_parent_bookmark="${jj_parent_bookmark%\*}"
        if [ -n "$jj_parent_bookmark" ]; then
          # Case 3: parent has a bookmark
          vcs_ref="jj: ${jj_parent_bookmark} ↳"
        else
          # Case 4: jj change ID only
          vcs_ref="jj: ${jj_change}"
        fi
      fi
    else
      # Case 5: plain detached HEAD
      sha=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
      [ -n "$sha" ] && vcs_ref="detached @ ${sha}"
    fi
  else
    # Case 5: plain detached HEAD, no jj
    sha=$(git -C "$cwd" -c core.useBuiltinFSMonitor=false rev-parse --short HEAD 2>/dev/null)
    [ -n "$sha" ] && vcs_ref="detached @ ${sha}"
  fi
fi

# Look up GitHub PR for the current jj bookmark. Cached on disk with async
# refresh so the statusline never blocks on a network call. First render after
# switching bookmarks may show no PR; the next render (after the background
# `gh` returns) will pick it up.
pr_ref=""
pr_url=""
bookmark=""
if [ -n "$git_branch" ]; then
  bookmark="$git_branch"
elif [ -n "$jj_bookmark" ]; then
  bookmark="$jj_bookmark"
elif [ -n "$jj_parent_bookmark" ]; then
  bookmark="$jj_parent_bookmark"
fi

if [ -n "$bookmark" ] && command -v gh >/dev/null 2>&1; then
  cache_dir="${HOME}/.cache/claude-statusline"
  mkdir -p "$cache_dir" 2>/dev/null
  cache_key=$(printf '%s\n%s' "$cwd" "$bookmark" | shasum | cut -c1-16)
  cache_file="${cache_dir}/pr_${cache_key}"

  needs_refresh=true
  if [ -f "$cache_file" ]; then
    if [ $(( $(date +%s) - $(stat -f %m "$cache_file" 2>/dev/null || echo 0) )) -lt 300 ]; then
      needs_refresh=false
    fi
  fi
  if $needs_refresh; then
    (
      cd "$cwd" 2>/dev/null && \
      gh pr list --head "$bookmark" --json number,url \
        --jq '.[0] // empty | "\(.number)\t\(.url)"' \
        >"${cache_file}.tmp" 2>/dev/null && \
      mv "${cache_file}.tmp" "$cache_file"
    ) &
  fi

  if [ -s "$cache_file" ]; then
    pr_num=$(awk -F'\t' '{print $1; exit}' "$cache_file")
    pr_url=$(awk -F'\t' '{print $2; exit}' "$cache_file")
    [ -n "$pr_num" ] && pr_ref="PR #${pr_num}"
  fi
fi

# Look up next macOS Calendar event via a small EventKit-based Swift binary
# at ~/.config/claude-statusline/next_meeting (compiled from next_meeting.swift).
# Cached on disk with async refresh (60s TTL); the countdown is recomputed
# each render so it stays accurate without re-querying.
meeting_title=""
meeting_start=""
meeting_end=""
meeting_cache_dir="${HOME}/.cache/claude-statusline"
meeting_cache="${meeting_cache_dir}/next_meeting"
meeting_bin="${HOME}/.config/claude-statusline/next_meeting"

if [ -x "$meeting_bin" ]; then
  mkdir -p "$meeting_cache_dir" 2>/dev/null
  needs_meeting_refresh=true
  if [ -f "$meeting_cache" ]; then
    if [ $(( $(date +%s) - $(stat -f %m "$meeting_cache" 2>/dev/null || echo 0) )) -lt 60 ]; then
      needs_meeting_refresh=false
    fi
  fi
  if $needs_meeting_refresh; then
    (
      "$meeting_bin" >"${meeting_cache}.tmp" 2>/dev/null
      mv "${meeting_cache}.tmp" "$meeting_cache" 2>/dev/null
    ) &
  fi
fi

if [ -s "$meeting_cache" ]; then
  meeting_start=$(awk -F'\t' '{print $1; exit}' "$meeting_cache")
  meeting_end=$(awk -F'\t' '{print $2; exit}' "$meeting_cache")
  meeting_title=$(awk -F'\t' '{sub(/^[^\t]*\t[^\t]*\t/, ""); print; exit}' "$meeting_cache")
fi

# Colors (ANSI) — matched to ~/.oh-my-zsh/themes/emoji.zsh-theme
dir_color='\033[38;5;14m'       # %F{14} — bright cyan
vcs_paren='\033[1;34m'          # bold blue parens, like %{$fg_bold[blue]%}
vcs_ref_color='\033[38;5;219m'  # %F{219} — light pink branch name
pr_color='\033[1;32m'           # bold green
model_color='\033[1;34m'        # bold blue
ctx_color='\033[1;33m'          # bold yellow
cost_color='\033[38;5;208m'     # orange — session spend
tokens_color='\033[38;5;117m'   # sky blue — token count
meeting_color='\033[38;5;213m'  # pink — next meeting
dim='\033[2m'                   # dim — per-turn deltas
reset='\033[0m'

line=$(printf "${dir_color}%s${reset}" "$dir")

if [ -n "$vcs_ref" ]; then
  line="$line $(printf "${vcs_paren}(${vcs_ref_color}%s${vcs_paren})${reset}" "$vcs_ref")"
fi

if [ -n "$pr_ref" ]; then
  if [ -n "$pr_url" ] && [ -z "$TERMINAL_EMULATOR" ]; then
    # iTerm2/Kitty/WezTerm: OSC 8 hyperlink wraps the visible "PR #N" text.
    line="$line $(printf "${pr_color}\033]8;;%s\a%s\033]8;;\a${reset}" "$pr_url" "$pr_ref")"
  elif [ -n "$pr_url" ]; then
    # IntelliJ's terminal drops OSC 8 silently. Append the bare URL so its
    # built-in URL auto-detection makes it Ctrl/Cmd-clickable.
    line="$line $(printf "${pr_color}%s %s${reset}" "$pr_ref" "$pr_url")"
  else
    line="$line $(printf "${pr_color}%s${reset}" "$pr_ref")"
  fi
fi

# Line 2: session info — model, context %, cost, api/total durations.
line2=""
if [ -n "$model" ]; then
  line2="$line2$(printf "${model_color}%s${reset}" "$model")"
fi

if [ -n "$used" ]; then
  used_pct=$(echo "$used" | awk '{printf "%.0f", $1}')
  [ -n "$line2" ] && line2="$line2    "
  line2="$line2$(printf "${ctx_color}Context Used: %s%%${reset}" "$used_pct")"
fi

if [ -n "$cost" ]; then
  cost_fmt=$(echo "$cost" | awk '{printf "%.2f", $1}')
  [ -n "$line2" ] && line2="$line2    "
  line2="$line2$(printf "${cost_color}\$%s${reset}" "$cost_fmt")"
  if [ -n "$turn_cost" ]; then
    line2="$line2$(printf "${cost_color} (+\$%s)${reset}" "$turn_cost")"
  fi
fi

if [ -n "$tokens" ]; then
  tokens_fmt=$(awk -v t="$tokens" 'BEGIN {
    if (t < 1000)      printf "%d", t
    else if (t < 10000) printf "%.1fk", t/1000
    else if (t < 1000000) printf "%dk", t/1000
    else                printf "%.1fM", t/1000000
  }')
  [ -n "$line2" ] && line2="$line2    "
  line2="$line2$(printf "${tokens_color}Tokens: %s${reset}" "$tokens_fmt")"
  if [ -n "$turn_tokens" ]; then
    turn_tokens_fmt=$(awk -v t="$turn_tokens" 'BEGIN {
      if (t < 1000)      printf "%d", t
      else if (t < 10000) printf "%.1fk", t/1000
      else if (t < 1000000) printf "%dk", t/1000
      else                printf "%.1fM", t/1000000
    }')
    line2="$line2$(printf "${tokens_color} (+%s)${reset}" "$turn_tokens_fmt")"
  fi
fi

# Line 3: next meeting countdown (recomputed fresh each render).
line3=""
if [ -n "$meeting_start" ] && [ -n "$meeting_end" ] && [ -n "$meeting_title" ]; then
  now_epoch=$(date +%s)
  if [ "$meeting_start" -gt "$now_epoch" ]; then
    # Upcoming — "Title in Xm" / "Title in Xh Ym"
    delta=$(( meeting_start - now_epoch ))
    mins=$(( delta / 60 ))
    if [ "$mins" -lt 60 ]; then
      countdown="${mins}m"
    else
      countdown="$(( mins / 60 ))h $(( mins % 60 ))m"
    fi
    line3=$(printf "${meeting_color}%s in %s${reset}" "$meeting_title" "$countdown")
  elif [ "$meeting_end" -gt "$now_epoch" ]; then
    # In-progress — "Title now (Xm left)"
    left_mins=$(( (meeting_end - now_epoch) / 60 ))
    line3=$(printf "${meeting_color}%s now (%dm left)${reset}" "$meeting_title" "$left_mins")
  fi
  # else: meeting has ended, suppress
fi

printf "%b" "$line"
[ -n "$line2" ] && printf "\n%b" "$line2"
[ -n "$line3" ] && printf "\n%b" "$line3"
exit 0
