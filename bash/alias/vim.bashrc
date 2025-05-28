alias vim_install_plugins='vim +PluginInstall +qall'
alias vim_install_vundle="git clone https://github.com/VundleVim/Vundle.vim.git ~/.vim/bundle/Vundle.vim && vim +PluginInstall +qall"

alias v="nvim"
alias vf="nvimf"

function nvimf() {
  nvim $(fzf)
}

function vimf() {
  vim $(fzf)
}
