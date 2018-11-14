# Tmux
#
# execute_in_all_panes "echo OH HAI"
function tmuxa(){
  tmux attach -t $*
}
function tmuxn(){
  tmux new-session -d -s $1
  tmux neww -t $1
  tmux neww -t $1 -n vim
  tmux neww -t $1
  tmux neww -t $1
  tmux neww -t $1
  tmux neww -t $1
  tmux neww -t $1

echo 1
  if [[ -f "Gemfile" ]]; then
    tmux neww -t $1 -n zeus
  else
    tmux neww -t $1
  fi

echo 1
  #tmux send-keys -t$1:1 "ls" C-m
  ## If it's a git folder, start by running `git status`
  #if [[ -d ".git" ]]; then
  #  tmux send-keys -t$1:1 "git status" C-m
  #fi
echo 1
  #tmux select-window -t$1:1
echo 1
  tmux attach -t $1
}
function tmuxk(){ tmux kill-session -t $*; }

