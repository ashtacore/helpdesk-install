#!/bin/bash
set -eu -o pipefail

usage="Usage (Linux / MacOS): bash <(curl -LsS https://raw.githubusercontent.com/ashtacore/helpdesk-install/master/templates/podman-monolithic/setup.sh)

Usage (Windows / Git Bash): winpty bash <(curl -LsS https://raw.githubusercontent.com/ashtacore/helpdesk-install/master/templates/podman-monolithic/setup.sh)

Options:
    -h,--help                  Display this help and exit.
"

while [[ "$#" -gt 0 ]]; do
  case $1 in
  -h|--help) echo "$usage" ; exit 0 ;;
  *)
    echo "Unknown parameter passed: $1"
    exit 1
    ;;
  esac
  # shellcheck disable=SC2317
  shift
done

os_type=
identify_os() {
  # Check for RHEL/CentOS, Fedora, etc.
  if command -v rpm >/dev/null && [[ -e /etc/redhat-release ]]; then
    os_type=rhel
  elif [[ -e /etc/os-release ]]; then
    . /etc/os-release
    # Is it Debian?
    case $ID in
    debian)
      os_type=debian ;;
    ubuntu)
      os_type=ubuntu ;;
    esac
  elif [[ "$(uname -s)" == Darwin ]]; then
    os_type=macos
  elif [[ "$(uname -s)" == MINGW* ]]; then
    os_type=windows
  fi

  if ! [[ $os_type ]]; then
    printf "error: unsupported operating system.\n"
    printf "\tFor a list of supported operating systems see https://docs.supportpal.com/current/System+Requirements#OperatingSystems\n"
    echo
    exit 1
  fi
}

# usage: check_command <bashrc__full_path>
check_command() {
  local _binary="$1" _full_path

  printf "checking for %s ... " "$_binary"

  # Checks if the binary is available.
  _full_path="$(command -v "$_binary")"
  _command_status="$?"
  if [ "$_command_status" -ne 0 ]; then
    printf "no\n"

    return 1
  else
    printf "found %s\n" "$_full_path"

    return 0
  fi
}

# usage: version_ge <installed_version> <minimum_version>
version_ge() {
  if ! [ "$(printf '%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; then
    printf "error: %s is less than minimum required version of %s\n" "$1" "$2"
    exit 1
  fi
}

check_winpty() {
  if ! check_command winpty; then
    printf "error: winpty is missing. Install Git Bash using the default options.\n"
    exit 1
  fi
}

configure_windows() {
  if [[ "$os_type" != "windows" ]]; then
    return
  fi

  check_winpty

  # winpty is required to run podman interactively (create a tty).
  path="${HOME}/.winpty/supportpal.sh"
  if [[ ! -e "${path}" ]]; then
    printf "registering winpty aliases ...\n"

    mkdir -p "$(dirname "${path}")"
    echo "alias podman='winpty podman'" >> "${path}"

    echo "[ -f ${path} ] && . ${path}" >> ~/.bashrc
    echo "[ -f ${path} ] && . ${path}" >> ~/.bash_profile
  fi

  # shellcheck disable=SC1090
  . "${path}"
}

check_podman() {
  if ! check_command podman; then
    printf "error: Install podman using the official installation instructions\n"
    exit 1
  fi

  local min="4.5.0" version

  set +e
  version="$(podman version -f "{{.Server.Version}}" 2>&1)"
  command_status="$?"
  set -e

  if [ $command_status -ne 0 ]; then
    echo "$version"

    if [[ "$version" == *"permission denied"* ]]; then
      echo
      echo "You may need to add your user to the podman group and then logout/login again for the change to take effect:"
      printf "\tsudo usermod -aG podman %s\n" "$USER"
      echo
      echo "Alternatively, consider starting your podman machine with root privelages podman machine set --rootful"
    fi
    exit 1
  fi

  printf "checking podman version %s >= %s ... " "$version" "$min"
  version_ge "$version" "$min"
  printf "✔\n"
}

check_podman_compose() {
  local min="1.0.6" version command_status

  set +e
  version="$(podman-compose version --short 2>&1)"
  command_status="$?"
  set -e

  if [ $command_status -ne 0 ]; then
    printf "error: Install podman-compose using the official installation instructions: https://github.com/containers/podman-compose\n"
    exit 1
  fi

  version="${version#v}"
  printf "checking podman-compose version %s >= %s ... " "$version" "$min"
  version_ge "$version" "$min"
  printf "✔\n"
}

escape_re() {
  IFS= read -d '' -r < <(sed -e ':a' -e '$!{N;ba' -e '}' -e 's/[&/\]/\\&/g; s/\n/\\&/g' <<<"$1")
  printf %s "${REPLY%$'\n'}"
}

create_volume() {
  printf "creating podman volume of name %s ... " "$1"
  # shellcheck disable=SC2034
  output="$(podman volume create "$1")"
  printf "✔\n"
}

configure() {
  # download docker-compose.yml example
  printf "generating docker-compose.yml ... "
  if [[ -f "docker-compose.yml" ]]; then
    echo
    echo "error: $(pwd)/docker-compose.yml already exists. Delete the file and try again."
    exit 1
  fi
  curl -fLsS https://raw.githubusercontent.com/ashtacore/helpdesk-install/master/templates/podman-monolithic/docker-compose.yml -o docker-compose.yml
  curl -fLsS https://raw.githubusercontent.com/ashtacore/helpdesk-install/master/templates/podman-monolithic/docker-compose.override.yml -o docker-compose.override.yml

  # guess the hostname
  hostname="$(hostname)"
  echo "DOMAIN_NAME=$(escape_re "${hostname// }")" > .env

  printf "✔\n"

  # create volumes
  bash <(curl -LsS https://raw.githubusercontent.com/ashtacore/helpdesk-install/master/templates/podman-monolithic/create_volumes.sh)
}

cat << "EOF"
 ____                               _   ____       _
/ ___| _   _ _ __  _ __   ___  _ __| |_|  _ \ __ _| |
\___ \| | | | '_ \| '_ \ / _ \| '__| __| |_) / _` | |
 ___) | |_| | |_) | |_) | (_) | |  | |_|  __/ (_| | |
|____/ \__,_| .__/| .__/ \___/|_|   \__|_|   \__,_|_|
            |_|   |_|
EOF

echo
identify_os
configure_windows
check_podman
check_podman_compose
configure

echo
echo "To complete the installation update the auto-generated $(pwd)/.env file."
echo "Refer back to https://docs.supportpal.com/current/Deploy+on+Docker for suggested changes."
echo
