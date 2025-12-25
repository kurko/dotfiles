# Devops: Basic machine

This is a set of scripts for installing new VPS accounts.

## Quick Start

**Fresh server (as root):**
```bash
USERNAME=myuser USER_PASSWORD=mypassword bash <(curl -s https://raw.githubusercontent.com/kurko/dotfiles/master/devops/basic/init.sh)
```

**Existing user (SSH'd as that user):**
```bash
bash <(curl -s https://raw.githubusercontent.com/kurko/dotfiles/master/devops/basic/init.sh)
```

## What it installs

- Creates user with sudo access (when running as root)
- vim, mosh, git, tmux, htop, build-essential
- Docker (Compose V2 bundled)
- rbenv + ruby-build
- Node.js 22.x LTS + Yarn (via corepack)

## Docker

Sample files (rename them to `Dockerfile`):

- [Dockerfile-rails](./Dockerfile-rails)

## systemd


Systemd configuration files (aka unit files), are typically located in one of
these directories:

- `/lib/systemd/system`: This directory contains system-provided unit files.
- `/etc/systemd/system`: This directory is for user-created unit files, which take precedence over system-provided unit files with the same name.

Try `sudo vim /etc/systemd/system/docker-service.service` and use the sample
file provided below (remember `sudo`):

- [Sample docker-service.service](./docker-service.service)

Once the file is modified, run

    sudo systemctl daemon-reload \
      && sudo systemctl start docker-service.service \
      && sudo systemctl enable docker-service.service

To start, stop, or check the status of the service:

    sudo systemctl start docker-service.service
    sudo systemctl stop docker-service.service
    sudo systemctl status docker-service.service
    sudo systemctl restart docker-service.service


Sources:

- https://gist.github.com/mosquito/b23e1c1e5723a7fd9e6568e5cf91180f


