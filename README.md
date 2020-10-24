# Dotfiles

Use these files in your bash to improve it.

**Important:** `git/gitconfig` has my nickname/email for Github. Please change
it.

If you're setting a new computer, ![here's how to setup](#setup-id-rsa) `~/.ssh/id_rsa.pub`.

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

<a href="#setup-id-rsa"></a>
### Setup `id_rsa` for Github

Run:

    ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
    cat ~/.ssh/id_rsa.pub

Then head to https://github.com/settings/keys/new.
