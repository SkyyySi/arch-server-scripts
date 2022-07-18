# Arch Server Scripts

## Summary

A collection of scripts for managing an Arch Linux-based server, primarily
to aid in installing some more tedious to install services.

## Description

TBA

## Usage

Note: A command block starting with `$` is intended to be run as a user, a line starting
with `#` is intended to be run as root (for example, using `sudo`).

### Dependencies

This program depends on the AUR helper [`paru`][1] being installed. If not already done,
please install it first by either running `install-dependencies.sh` (requires `sudo` or `doas`) or by manually installing it like this:

```
# pacman -Syu --needed base-devel git
$ git clone https://aur.archlinux.org/paru-bin
$ cd paru-bin
$ makepkg -sifcr
$ cd ..
$ rm -rf paru-bin
```

Other dependencies should automatically be taken care of by their corrosponding install scripts.

[1]: https://github.com/Morganamilo/paru
