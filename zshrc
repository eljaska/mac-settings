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

# Start kata with every jj-managed repo under ~/Developer/*/* as a
# workspace. Pulls the kata repo first and rebuilds/reinstalls if
# HEAD moved.
kk() {
  local kata_repo="$HOME/Developer/devtools/kata"
  local needs_build=false

  if [[ -d "$kata_repo/.git" ]]; then
    local before after
    before=$(git -C "$kata_repo" rev-parse HEAD 2>/dev/null)
    echo "kk: pulling $kata_repo..."
    if ! git -C "$kata_repo" pull --ff-only; then
      echo "kk: git pull failed; continuing with existing binary" >&2
    else
      after=$(git -C "$kata_repo" rev-parse HEAD 2>/dev/null)
      [[ -n "$before" && "$before" != "$after" ]] && {
        echo "kk: HEAD $before -> $after"
        needs_build=true
      }
    fi
  else
    echo "kk: $kata_repo is not a git repo; skipping self-update" >&2
  fi

  # Also build when the binary isn't there yet — first run after a
  # fresh clone or a ~/.cargo/bin cleanup.
  if ! command -v kata >/dev/null 2>&1; then
    echo "kk: kata binary missing"
    needs_build=true
  fi

  if $needs_build; then
    echo "kk: (re)building kata..."
    if ! cargo install --path "$kata_repo/crates/kata_server" --force; then
      echo "kk: cargo install failed; aborting" >&2
      return 1
    fi
  else
    echo "kk: already up to date"
  fi

  local dev_dir="$HOME/Developer"
  local workspaces=()
  local d name
  setopt local_options nullglob
  for d in "$dev_dir"/*/*/; do
    [[ -d "${d}.jj" ]] || continue
    name="${${d%/}##*/}"
    # Skip maudebox-created variants
    [[ "$name" == *.* ]] && continue
    workspaces+=(--workspace "${name}=${d%/}")
  done

  if (( ${#workspaces[@]} == 0 )); then
    echo "No jj repos found under $dev_dir"
    return 1
  fi

  kata serve \
    "${workspaces[@]}" \
    --data ~/.local/share/kata \
    --author "Ender Jaska <eljaska@gmail.com>" \
    --bind 127.0.0.1:7878
}

# Build and launch jjuicy (a GUI for jj). Pulls the jjuicy repo
# first and rebuilds/reinstalls if HEAD moved. Returns once the
# app is spawned — the Tauri process lives on its own after that.
jjuicy() {
  local jjuicy_repo="$HOME/Developer/devtools/jjuicy"
  local ju_bin="$HOME/.cargo/bin/ju"
  local ju_app="/Applications/jjuicy.app"
  local needs_build=false

  if [[ -d "$jjuicy_repo/.git" ]]; then
    local before after
    before=$(git -C "$jjuicy_repo" rev-parse HEAD 2>/dev/null)
    echo "jjuicy: pulling $jjuicy_repo..."
    if ! git -C "$jjuicy_repo" pull --ff-only; then
      echo "jjuicy: git pull failed; continuing with existing binary" >&2
    else
      after=$(git -C "$jjuicy_repo" rev-parse HEAD 2>/dev/null)
      [[ -n "$before" && "$before" != "$after" ]] && {
        echo "jjuicy: HEAD $before -> $after"
        needs_build=true
      }
    fi
  else
    echo "jjuicy: $jjuicy_repo is not a git repo; skipping self-update" >&2
  fi

  # Also build when either artifact is missing — first run after a
  # fresh clone, /Applications wipe, or ~/.cargo/bin cleanup.
  if [[ ! -x "$ju_bin" || ! -d "$ju_app" ]]; then
    echo "jjuicy: ju binary or /Applications/jjuicy.app missing"
    needs_build=true
  fi

  if $needs_build; then
    echo "jjuicy: (re)building..."
    # cargo tauri build produces both target/release/ju AND the .app
    # bundle in one compile — Tauri.toml's beforeBuildCommand handles
    # `npm run build` for us. The tauri CLI ships as a devDependency,
    # so npx picks it up after npm install.
    (
      cd "$jjuicy_repo" || exit 1
      npm install --silent && \
      npx tauri build && \
      mkdir -p "$HOME/.cargo/bin" && \
      install -m 755 target/release/ju "$ju_bin" && \
      ditto target/release/bundle/macos/jjuicy.app "$ju_app"
    ) || {
      echo "jjuicy: rebuild failed; aborting" >&2
      return 1
    }
  else
    echo "jjuicy: already up to date"
  fi

  nohup ju gui >/dev/null 2>&1 &
  disown
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

# Sync each fork under ~/Developer/devtools with its upstream by
# pushing upstream/<default-branch> straight to origin. Uses raw git
# (no gh API call) so it survives forks whose upstream lives in a
# SAML-protected org the local `gh` token isn't authorized for.
sync_devtools() {
  local base="$HOME/Developer/devtools"
  [ -d "$base" ] || return 0
  setopt local_options nullglob
  local dir
  for dir in "$base"/*/; do
    [ -d "$dir/.git" ] || continue
    echo "==> Syncing $(basename "$dir")..."
    (
      cd "$dir" || exit 1
      git remote get-url upstream >/dev/null 2>&1 || {
        echo "    no upstream remote; skipping"
        exit 0
      }
      local branch
      branch=$(git ls-remote --symref origin HEAD 2>/dev/null \
        | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2; exit}')
      [ -n "$branch" ] || {
        echo "    cannot determine default branch; skipping"
        exit 0
      }
      git fetch upstream --quiet
      if ! git push --quiet origin "upstream/$branch:$branch"; then
        echo "    push failed (fork may have diverged from upstream)"
      fi
      [ -d .jj ] && jj git fetch --all-remotes
    )
  done
}

login() {
  ZSH="$ZSH" command zsh -f "$ZSH/tools/upgrade.sh" -i -v default
  brew upgrade
  sync_devtools

  # Spin off a new iTerm window that builds+launches jjuicy in the
  # background, then runs kata in the foreground. Keeps the current
  # shell free for interactive work.
  osascript <<'AS'
tell application "iTerm"
    create window with default profile
    tell current session of current window
        write text "jjuicy && kk"
    end tell
end tell
AS
}

test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"
