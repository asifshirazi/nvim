# nvim

My Neovim configuration. Still Vimscript, still
[vim-plug](https://github.com/junegunn/vim-plug), deliberately no LSP.

It opens instantly and gets out of the way: a NERDTree sidebar, fuzzy finding
over files, popup completion on the command line, sessions that remember your
layout per project, and 43 colorschemes you can flip through with live preview
and one keystroke.

## Requirements

- **Neovim >= 0.11.7, built with LuaJIT.** That is Telescope's floor, the
  highest of any plugin here. Check with `:version`. Developed on 0.12.4.
- A **Nerd Font** in your terminal, for the file icons and tree arrows
- **True colour.** The themes are 24-bit only, so macOS `Terminal.app` will
  render them wrong. iTerm2, Ghostty, WezTerm and Kitty are all fine.
- Optional: [`ranger`](https://github.com/ranger/ranger), for `\f`
- Optional: [`ripgrep`](https://github.com/BurntSushi/ripgrep), for `\ts`.
  Telescope hardcodes `rg` in its default `vimgrep_arguments`, so live grep
  does nothing without it.
- Optional: [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter)
  with the `regex` and `bash` parsers, which noice uses to highlight the
  cmdline. Everything works without it; `:checkhealth noice` will warn.

## Install

**1. Clone this config.** Do this first, because `git clone` refuses a
non-empty directory: installing vim-plug before this would break it.

```sh
git clone https://github.com/asifshirazi/nvim.git ~/.config/nvim
```

**2. Install [vim-plug](https://github.com/junegunn/vim-plug).** It is not
vendored in this repo.

```sh
curl -fLo ~/.config/nvim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
```

**3. Install the plugins.**

```sh
nvim +PlugInstall +qa
```

Plugins install into `~/.local/share/nvim/plugged`.

## Keymaps

Leader is `\` (Vim's default). Press it and pause to get a
[which-key](https://github.com/folke/which-key.nvim) menu of everything below.

| key | does |
|---|---|
| `<C-t>` | toggle the NERDTree sidebar |
| `<Tab>` / `<S-Tab>` | next / previous buffer |
| `<C-q>` | close buffer, keeping the window layout |
| `\f` | Ranger |
| `\tf` | Telescope find files (dropdown, no preview) |
| `\ts` | Telescope live grep, search file contents |
| `\tgs` | Telescope git status (ivy panel) |
| `\h` | Themery, the colorscheme picker with live preview |
| `\d` | development mode: tree left, file centre, `claude` and `pi` terminals right |
| `\c` | small terminal split below |
| `\R` | `:Restart`, re-execs nvim and restores the whole layout |
| `\bd` | close buffer |

`\d` is the one worth explaining. It lays out a whole working session in a
single keystroke: NERDTree on the left, the file you were on in the middle, and
two terminals stacked on the right running `claude` and `pi`. Pair it with
`\R`, which re-execs Neovim and puts that layout back exactly as it was.

In NERDTree, `V`-select several nodes and then `o` `i` `s` `t` `d` `m` `c` `a`
to act on all of them at once.

`m` opens the node menu as a Telescope picker at the cursor, so you can filter
it by typing instead of hunting for the shortcut letter. `M` still gives you
NERDTree's original menu.

## Colorschemes

`\h` opens [themery](https://github.com/zaldih/themery.nvim), which lists every
colorscheme on the runtimepath (Neovim's built-ins plus everything installed)
and remembers your pick across restarts. Live preview as you scroll.

Bundled: [github](https://github.com/projekt0n/github-nvim-theme) (11 variants
including light, high-contrast and colourblind),
[nord](https://github.com/nordtheme/vim),
[vague](https://github.com/vague-theme/vague.nvim),
[modus](https://github.com/miikanissi/modus-themes.nvim) (WCAG AAA).

The statusline follows along automatically wherever the theme ships a matching
[vim-airline](https://github.com/vim-airline/vim-airline) theme.

## What's in here

| | |
|---|---|
| File explorer | nerdtree, nerdtree-visual-selection, ranger.vim |
| Navigation | telescope, bclose, which-key |
| Command line | noice (floating cmdline) + nvim-cmp sources |
| Sessions | auto-session, plus `:Restart` |
| Statusline | vim-airline |
| Icons | vim-devicons, nerdtree-syntax-highlight |

## Layout

```
init.vim        settings, plugin config, in numbered sections
config/
  plugins.vim     the plug#begin/end block
  keybinds.vim    mappings + which-key
  nerdtree.vim    NERDTree options, icons and highlights
  telescope.vim   NERDTree's `m` menu as a Telescope picker
  autoreload.vim  reload files changed outside nvim, even mid-edit
autoload/
  restart.vim     :Restart, loaded only when you first use it
```

Sessions are saved per working directory, so reopening `nvim` in a project
restores the windows, tabs and tree state you left behind. There is no session
file to name or manage.

Everything is commented with the *reason* for a setting rather than a
restatement of it, usually with a `file:line` pointer into the plugin source
that explains why the line exists at all. If a setting here looks strange, the
comment above it should tell you what went wrong without it.

## Changelog

[CHANGELOG.md](CHANGELOG.md) records what changed in each version. Every
version is tagged and published on the
[releases page](https://github.com/asifshirazi/nvim/releases).

## License

[MIT](LICENSE)
