# Arch Server Scripts

## Summary

A collection of scripts for managing an Arch Linux-based server, primarily
to aid in installing some more tedious to install services.

## Description

Nowadays, it is very common to run server applications through a bunch of
Docker containers. There are very few cases in which that would be a problem;
taking performance as an example, my Raspberry Pi 4 (8GB) can run multiple
contaienrs just fine. It is also recommended for security, as a hacker compromising
a container is already bad enough, but them taking control of the entire machine is
most definetly even worse.

That being said, this workflow isn't for everyone. Some administrators
may prefer to be able to manage their software using the same great tools they
use on their desktop, like `pacman` and the ABS + AUR. Or in some rare cases,
they may wish to really squeeze out the last bit of performance, and thus not
run their software in a container. There have also been instances of some things
working better on Arch Linux than on other distros (citation needed; I remember
having read about that on the r/archlinux subreddit).

## Usage

Note: A command block starting with `$` is intended to be run as a user, a line starting
with `#` is intended to be run as root (for example, using `sudo`).



### Dependencies

Some of these scripts depend on the AUR helper [`paru`][paru] being installed. If not already done,
please install it first by running `install-dependencies.sh` (requires `sudo` or `doas`).

Other dependencies should automatically be taken care of by their corrosponding install scripts.

## Legal

### License

This project is licensed under the terms of the Unlicense. You can find a copy in the `LICENSE.md` file
at the root of this repository, or alternatively at [unlicense.org][unlicense]. Note that this project uses the additional contribution disclaimer provided further down below on their website.

[paru]: https://github.com/Morganamilo/paru
[unlicense]: https://unlicense.org/