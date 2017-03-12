#!/bin/bash
#
# Inspiration by Matt Campbell.

# kub = kube
#
# Type `kube` in the terminal to get the options you have.
function kube() {
  KUBE_CONFIG_PATH="$HOME/.kube/config"
  if [[ ! -f "$KUBE_CONFIG_PATH" ]]; then
    printf "Error: $KUBE_CONFIG_PATH doesn't exist."
    return 1
  fi

  if [[ $1 == "podname" ]]; then
    echo `kube-podname`
  elif [[ $1 == "ssh" ]]; then
    kube-ssh
  elif [[ $1 == "services" ]]; then
    kube-services
  else
    printf "Usage: kube <command> [options]\n"
    printf "\n"
    printf "Commands:\n"
    printf "podname\t\tReturns the name of the remote pod corresponding to the\n"
    printf "\t\tapp in the current directory.\n"
    printf "ssh \t\tSSH into the current app.\n"
    printf "services\tLists all services available.\n"
  fi
}

# kube-podname
#
# This script inspects the present working directoy (`pwd`) and uses the
# current repository's name to return the first running kubernetes pod
# which matches the name of the repository.
#
# e.g. You are working in $HOME/my-app-api
# Running `kube-podname` should return something like `my-app-api-12345678-xyz`
function kube-podname() {
  # /foo/my-app-api becomes /foo/my-app
  NAME=$(pwd | sed 's/-api//g')

  # select string contents after the final /
  SERVICE_NAME=${NAME##*/}

  echo `kubectl get pods | grep $SERVICE_NAME | awk '{print $1}' | head -1`
}

# kube-ssh
#
# This will SSH into the pod.
function kube-ssh() {
  echo 'Running: kubectl exec -it `kube-podname` /bin/bash'
  kubectl exec -it `kube-podname` /bin/bash
}

function kube-services() {
  echo 'Running: kubectl get services'
  kubectl get services
}

function kube-port-forward() {
  echo 'kubectl port-forward `kube-podname` 3000:3000'
  kubectl port-forward `kube-podname` 3000:3000
}
