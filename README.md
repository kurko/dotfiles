# Dotfiles

Use these files in your bash to improve it.

**Important:** `git/gitconfig` has my nickname/email for Github. Please change
it.

## Installation (new computer)

A fresh macOS install runs zsh and has no `git` or compiler, while these
dotfiles are bash-based and Homebrew needs a compiler. Run the steps below
**in order**; everything after step 2 is a single copy-paste.

### 1. Switch your shell to bash

These dotfiles are bash-based, and the installer is a bash script sourced into
your current shell, so it needs to run under bash. Switch your login shell, then
**open a new terminal window** so the remaining steps run in bash:

    chsh -s /bin/bash

### 2. Install the Xcode Command Line Tools

This provides `git` (needed to clone the repo) and the compiler toolchain (a
prerequisite for Homebrew):

    xcode-select --install

Wait for the GUI installer to finish before moving on.

### 3. Run the installer

    source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/dotfiles/master/install )"

That one command does everything else:

* **installs Homebrew** if it isn't already present
* clones this repo to `~/.dotfiles`
* sets up symlinks for `gitconfig`, `tmux`, bash aliases, Alacritty config, and more
* installs all software via Homebrew (`rbenv`, `vim`, `ctags`, `1password`,
  `slack`, `google chrome`, ...)
* generates an SSH key at `~/.ssh/id_rsa.pub` if you don't have one

The installer is idempotent, so you can re-run this command any time to fix or
finish a partial install. A post-install checklist prints the few manual steps
that remain, including uploading your SSH key to GitHub (App Store apps, etc.).
It also installs 1Password; download it manually if that step fails.

### Running the installer manually

If you'd rather clone and run it directly (which is what the command above
does under the hood):

```
git clone git@github.com:kurko/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install
```

### Update from Github

You can just run the same command

`source /dev/stdin <<<"$( curl -sS https://raw.githubusercontent.com/kurko/dotfiles/master/install )"`

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

