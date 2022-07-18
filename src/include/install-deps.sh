#!/usr/bin/env bash
# This file is not intended to be executed directly.
__OLD_DIR="${__OLD_DIR:-$PWD}"
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&>/dev/null&&pwd)" || exit 2

source 'elevate.sh'

install-deps() {
	elevate pacman -Syu --needed "$@"
}

cd "${__OLD_DIR}" || exit 2
