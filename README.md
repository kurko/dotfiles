# Dotfiles

Use these files in your bash to improve it.

**Important:** `git/gitconfig` has my nickname/email for Github. Please change
it.

### Setup

Just run

`source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/.dotfiles/master/install )"`

that's all. If it doesn't work, 

```
git clone git@github.com:kurko/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

### Update from Github

You can just run the same command

`source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/.dotfiles/master/install )"`

Or you can

```
cd ~/.dotfiles
git pull --rebase origin master
```

### Reloading

To reload dotfiles, run:

`$ ubp`

`ubp` will **U**pdate **B**ash **P**rofile with whatever is in the .dotfiles
dir.
