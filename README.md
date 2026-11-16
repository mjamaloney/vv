# vv Jujutsu Plugin for vim

`vv` is a plugin to improve JJ workflows from within vim. Requires Vim 9.1+ and `jj`.

## Install

With vim-plug:

```vim
Plug '~/src/vv'
```

## Usage

`:VV` (or `:VVLog [revset]`) opens a log view that works as a hub. Each key acts
on the revision under the cursor:

| Key | Action |
|---|---|
| `<CR>` / `p` | Show the diff (focus it / preview and stay in the log) |
| `e` | Edit the description; `:w` applies it |
| `m` / `M` | Mark the revision (or revision + descendants) to move |
| `a` / `b` / `o` | Move the marked revision after / before / onto this one |
| `s` `n` `E` `X` | squash / new / edit / abandon |
| `u` | `jj undo` |
| `g?` | Help |

See `:help vv`.

## Features

* [x] Navigate jj revisions in a view that looks like `jj log`
* [x] Change descriptions of revisions on the fly
* [x] Rearrange revisions
* [~] Navigate through diffs of revisions (unified diff done; side-by-side TODO)

## Development

```sh
./test/run.sh   # runs the suite against a throwaway jj repo
```

Layout: `plugin/` defines the commands, `autoload/vv.vim` runs jj (sync and
async), and each feature lives in `autoload/vv/` (`log`, `describe`, `diff`, `rebase`).
