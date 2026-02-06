function ssh_homepi() {
  if [[ -z "$SERVER_USER" ]]; then
    echo "Please set \$SERVER_USER"
    return 1
  fi
  if [[ -z "$PERSONAL_DOMAIN" ]]; then
    echo "Please set \$PERSONAL_DOMAIN"
    return 1
  fi
  ssh $SERVER_USER@homepi.$PERSONAL_DOMAIN
}

function mosh_homepi() {
  if [[ -z "$SERVER_USER" ]]; then
    echo "Please set \$SERVER_USER"
    return 1
  fi
  if [[ -z "$PERSONAL_DOMAIN" ]]; then
    echo "Please set \$PERSONAL_DOMAIN"
    return 1
  fi
  mosh $SERVER_USER@homepi.$PERSONAL_DOMAIN
}

alias clean_tmp="sudo find /tmp -type f -atime +10 -delete"
