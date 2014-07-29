export DOTFILES=~/.dotfiles
source $DOTFILES/bash/prompt_config
source $DOTFILES/bash/config
source $DOTFILES/bash/env
source $DOTFILES/bash/aliases
source $DOTFILES/bash/aliases_env_specific
source $DOTFILES/bash/bootstrap_machine

# This is neat
source $DOTFILES/bash/dirmarks

export PATH=$PATH:~/.dotfiles/bin
