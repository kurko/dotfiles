#!/bin/bash
#
# This installs the basic building blocks for a new server with the intention of
# hosting apps later (e.g Docker with Rails).
#
# Usage:
#
#   # As root (creates user):
#   USERNAME=myuser USER_PASSWORD=secret bash <(curl -s https://raw.githubusercontent.com/kurko/dotfiles/master/devops/basic/init.sh)
#
#   # As existing user (with sudo):
#   curl -s https://raw.githubusercontent.com/kurko/dotfiles/master/devops/basic/init.sh | sudo bash
#
# This script:
#
# - Creates user (if running as root)
# - Installs: vim mosh build-essential software-properties-common curl wget git tmux htop
# - Installs Docker (Compose V2 is bundled)
# - Installs Ruby (rbenv), Node.js 22.x LTS, and Yarn (via corepack)

set -e

# Determine target user based on who's running the script
if [ "$(id -u)" -eq 0 ]; then
  # Running as root
  if [ -n "$USERNAME" ]; then
    # Explicit USERNAME provided
    TARGET_USER="$USERNAME"
  elif [ -n "$SUDO_USER" ]; then
    # Running via sudo - use the original user
    TARGET_USER="$SUDO_USER"
  else
    # Running as root directly without USERNAME
    echo "Error: USERNAME is required when running as root."
    echo ""
    echo "Usage:"
    echo "  USERNAME=myuser USER_PASSWORD=secret bash <(curl -s https://raw.githubusercontent.com/kurko/dotfiles/master/devops/basic/init.sh)"
    echo ""
    echo "If the user already exists, USER_PASSWORD can be omitted."
    exit 1
  fi
else
  # Running as non-root - use current user
  TARGET_USER="$(whoami)"
fi

TARGET_HOME="/home/$TARGET_USER"

echo "==> Setting up server for user: $TARGET_USER"

# Create user if needed (only when running as root and user doesn't exist)
if [ "$(id -u)" -eq 0 ]; then
  if ! id -u "$TARGET_USER" > /dev/null 2>&1; then
    if [ -z "$USER_PASSWORD" ]; then
      echo "Error: User '$TARGET_USER' does not exist. USER_PASSWORD is required to create them."
      echo ""
      echo "Usage:"
      echo "  USERNAME=$TARGET_USER USER_PASSWORD=secret bash <(curl -s ...)"
      exit 1
    fi

    echo "==> Creating user: $TARGET_USER"
    adduser "$TARGET_USER" --gecos ",,," --disabled-password
    echo "$TARGET_USER:$USER_PASSWORD" | chpasswd

    # Set up SSH directory and copy root's authorized_keys
    mkdir -p "$TARGET_HOME/.ssh"
    if [ -f /root/.ssh/authorized_keys ]; then
      cp /root/.ssh/authorized_keys "$TARGET_HOME/.ssh/authorized_keys"
      echo "==> Copied SSH keys from root to $TARGET_USER"
    else
      touch "$TARGET_HOME/.ssh/authorized_keys"
    fi
    chmod 700 "$TARGET_HOME/.ssh"
    chmod 600 "$TARGET_HOME/.ssh/authorized_keys"
    chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME/.ssh"
  else
    echo "==> User '$TARGET_USER' already exists. Skipping creation."
  fi

  # Add user to sudo group
  usermod -aG sudo "$TARGET_USER"
fi

# Update package lists and upgrade the system
echo "==> Updating system packages"
apt-get update -y && apt-get upgrade -y

# Install basic software
echo "==> Installing basic tools"
apt-get install -y \
  vim mosh build-essential software-properties-common curl wget git tmux htop

# Install Docker
if ! command -v docker &> /dev/null; then
  echo "==> Installing Docker"
  curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
  sh /tmp/get-docker.sh
  rm /tmp/get-docker.sh
else
  echo "==> Docker already installed. Skipping."
fi

# Add user to docker group
usermod -aG docker "$TARGET_USER"

# Note: Docker Compose V2 is bundled with Docker (use `docker compose`)

# Install Rbenv and Ruby-build
echo "==> Installing rbenv and ruby-build"
apt-get install -y rbenv ruby-build

# Configure rbenv in user's bashrc
if ! grep -q 'export PATH="$HOME/.rbenv/bin:$PATH"' "$TARGET_HOME/.bashrc"; then
  echo "==> Configuring rbenv in $TARGET_HOME/.bashrc"
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> "$TARGET_HOME/.bashrc"
  echo 'eval "$(rbenv init -)"' >> "$TARGET_HOME/.bashrc"
fi

# Install Node.js LTS
echo "==> Installing Node.js 22.x LTS"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Enable Yarn via corepack
echo "==> Enabling Yarn via corepack"
corepack enable

# Clean up
apt-get autoremove -y && apt-get clean

echo ""
echo "==> Setup complete!"
echo ""
if [ "$(id -u)" -eq 0 ]; then
  echo "SSH in as '$TARGET_USER' to start using the server:"
  echo "  ssh $TARGET_USER@<server-ip>"
else
  echo "Run 'source ~/.bashrc' or start a new shell to activate rbenv."
fi
