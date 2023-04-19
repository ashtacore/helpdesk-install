#!/bin/bash
set -eu -o pipefail

create_volume() {
  printf "creating podman volume of name %s ... " "$1"
  # shellcheck disable=SC2034
  output="$(podman volume create "$1")"
  printf "✔\n"
}

create_volume supportpal_db
create_volume supportpal_config
create_volume supportpal_redis
create_volume supportpal_storage
create_volume supportpal_logs
create_volume supportpal_addons
create_volume supportpal_caddy
