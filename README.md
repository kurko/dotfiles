# Dotfiles

Use these files in your bash to improve it.

**Important:** `git/gitconfig` has my nickname/email for Github. Please change
it.




### New Computer Checklist

1. Download [1Password](https://1password.com/downloads/mac/)
1. **On MacOS:** run `chsh -s /bin/bash` to replace ZSH with Bash.
1. [Setup RSA key](#setup-id_rsa-for-github) `~/.ssh/id_rsa.pub` and upload to Github.
1. Run `source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/.dotfiles/master/install )"`

### More details

You can run the follow command and it will show up errors that you can adjust, one by one

    source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/.dotfiles/master/install )"

If it doesn't work, you can clone the files and use it directly (which is mostly what the command
above does):

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

<a href="#setup-id-rsa"></a>
### Setup `id_rsa` for Github

Run:

    ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
    cat ~/.ssh/id_rsa.pub

Then head to https://github.com/settings/keys/new.

