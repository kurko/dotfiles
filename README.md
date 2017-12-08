# Dotfiles

Use these files in your bash to improve it.

### Setup

Just run

`source <(curl -s https://raw.githubusercontent.com/kurko/.dotfiles/master/install)`

that's all.

### Update from Github

You can just run the same command

`source <(curl -s https://raw.githubusercontent.com/kurko/.dotfiles/master/install)`

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
