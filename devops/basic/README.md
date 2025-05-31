# Devops: Basic machine

This is a set of scripts for installing new VPS accounts.

## Init machine

This script will run basic installations of vim, mosh, git, add a devops user,
install Ruby, node and more.

- [init.sh](./init.sh)

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


