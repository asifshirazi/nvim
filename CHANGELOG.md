# Changelog

All notable changes to this config are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and
versions follow [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.1] - 2026-08-25

The command line moves to blink.cmp, terminal panes tone with the sidebar, and
:Restart restores pane sizes -- plus a round of restart-flow fixes.

### Added

- **Terminal panes share the explorer's darker background.** Both take the
  theme's floating-window tone, so a `\d` layout reads as one surface instead
  of terminals sitting on the lighter editor background. Covers the snacks
  terminal and the plain `:terminal` panes.
- **Instant reload when a terminal job exits.** `TermClose`/`TermLeave` join
  the autoreload triggers, so a file rewritten by claude/pi/omp refreshes the
  moment the job finishes rather than on the next one-second poll.
- **`:Restart` confirms when it's done**, with a notification naming what came
  back (layout, explorer and claude/pi/omp sessions).
- **Slanted/rounded statusline separators** and a line-number icon on the
  cursor-position segment; the pointed `>`/`<` component dividers are dropped.

### Changed

- **Command-line completion is [blink.cmp](https://github.com/saghen/blink.cmp)**,
  replacing nvim-cmp and its cmp-cmdline/cmp-path/cmp-buffer sources -- four
  plugins down to one, with blink's own fuzzy matcher. It stays command-line
  only (no insert-mode popup, no LSP here): the `:` menu appears after four
  characters of a command name, `/` and `?` keep the classic bottom line, and
  `<CR>` accepts-and-runs. noice's own popup is off, so blink draws the one menu.
- **The explorer's `watch` is set explicitly**, documenting that the sidebar
  refreshes itself on filesystem changes -- the reason autoreload no longer
  pokes the tree.

### Removed

- **nvim-cmp, cmp-cmdline, cmp-path and cmp-buffer**, replaced by blink.cmp.

### Fixed

- **`:Restart` restores pane widths and heights.** The explorer was closed
  before `mksession`, so the remaining panes were saved at their expanded sizes
  and the reopened sidebar reflowed them. The full-layout sizes are captured
  before the close now and re-applied once the sidebar is back.
- **`:Restart` no longer errors or flashes a stray "Not auto-restoring"
  message.** auto-session's auto-restore is disabled for the restart launch
  (rather than aborted mid-flight), so it never races `:Restart` for the
  restore, never emits that notice, and never trips noice's "vim.notify has
  been overwritten" guard. A redraw after restore clears leftover cells.

## [0.3.0] - 2026-08-25

The config is Lua on lazy.nvim now, and one plugin does what nine used to:
snacks.nvim replaces the NERDTree/Telescope stack, with lualine and gitsigns
taking over the statusline.

### Added

- **[snacks.nvim](https://github.com/folke/snacks.nvim)**: the explorer
  sidebar, the pickers, notifications, the toggleable terminal, and the
  quality-of-life modules (bigfile, indent guides, input, quickfile, smooth
  scroll, statuscolumn). The explorer keeps the old tree's shape -- 22 columns
  on the left, dotfiles visible, git status marks -- and brings built-in file
  operations (`a` add, `r` rename, `d` delete, `m` move, `c` copy, `u`
  refresh), each prompting in a floating input.
- **lazygit on `\gg`**, opened in a floating terminal themed to match the
  active colorscheme.
- **A lualine statusline fed by gitsigns**: the branch, and `+n ~n -n` counts
  for the current buffer diffed against the index. gitsigns also draws the
  hunk signs in the gutter. The mode indicator moved into the bar
  (`showmode` off).
- **`\l` reveals whitespace** in the current window: `$` line ends, `>-` tabs,
  `-` trailing and leading spaces, `&` non-breaking spaces.
- **`\gs`, git status as an ivy picker** (moved from `\tgs`), grouped with
  lazygit under `\g`.

### Changed

- **The whole config is Lua on lazy.nvim.** `init.vim` and `config/*.vim` are
  gone; specs live one file per concern under `lua/plugins/`, and lazy.nvim
  bootstraps itself on first start -- there is no plugin manager to install by
  hand any more.
- **`<C-t>` toggles the snacks explorer.** `:Restart` reopens the sidebar,
  now at the cwd root: snacks keeps its own tree state, so the expanded-folder
  capture is gone. auto-session still restores with the sidebar closed.
- **`\tf` and `\ts` are snacks pickers**, in the same dropdown layout the
  Telescope versions used.
- **`<C-q>` prompts to save or discard a modified buffer** instead of refusing
  with an error. The window layout is preserved as before, and `\bd` behaves
  the same way.
- **`\c` toggles its 10-line bottom terminal** instead of stacking a fresh
  split on every press.
- **`\d` reveals the current file in the explorer** rather than just opening
  the tree at its root.
- **Winbar icons come from nvim-web-devicons.** Every file gets a coloured
  glyph now; types outside the old NERDTree colour tables used to render
  uncoloured, and unknown types take devicons' default grey.
- **Notifications render through snacks.notifier.** noice's notify view falls
  through to it with nvim-notify gone.

### Removed

- **Twelve plugins**: nerdtree, nerdtree-visual-selection,
  vim-nerdtree-syntax-highlight, ranger.vim, vim-devicons, telescope.nvim,
  plenary.nvim, bclose.vim, nvim-notify, vim-airline, vim-airline-themes and
  vim-fugitive. Nineteen remain.
- **`\f` (Ranger).** A full-screen TUI file manager has no snacks equivalent,
  and the explorer covers browsing.
- **The NERDTree `m`-menu Telescope port**, subsumed by the explorer's
  built-in file operations.

## [0.2.4] - 2026-08-24

Buffer tabs are drawn per window now, and `omp` terminals resume across a
restart.

### Added

- **A per-window buffer strip** (`config/winbar.vim`), drawn in `'winbar'`
  rather than the tabline, so each split shows its own tabs in the order you
  opened them instead of every buffer open anywhere. Each tab carries its
  filetype glyph and closes from its own click target, dropping out of that
  window's strip while the buffer stays loaded; a modified buffer shows a dot
  in place of the close glyph. `<Tab>` and `<S-Tab>` cycle the window's own
  list, and the strips survive both `:Restart` and auto-session.
- **`omp` joins `claude` and `pi` as a terminal whose session survives a
  restart.** When the working directory has a saved `omp` session, the restored
  pane relaunches with `--continue` and picks the conversation back up.

### Changed

- **A plain quit and reopen now resumes terminal sessions, not only
  `:Restart`.** auto-session rewrites `claude`, `pi` and `omp` panes to
  `--continue` as it saves, so reopening the layout continues each session
  instead of starting fresh.
- **`<Tab>` and `<S-Tab>` walk the current window's buffer list**, not the
  global one. `:bnext` and `:bprevious` kept pulling in buffers opened in other
  windows, and each one joined this window's strip.
- **airline's buffer tabline is off**, replaced by the per-window strip.
  Running both drew every name twice and cost a screen line, airline's tabline
  being global.
- **Indentation inserts spaces instead of a literal tab** (`expandtab`), at the
  existing width of two.
- **Line numbers sit four spaces off the text** via `'statuscolumn'`.

## [0.2.3] - 2026-08-24

An animated cursor, a shape per mode, and two more files out of `init.vim`.

### Added

- **[smear-cursor](https://github.com/sphamba/smear-cursor.nvim)**, which
  animates the cursor gliding between positions instead of jumping. Toggle it
  at runtime with `:SmearCursorToggle`.

### Changed

- **The cursor now takes a shape per mode**: a block wherever it sits on a
  character, a bar in the insert-like modes where it sits between them, and an
  underline while replacing. A bar everywhere reads wrong at end of line, since
  `<End>` stops on the last character rather than past it, so the bar lands to
  the left of it.
- **`airline.vim` and `themery.vim` moved into `config/`**, leaving `init.vim`
  sections 5 and 6 as a source line each.

### Fixed

- **`\tgs` opens git status in the ivy panel its own comment describes.** The
  argument was lost before the mapping was first committed, so the picker had
  always been opening with the default layout.

## [0.2.2] - 2026-08-24

NERDTree's node menu is a Telescope picker now, and the sourced files moved into
`config/`.

### Added

- **NERDTree's `m` menu as a Telescope picker**, opening at the cursor and sized
  to its contents, so the eleven actions can be filtered by typing instead of
  hunting for the shortcut letter. The original menu stays on `M`.

### Changed

- **Messages belong to noice again.** NERDTree confirmations, such as the path
  copied to your clipboard, arrive as notifications rather than on the bottom
  line. They had been left native because the old `m` menu repaints on every
  keypress and stacked a notification per keystroke; noice now stands down for
  the length of that menu alone, which only `M` still reaches.
- **`plugins.vim`, `keybinds.vim`, `nerdtree.vim`, `telescope.vim` and
  `autoreload.vim` moved into `config/`.** Only `restart.vim` remains in
  `autoload/`, being the one file genuinely loaded on demand. Note that
  autoreload's guard against stacking polling timers depended on being
  autoloaded, since Vim sources such a file once per session; the timer id lives
  in `g:autoreload_timer` now so re-sourcing `init.vim` still cannot stack them.

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

[0.3.1]: https://github.com/asifshirazi/nvim/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/asifshirazi/nvim/compare/v0.2.4...v0.3.0
[0.2.4]: https://github.com/asifshirazi/nvim/compare/v0.2.3...v0.2.4
[0.2.3]: https://github.com/asifshirazi/nvim/compare/v0.2.2...v0.2.3
[0.2.2]: https://github.com/asifshirazi/nvim/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/asifshirazi/nvim/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/asifshirazi/nvim/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/asifshirazi/nvim/releases/tag/v0.1.0
