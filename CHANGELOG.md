# Changelog

All notable changes to this config are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1] - 2026-08-23

Fuzzy command-line matching restored, and the Telescope keys grouped under `\t`.

### Added

- **`\ts`**, live grep across the project, and **`\tgs`**, git status in an ivy
  panel at the bottom of the screen.
- ripgrep in the README requirements. Telescope hardcodes `rg` for grep, so
  `\ts` does nothing without it.

### Changed

- **`\t` is now a menu rather than a mapping.** File finding moved to `\tf`,
  and which-key lists the group on `\t` with a nested `git` group under `\tg`.

### Fixed

- **Lowercase and fuzzy matching on the command line.** `:tele` completes
  `Telescope` again, and `:tlscp` reaches it too. Command-line completion had
  been prefix- and case-sensitive since 0.2.0 replaced wilder: the new
  completion source reads its candidates from `getcompletion()`, which does no
  fuzzy matching of its own unless `'wildoptions'` says so.

## [0.2.0] - 2026-08-23

Command line rebuilt on nvim-cmp and noice, and NERDTree config split into its
own file.

### Added

- **Floating command line** via [noice.nvim](https://github.com/folke/noice.nvim).
  `:` now opens a centred palette instead of the bottom line.
- **Popup completion for `:`, `/` and `?`** via
  [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) with the `cmdline`, `path`
  and `buffer` sources. Paths are matched first, command names second.
- **`nerdtree.vim`**, holding every NERDTree option, its devicons glyphs and the
  neutral-name highlights. `init.vim` section 7 is now a single `source` line.

### Changed

- Completion for `:e src/` now scopes into the directory instead of listing the
  whole tree.
- `:Telescope` completes its 52 subcommands. Under the old setup it completed
  nothing at all.
- Messages stay on Neovim's native message line. noice takes only the command
  line and the popup menu.

### Removed

- `wilder.nvim` and `fzy-lua-native`, replaced by nvim-cmp.
- `glyph-palette.vim`, which existed solely to colour wilder's popup.

### Fixed

- **`E704` when completing `:Telescope`, `:Man` or `:SessionRestore`.** These
  commands supply a function rather than a string for their completion, which
  the old command-line plugin could not handle. It had no upstream fix, so the
  config carried a local patch; that patch is gone along with the plugin.
- **NERDTree's `m` menu.** It was rendering as a notification in the top-right
  corner, then duplicating itself on every keypress. It now behaves exactly as
  it did before noice.

## [0.1.0] - 2026-08-23

First tagged version. A Vimscript Neovim config built on vim-plug, with no LSP.

### Added

- **NERDTree sidebar** with file icons, per-filetype icon colours and
  multi-select actions.
- **Telescope** file finding, bound to `\t`.
- **43 colorschemes** switchable at runtime through
  [themery](https://github.com/zaldih/themery.nvim) on `\h`, with live preview
  and the choice remembered across restarts. Bundled: github, nord, vague and
  modus.
- **Per-project sessions** through auto-session, plus `:Restart`, which re-execs
  Neovim and restores the whole layout.
- **`\d` development mode**, laying out tree, file and two terminals in one
  keystroke.
- **which-key** menu on `\`, in a hand-ordered list rather than alphabetical.
- **`autoreload.vim`**, picking up files changed outside Neovim even mid-edit.
- **README and MIT licence.**

### Changed

- vim-plug is no longer vendored in the repository. It installs per machine, as
  described in the README.
- Plugins install to `~/.local/share/nvim/plugged`, vim-plug's own default,
  rather than inside the config directory.

[0.2.1]: https://github.com/asifshirazi/nvim/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/asifshirazi/nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/asifshirazi/nvim/releases/tag/v0.1.0
