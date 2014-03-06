### Dotfiles

Use these files in your bash to improve it.

Start by cloning this repo into `~/.dotfiles`. Then add this to your
`~/.bashrc` (or `~/.bash_profile` if you're in a Mac):

`if [ -f ~/.bashrc ]; then
  source ~/.dotfiles/bashrc
else
  source ~/.dotfiles/bash_profile
fi`

Edit gitconfig file at `~/.dotfiles/git/` with your name and email

Add the ir_black theme in your `~/.vim/colors/` directory
Install ctags package: `sudo apt-get install exuberant-ctags`

Now run the loading commands:
`$ source ~/.bashrc` (or `$ source ~/.bash_profile` if you're in a Mac, punk)
`$ ubp`

`ubp` will **U**pdate **B**ash **P**rofile with whatever is in the .dotfiles
dir (we hope so).
