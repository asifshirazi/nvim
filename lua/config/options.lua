-- Basic settings, appearance and providers.
-- Ported from init.vim sections 2, 3 and 11. The colorscheme is deliberately
-- NOT set here: that is the nord spec's job (lua/plugins/colorschemes.lua), so
-- the fresh-machine fallback runs at plugin-config time and themery can then
-- override it. See the load-order notes in lua/config/lazy.lua.

-- `syntax enable` is dropped: syntax is on by default in Neovim.

-- Block where the cursor sits on a character, bar where it sits between them.
vim.opt.guicursor = "n-v-c:block,i-ci-ve:ver25-blinkwait400-blinkoff200-blinkon150,r-cr:hor20-blinkwait400-blinkoff200-blinkon150,o:hor50,t:ver25-blinkwait400-blinkoff200-blinkon150"
vim.opt.encoding = "utf-8"            -- use UTF-8 file encoding
vim.opt.clipboard:append("unnamedplus") -- use system clipboard directly (register '+')
vim.opt.mouse = "a"                   -- mouse in all modes (click cursor, resize splits)
vim.opt.mousescroll = "ver:1,hor:0"
vim.opt.whichwrap:append("<,>,h,l")   -- arrows cross line edges to next/prev line
vim.opt.timeoutlen = 300              -- snappy key-repeat/escape, less lag
vim.opt.updatetime = 1000             -- faster CursorHold -> checktime, so autoread doesn't wait for focus

-- Indentation
vim.opt.tabstop = 2                   -- visual width of a <Tab>
vim.opt.shiftwidth = 2                -- spaces per auto-indent step
vim.opt.expandtab = true              -- insert spaces, never a literal <Tab>

-- Appearance
vim.opt.number = true                 -- show line numbers
vim.opt.fillchars:append({ stl = " ", stlnc = " " }) -- pad status line so it looks continuous

-- Whitespace reveal, toggled per window with \l (lua/config/keymaps.lua).
-- Everything stays invisible until 'list' is turned on; 'listchars' only
-- defines what shows once it is.
vim.opt.list = false
vim.opt.listchars = {
  eol = "$",
  tab = ">-",
  trail = "-",
  lead = "-",
  extends = "~",
  precedes = "~",
  conceal = "+",
  nbsp = "&",
}

-- Command line & messages (blink.cmp + noice). blink brings its own fuzzy
-- matcher, so this only affects the native wildmenu fallback -- fuzzy there
-- too, for the case where blink's binary is unavailable.
vim.opt.wildoptions:append("fuzzy")

-- Providers
vim.g.loaded_perl_provider = 0
