#!/usr/bin/env bash

set -e
die () { >&2 printf %s\\n "$1"; exit 1; }

tmp="$(mktemp -d)" || die 'mktemp failed'
trap "rm -rf ${tmp}" EXIT

sym="${PWD}/sym"

# setup for all tests
cd "$tmp"
mkdir -p home expected-home dotfiles/bash dotfiles/mpv/.config/mpv
touch dotfiles/bash/.bashrc
touch dotfiles/mpv/.config/mpv/mpv.conf

nfailed=0
echo "running tests."

echo -e "\n1: pretend, no conflicts, link all"
# end setup
$sym -t home -p dotfiles/* &> log
expected="Pretend mode is on; the following operations are what would have been executed.
LINK: ${tmp}/home/.bashrc -> ../dotfiles/bash/.bashrc
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))


echo -e "\n2: pretend, conflict with bash, link all"
touch home/.bashrc
# end setup
$sym -t home -p dotfiles/* &> log
expected="CONFLICT: ${tmp}/home/.bashrc already exists. sym cannot create symlinks if there is an existing file.
Pretend mode is on; the following operations are what would have been executed.
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
rm -r home; mkdir home


echo -e "\n3: nonexistent target directory"
# end setup
$sym -t home/foo -p dotfiles/* &> log || true
echo "  assertion 1: expected output"; expected="target directory home/foo is not a directory or does not exist"
diff log <(echo "$expected") || nfailed=$((nfailed + 1))


echo -e "\n4: no conflicts, link all"
cd expected-home
mkdir -p .config/mpv
ln -s ../dotfiles/bash/.bashrc .
cd .config/mpv
ln -s ../../../dotfiles/mpv/.config/mpv/mpv.conf .
cd ../../..
# end setup
$sym -t home -v dotfiles/* &> log
expected="LINK: ${tmp}/home/.bashrc -> ../dotfiles/bash/.bashrc
MKDIRS: ${tmp}/home/.config/mpv
LINK: ${tmp}/home/.config/mpv/mpv.conf -> ../../../dotfiles/mpv/.config/mpv/mpv.conf"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
echo "  assertion 2: expected result"; diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home


echo -e "\n5: conflict with mpv (link all should be noop)"
mkdir -p home/.config/mpv expected-home/.config/mpv
touch home/.config/mpv/mpv.conf expected-home/.config/mpv/mpv.conf
# end setup
$sym -t home dotfiles/* &> log || true
expected="CONFLICT: ${tmp}/home/.config/mpv/mpv.conf already exists. sym cannot create symlinks if there is an existing file.
sym will not start until all conflicts are resolved."
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
echo "  assertion 2: expected result"; diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home


echo -e "\n6: pretend, unlink all"
$sym -t home dotfiles/* > /dev/null
# end setup
$sym -t home -p -d dotfiles/* &> log
expected="Pretend mode is on; the following operations are what would have been executed.
UNLINK: ${tmp}/home/.bashrc
UNLINK: ${tmp}/home/.config/mpv/mpv.conf"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
rm -r home; mkdir home


echo -e "\n7: pretend, unlink only mpv, but is 'not owned' by sym (absolute symlink to same path)"
$sym -t home dotfiles/* > /dev/null
ln -sf "$(readlink -f home/.config/mpv/mpv.conf)" home/.config/mpv/mpv.conf
# end setup
$sym -t home -p -d dotfiles/* &> log
expected="CONFLICT: ${tmp}/home/.config/mpv/mpv.conf is an absolute symlink. sym only creates relative symlinks, so refusing to remove.
Pretend mode is on; the following operations are what would have been executed.
UNLINK: ${tmp}/home/.bashrc"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
rm -r home; mkdir home


echo -e "\n8: unlink only mpv"
$sym -t home dotfiles/* > /dev/null
cd expected-home
ln -s ../dotfiles/bash/.bashrc .
cd ..
# end setup
$sym -t home -v -d dotfiles/mpv &> log
expected="UNLINK: ${tmp}/home/.config/mpv/mpv.conf
RMDIR: ${tmp}/home/.config/mpv
RMDIR: ${tmp}/home/.config"
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
echo "  assertion 2: expected result"; diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home

echo -e "\n9: try to unlink bash, but conflict; bash is not owned by sym (dead symlink)"
cd home
tmpfile="$(mktemp)"
ln -sf "$tmpfile" .bashrc
cd ../expected-home
ln -sf "$tmpfile" .bashrc
cd ..
# end setup
$sym -t home -v -d dotfiles/* &> log || true
expected="CONFLICT: ${tmp}/home/.bashrc is an absolute symlink. sym only creates relative symlinks, so refusing to remove.
sym will not start until all conflicts are resolved."
echo "  assertion 1: expected output"; diff log <(echo "$expected") || nfailed=$((nfailed + 1))
echo "  assertion 2: expected result"; diff -r --no-dereference home expected-home || nfailed=$((nfailed + 1))
rm -r home; mkdir home
rm -r expected-home; mkdir expected-home

echo -e '\ntesting finished.'
(( "$nfailed" > 0 )) && die "failed ${nfailed} assertions"
