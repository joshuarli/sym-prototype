# sym-prototype

sym is a straightforward batch symlinker developed to easily install and uninstall user configuration files / dotfiles.

It implements a feature subset of GNU Stow, but is similar in spirit. In fact, GNU Stow entirely satisfies my own needs, notwithstanding [several pain points](#Appendix) with regards to the use case in question, which it was not specifically designed to fulfill.

This is the python prototype and reference implementation for a possible golang implementation in the future.


## Installation

It's a standalone, stdlib-only python script that works on 3.6+ but can probably be trivially ported to 3.x if you so desire.


## Usage

Let's say `$HOME` looks like this:

	.
    ├── somewhere
    │ └── ...
    └── .config
       └── foo
          └── bar.conf

And you're in `${HOME}/somewhere/else/dotfiles`:

    .
    ├── bash
    │ └── .bashrc
    └── mpv
       └── .config
          └── mpv
             └── mpv.conf

To symlink your `bash` and `mpv` configuration files ("source" directories) to `$HOME` (the "target" directory's default value - it can be specified with `-t`), simply invoke:

	$ sym bash mpv

The resulting `$HOME`:

    .
    ├── somewhere
       └── ...
    ├── .bashrc -> somewhere/else/dotfiles/bash/.bashrc
    └── .config
       └── foo
          └── bar.conf
       └── mpv
          └── mpv.conf -> somewhere/else/dotfiles/mpv/.config/mpv/mpv.conf

To remove symlinks, pass the `-d` (delete) flag: `sym -d bash mpv`.


## Operational Notes

`sym` will:

- always create relative symlinks
	- will never create nor remove absolute symlinks
- create directories to accomodate new symlinks as needed
- remove empty directories that are created as a result of symlink removal (GNU Stow does not do this)

Like GNU Stow, `sym` performs two passes. The first pass collects symlink jobs, and if any conflicts are detected during this process, they will all be printed and `sym` will exit. The second pass executes all the symlink jobs, symlinking or removing depending on whether or not `-d` was passed.

A conflict occurs under the following conditions:

Symlink mode:

Remove mode:

TODO

By default, `sym` ignores some filepaths with a built-in filename glob blacklist. In the future, repeatable `--exclude` (glob or regex, not decided yet) and `--include` will be implemented.


## Appendix

There are several pain points when using GNU Stow to install/uninstall dotfiles.

Ideally, you want to be able to say `stow bash` and have your bash configuration files installed to `$HOME`. The only way to achieve this is to have your dotfiles in `~/somedir` and your files in `~/somedir/bash` e.g. `~/somedir/bash/.bashrc` and your pwd at `~/somedir` when you invoke `stow bash`. Only then you will get `~/.bashrc -> somedir/bash/.bashrc`. The target directory defaults to `${PWD}/..` (if `STOW_DIR` is not set, which usually isn't/wouldn't be by an end user), which is `$HOME` in this specific scenario.

What if you need additional levels of organization? Say `~/somedir/debian-headless/bash`. If your pwd is still `~/somedir`, you actually can't `stow debian-headless/bash` because GNU Stow does not permit slashes in package names (note the nomenclature with "package name": clearly, Stow is targetting a different use case). What if you cd to `~/somedir/debian-headless` and then invoked `stow bash`? That would result in `~/somedir/.bashrc -> debian-headless/.bashrc` because of the default target directory. So you need to pass `-t "$HOME"`! And then, what if you wanted the comfort of operating from just `~/somedir` instead of cd'ing back and forth? You would need to pass `-d debian-headless bash`.

Furthermore, what if you have something like `~/somedir/bin` full of your hacked-together scripts and you stow them on a fresh machine where `~/bin` doesn't exist yet? GNU Stow's default behavior is to "fold trees", which means instead of `~/bin/script-1 -> somedir/bin/script-1` and `~/bin/script-2 -> somedir/bin/script-1`, you get `~/bin -> somedir/bin` which is annoying when you want to add stuff to `~/bin` but not pollute your dotfiles repository. So you add `--no-folding` and suddenly, the incantations are getting quite long!

`sym` solves all these usability hurdles by default:

- `$HOME` is the default target directory
- no "tree folding" is done (the only symlinks `sym` creates resolve to files), nor is it supported
- slashes to source directories (what GNU Stow calls package names) are permitted
