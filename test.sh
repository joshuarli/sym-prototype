#!/usr/bin/env bash

set -e
die () { >&2 printf %s\\n "$1"; exit 1; }

tmp="$(mktemp -d)" || die 'mktemp failed'
trap "rm -rf ${tmp}" EXIT

sym="${PWD}/sym"

# setup
cd "$tmp"
mkdir -p home expected-home dotfiles/bash dotfiles/mpv/.config/mpv
touch dotfiles/bash/.bashrc
touch dotfiles/mpv/.config/mpv/mpv.conf

nfailed=0

echo "1: pretend, no conflicts, link all"
$sym -p -t home dotfiles/* &> log
expected="Pretend mode is on; the following operations are what would have been executed.
LINK: ${tmp}/home/.bashrc -> ../dotfiles/bash/.bashrc
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
diff log <(echo "$expected") || nfailed=$((nfailed + 1))

echo "2: pretend, conflict with bash, link all"
touch home/.bashrc
$sym -p -t home dotfiles/* &> log
expected="CONFLICT: ${tmp}/home/.bashrc already exists. sym cannot create symlinks if there is an existing file.
Pretend mode is on; the following operations are what would have been executed.
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
diff log <(echo "$expected") || nfailed=$((nfailed + 1))
rm -r home; mkdir home

echo "3: nonexistent target directory"
$sym -p -t home/foo dotfiles/* &> log || true
expected="target directory home/foo is not a directory or does not exist"
diff log <(echo "$expected") || nfailed=$((nfailed + 1))

echo "4: no conflicts, link all"
cd expected-home
mkdir -p .config/mpv
ln -s ../dotfiles/bash/.bashrc .
cd .config/mpv
ln -s ../../../dotfiles/mpv/.config/mpv/mpv.conf .
cd ../../..
$sym -vt home dotfiles/* &> log
expected="LINK: ${tmp}/home/.bashrc -> ../dotfiles/bash/.bashrc
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
diff log <(echo "$expected") || nfailed=$((nfailed + 1))
diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home

echo "5: conflict with mpv, and 6: link all (noop)"
mkdir -p home/.config/mpv expected-home/.config/mpv
touch home/.config/mpv/mpv.conf expected-home/.config/mpv/mpv.conf
$sym -t home dotfiles/* &> log || true
expected="CONFLICT: ${tmp}/home/.config/mpv/mpv.conf already exists. sym cannot create symlinks if there is an existing file.
sym will not start until all conflicts are resolved."
diff log <(echo "$expected") || nfailed=$((nfailed + 1))
diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home

# echo "7: pretend, unlink all"

# echo "8: pretend, unlink only mpv, but is 'not owned' by sym (absolute symlink)"

# echo "9: unlink all"

# and more


echo 'testing finished.'
(( "$nfailed" > 0 )) && die "failed ${nfailed} assertions"
