alias glg="git lg"

alias gco="git checkout"
alias gcm="git commit -m"
alias gott="gotestsum"
alias lg="lazygit"



cc() {
  local safe_pwd="${PWD//[^[:alnum:]]/_}"
  local session="${safe_pwd}-${1:-claude}"

  if tmux has-session -t "$session" 2>/dev/null; then
    tmux attach -t "$session"
  else
    newTmux "$session" "$PWD" "zsh -ic 'claude; exec zsh'" && \
    tmux attach -t "$session"
  fi
}

newTmux() {
  local session="$1"
  local dir="${2:-$PWD}"
  shift 2
  tmux new-session -d -s "$session" -c "$dir" -P -F '#{pane_id}' "$@"
}

nmcp() {
  local name="gitnexusMCP"
  if tmux has-session -t "$name" 2>/dev/null; then
    tmux kill-session -t "$name"
  fi
  tmux new-session -d -s "$name" -c "$PWD" "zsh -ic 'gitnexus mcp'" 
  echo "gitnexus mcp start"

}
