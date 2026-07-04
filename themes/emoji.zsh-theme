# Preview all 256 color codes:
#   for i in {0..255}; do print -Pn "%K{$i}  %k%F{$i}${(l:3::0:)i}%f "; [[ $((i%16)) -eq 15 ]] && echo; done
# Can replace colors with %F{###}%f or %F{#XXXXXXX}%f for hex colors

PROMPT=" %(?:%{$fg[green]%}➜:%{$fg_bold[red]%}➜)"
PROMPT+=' %F{14}%c%f%{$reset_color%} $(git_prompt_info)'

# Right prompt: show the next meeting from the Claude Code statusline cache.
# Falls back to 🌸 when there's nothing upcoming. The cache is populated by
# ~/.config/claude-statusline/next_meeting (the EventKit binary).
_emoji_theme_rprompt() {
  local cache="$HOME/.cache/claude-statusline/next_meeting"
  if [[ ! -s "$cache" ]]; then
    print -n "🌸"
    return
  fi

  local start end title
  IFS=$'\t' read -r start end title < "$cache"
  if [[ -z "$start" || -z "$end" || -z "$title" ]]; then
    print -n "🌸"
    return
  fi

  local now mins left
  now=$(date +%s)

  if (( start > now )); then
    mins=$(( (start - now) / 60 ))
    if (( mins < 60 )); then
      print -n "📅  %F{213}${title} in ${mins}m%f"
    else
      print -n "📅  %F{213}${title} in $(( mins / 60 ))h $(( mins % 60 ))m%f"
    fi
  elif (( end > now )); then
    left=$(( (end - now) / 60 ))
    print -n "📅  %F{213}${title} now (${left}m left)%f"
  else
    print -n "🌸"
  fi
}

RPROMPT='$(_emoji_theme_rprompt)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}(%F{219}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%f%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[blue]%}) %{$fg[yellow]%}✏️ "
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[blue]%}) ✅"
