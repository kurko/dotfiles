#!/bin/bash

function docker_prune_dangling_images() {
  echo 'Running: docker rmi $(docker images -f "dangling=true" -q)'
  docker rmi $(docker images -f "dangling=true" -q)
}
