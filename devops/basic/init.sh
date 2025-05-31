#!/bin/bash
#
# This installs the basic building blocks for a new server with the intention of
# hosting apps later (e.g Docker with Rails).
#
# Usage:
#
#   bash <(curl -s https://raw.githubusercontent.com/kurko/devops/master/devops/basic/init.sh)
#
# This script:
#
# - Installs:
#   - vim mosh build-essential software-properties-common curl wget git tmux
#     htop
# - Installs Docker and Compose
# - Installs Ruby, adds rbenv to path
# - Installs Node.js and Yarn

# Update package lists and upgrade the system
sudo apt-get update -y && sudo apt-get upgrade -y

# Install basic software
#
# mosh: replaces ssh (e.g mosh user@ip) to make the connection feel way faster
sudo apt-get install -y \
  vim mosh build-essential software-properties-common curl wget git tmux htop

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
else
    echo "Docker is already installed. Skipping installation."
fi

# Add $USERNAME to the Docker group
sudo usermod -aG docker `whoami`

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Rbenv and Ruby-build for managing Ruby versions
sudo apt-get install -y rbenv ruby-build

# Check if rbenv is already in PATH
if ! grep -q 'export PATH="$HOME/.rbenv/bin:$PATH"' ~/.bashrc; then
    echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
    echo 'eval "$(rbenv init -)"' >> ~/.bashrc
    source ~/.bashrc
fi

# Install Node.js for the Rails asset pipeline
curl -sL https://deb.nodesource.com/setup_14.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Yarn for managing JavaScript packages
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get update && sudo apt-get install yarn

# Clean up
sudo apt-get autoremove -y && sudo apt-get clean

echo "Setup complete. Please reboot the system using 'sudo reboot'."
