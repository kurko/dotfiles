#!/bin/bash

function docker_prune_dangling_images() {
  echo 'Running: docker rmi $(docker images -f "dangling=true" -q)'
  docker rmi $(docker images -f "dangling=true" -q)
}

function docker_image_archs() {
  for i in `docker ps --format "{{.Image}}"`
  do
    docker image inspect $i --format "$i -> {{.Architecture}} : {{.Os}}"
  done
}
