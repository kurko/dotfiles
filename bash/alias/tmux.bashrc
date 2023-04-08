source "$DOTFILES/bash/alias/bash.bashrc"

# Tmux
#
function tmuxa(){

  # If there's a tmux session, attach to it, otherwise restore from tmux-ressurect
  pgrep -x "tmux" > /dev/null

  if [ ! $? -eq 0 ]; then
    echo "Restoring Tmux..."
    tmux new -d -s delete-me && \
      tmux run-shell ~/.tmux/plugins/tmux-resurrect/scripts/restore.sh && \
      tmux kill-session -t delete-me
  fi

  if [ $# -eq 0 ]; then
    tmux attach
  else
    tmux attach -t $*
  fi
}


function tmuxn(){
  tmux has-session -t $1 >/dev/null 2>&1

  if [ $? != 0 ]; then
    tmux new-session -d -s $1
    tmux neww -t $1
    tmux neww -t $1

    # Rails project?
    if file-exists "Gemfile" && file-exists "config.ru" ; then
      tmux neww -t $1
    fi
  fi

  tmux attach -t $1
  #tmux set -g automatic-rename "on" 1>/dev/null
}
function tmuxn3(){
  tmux new-session -d -s $1
  tmux neww -t $1
  tmux neww -t $1
  tmux attach -t $1
  #tmux set -g automatic-rename "on" 1>/dev/null
}
function tmuxk(){ tmux kill-session -t $*; }

function tmux-dir(){
  echo "run -> :attach-session -t . -c $1"
}

# These functions are only available within a Tmux session
if [[ "$TERM" =~ "screen".* ]]; then
  # We are in TMUX!

  # https://gist.github.com/javipolo/62eb953f817a9a2f63b8127ff5f60788
  #
  # Given a command ending with a URL, return everything until it. For instance,
  # alex@subdomain.domain.com becomes alex@subdomain.domain. When it is an IP
  # address don't remove dots.
  function __tmux_get_hostname(){
    local HOST="$(echo $* | rev | cut -d ' ' -f 1 | rev)"

    # The host is an IP address, then use it.
    if echo $HOST | grep -e "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}" -q; then
      echo $HOST
    else
      echo $HOST | cut -d . -f 1,2
    fi
  }

  # Used for commands that will show a hostname in the window status bar, like
  #
  #   ssh user@domain.com
  #
  # It will rename window according to __tmux_get_hostname and then restore it
  # afterwards.
  function __tmux_command_with_host() {
    echo "$@ within tmux"
    __tmux_window=$(tmux list-windows | awk -F : '/\(active\)$/{print $1}')
    # Use current window to change back the setting. If not it will be
    # applied to the active window
    #trap "tmux set-window-option -t $__tmux_window automatic-rename on 1>/dev/null; tmux setw automatic-rename" RETURN
    tmux rename-window "$(__tmux_get_hostname $*)"
    command "$@"
    # This is not working on Ubuntu
    # tmux set-window-option automatic-rename "on" 1>/dev/null
    tmux setw automatic-rename
  }

  # The following functions will override existing commands to show additional
  # information in the status bar.
  function ssh() {
    __tmux_command_with_host ssh "$@"
  }
  function mosh() {
    __tmux_command_with_host mosh "$@"
  }
fi
