" ==== 1. Plugins ============================================================
call plug#begin()
  " ---- File explorer ----
  Plug 'preservim/nerdtree'
  Plug 'PhilRunninger/nerdtree-visual-selection'  " V-select several nodes, then o/i/s/t/d/m/c/a
  Plug 'francoiscabrol/ranger.vim'

  " ---- Editing & navigation ----
  Plug 'nvim-telescope/telescope.nvim'
  Plug 'nvim-lua/plenary.nvim'   " telescope dependency
  Plug 'rbgrouleff/bclose.vim'
  Plug 'folke/which-key.nvim'    " key hints; supports explicit menu ordering

  " ---- Command line & messages ----
  Plug 'hrsh7th/nvim-cmp'        " completion engine; configured cmdline-only here
  Plug 'hrsh7th/cmp-cmdline'     " : commands and their arguments
  Plug 'hrsh7th/cmp-path'        " filesystem paths
  Plug 'hrsh7th/cmp-buffer'      " words from the current buffer, for / and ?
  Plug 'folke/noice.nvim'        " routes cmdline, messages and popupmenu into floats
  Plug 'MunifTanjim/nui.nvim'    " noice dependency (required)
  Plug 'rcarriga/nvim-notify'    " noice's notify view; without it routes fall back to mini

  " ---- Sessions ----
  Plug 'rmagatti/auto-session'   " save/restore the layout per working directory

  " ---- Statusline ----
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'

  " ---- Colorschemes ----
  Plug 'zaldih/themery.nvim'                      " :Themery picker -- see init.vim section 6
  Plug 'projekt0n/github-nvim-theme'              " 11 github_* schemes + airline themes
  Plug 'nordtheme/vim', { 'as': 'nord' }          " `nord` + airline theme; 'as' avoids plugged/vim
  Plug 'vague-theme/vague.nvim'                   " `vague`
  Plug 'miikanissi/modus-themes.nvim'             " modus_operandi (light) / modus_vivendi (dark)

  " ---- Icons ----
  Plug 'ryanoasis/vim-devicons'                   " file glyph icons
  Plug 'tiagofumo/vim-nerdtree-syntax-highlight'  " per-filetype icon colours (load after devicons)

call plug#end()
