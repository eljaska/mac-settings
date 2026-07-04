# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$HOME/go/bin:$PATH"

# Path to your Oh My Zsh installation.
export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="emoji"

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  you-should-use
  zsh-bat
  nvm
  zsh-nvm
)

source $ZSH/oh-my-zsh.sh

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='micro'
else
  export EDITOR='code --wait'
fi

alias dev='cd ~/Developer'

cc() {
  FORCE_HYPERLINK=1 claude --model 'claude-opus-4-7[1m]'
}

xx() {
  # Pairs of (label, command). Regular array preserves order, unlike an
  # associative array.
  local entries=(
    "Launch Claude Code"  "cc"
  )

  local labels=()
  local i
  for (( i=1; i<=${#entries}; i+=2 )); do
    labels+=("${entries[i]}")
  done

  local selection
  selection=$(printf '%s\n' "${labels[@]}" | fzf \
    --prompt="xx> " \
    --height=~50% \
    --layout=reverse \
    --border=rounded \
    --header="Select a command to run (type to filter)" \
    --preview='echo "→ {}"' \
    --preview-window=up:1 \
    --select-1 \
    ${1:+--query="$*"})

  if [[ -z "$selection" ]]; then
    return
  fi

  for (( i=1; i<=${#entries}; i+=2 )); do
    if [[ "${entries[i]}" == "$selection" ]]; then
      local cmd="${entries[i+1]}"
      echo "\n\033[1;34m▶ $cmd\033[0m\n"
      eval "$cmd"
      return
    fi
  done
}

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
