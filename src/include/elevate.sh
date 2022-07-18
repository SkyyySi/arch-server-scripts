#!/usr/bin/env bash
# This file is not intended to be executed directly.
__OLD_DIR="${__OLD_DIR:-$PWD}"
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&>/dev/null&&pwd)" || exit 2

if command -v sudo &> '/dev/null'; then
	elevate() {
		sudo "$@"
	}
elif command -v doas &> '/dev/null'; then
	elevate() {
		doas "$@"
	}
fi

cd "${__OLD_DIR}" || exit 2
