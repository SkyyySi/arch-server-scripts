#!/usr/bin/env bash
__OLD_DIR="${__OLD_DIR:-$PWD}"
cd "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")"&>/dev/null&&pwd)" || exit 2

source 'src/include/install-deps.sh'

install-deps base-devel git

mkdir -p '/tmp/arch-install-scripts'
cd '/tmp/arch-install-scripts' || exit 2

git clone 'https://aur.archlinux.org/paru-bin'
cd 'paru-bin' || exit 2
makepkg -sifcr
cd .. || exit 2
rm -rf 'paru-bin'

cd "${__OLD_DIR}" || exit 2
