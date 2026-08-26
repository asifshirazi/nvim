-- folke/snacks.nvim -- explorer, pickers, notifier, terminal, and QoL modules.
-- Replaces the old file-tree/fuzzy-finder/notification/icon plugin stack.
-- Keymaps live in lua/config/keymaps.lua. The dashboard lands only on an empty
-- startup with no session to restore; lua/session.lua restores project dirs.

return {
  {
    "folke/snacks.nvim",
    priority = 1000, -- per README: setup early (creates autocmds only)
    opts = {
      bigfile = { enabled = true },
      dashboard = {
        enabled = true,
        -- Logo fits in 60 cols (56 visible); header section centers it automatically.
        width = 60,
        preset = {
          header = [[
 ▄▄▄▄ ▄▄▄▄  ▄▄▄▄ ▄▄   ▄▄▄▄ ▄▄▄▄▄  ▄▄▄  ▄▄ ▄▄ ▄▄ ▄▄▄▄ ▄▄ 
░█ ░█ ░█ ░█ ░█ ░█ ░█ ░█ ░█ ▀▀ ░█ ░█ ░█ ░█ ░█ ▄▄ ░█ ░█ ░█
▒█ ░█ ▒█ ▀▀ ▒█ ▒█ ▒█ ▒█ ░█ ▄░▀▀  ▒█▀▀▀ ▒█ ░█ ▒█ ▒█ ▒█ ▒█
▓▓ ▓░ ▓▓    ▓▓ ▓▓ ▓▓ ▓▓ ▓░ ▒░ ▒░ ▓▓ ░█ ▓▓ ▓░ ▓▓ ▓▓ ▓▓ ▓▓
 ▀▀▀▀ ▀▀    ▀▀ ▀▀ ▀▀  ▀▀▀▀ ▀▀▀▀▀  ▀▀▀▀  ▀▀▀  ▀▀ ▀▀ ▀▀ ▀▀]],
          keys = {
            { icon = " ", key = "f", desc = "Find File",    action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "g", desc = "Find Text",    action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent Files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = " ", key = "n", desc = "New File",     action = ":ene | startinsert" },
            { icon = " ", key = "c", desc = "Config",       action = ":lua Snacks.dashboard.pick('files', {cwd = vim.fn.stdpath('config')})" },
            { icon = "󰒲 ", key = "L", desc = "Lazy",        action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit",         action = ":qa" },
          },
        },
        sections = {
          -- ARMAZEVIM logo: Forgotten Simplicity (TheDraw), centered by snacks.
          { section = "header", padding = 1 },
          -- Shortcuts
          { section = "keys", gap = 1, padding = 1 },
          -- Recent files
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          -- Git log for the current repo (hidden outside repos, cached 5 min).
          {
            section = "terminal",
            icon = " ",
            title = "Git Log",
            enabled = function() return Snacks.git.get_root() ~= nil end,
            cmd = "git --no-pager log --graph -2 --pretty=format:'%C(yellow)%h%Creset %C(cyan)%<(12,trunc)%an%Creset%C(green)%>(34)%ar%Creset%n    %C(white)%<(50,trunc)%s%Creset' --color=always 2>/dev/null; sleep .1",
            height = 6,
            padding = 1,
            ttl = 5 * 60,
            indent = 3,
          },
          { section = "startup" },
        },
      },
      explorer = { enabled = true }, -- replace_netrw = true default
      image = { enabled = true },
      indent = { enabled = true },
      input = { enabled = true },
      notifier = { enabled = true },
      toggle = { which_key = true },
      picker = {
        enabled = true,
        layouts = {
          buflist = {
            layout = {
              backdrop = false,
              row = 1,
              width = 0.4,
              min_width = 80,
              height = 0.8,
              border = "none",
              box = "vertical",
              { win = "preview", title = "{preview}", height = 0.4, border = true },
              {
                box = "vertical",
                border = true,
                title = "{title} {live} {flags}",
                title_pos = "center",
                footer = " <Tab> select  <C-x> delete  <C-a> all  ? help ",
                footer_pos = "center",
                { win = "input", height = 1, border = "bottom" },
                { win = "list", border = "none" },
              },
            },
          },
        },
        sources = {
          explorer = {
            hidden = true,      -- show dotfiles
            watch = true,       -- auto-refresh tree on filesystem changes (fs-events)
            follow_file = false, -- built-in follow expands the whole path; custom follow below selects instead
            layout = { layout = { width = 22 } }, -- sidebar preset (search input on top)
          },
        },
      },
      quickfile = { enabled = true },
      scroll = { enabled = true },
      statuscolumn = { enabled = true },
    },
    config = function(_, opts)
      require("snacks").setup(opts)
      -- file window with only the explorer left quits nvim. If the explorer
      -- layout keeps a second (input) window, winnr('$')==1 is never true and
      -- this is a harmless no-op (explorer just stays open).
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function()
          if vim.fn.winnr("$") == 1 and vim.bo.filetype == "snacks_picker_list" then
            vim.cmd.quit()
          end
        end,
      })

      -- Give snacks terminals (and other SnacksNormal windows) the darker
      -- NormalFloat background, so a terminal pane tones with the explorer
      -- sidebar instead of the lighter editor Normal. snacks links SnacksNormal
      -- -> NormalFloat only with default=true, and tokyonight defines it first
      -- with no bg, so re-assert the link here and on every colorscheme change
      -- (the \h picker re-applies the theme, which would otherwise clobber it).
      local function tone_snacks_normal()
        vim.api.nvim_set_hl(0, "SnacksNormal", { link = "NormalFloat" })
        vim.api.nvim_set_hl(0, "SnacksNormalNC", { link = "NormalFloat" })
      end
      tone_snacks_normal()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = tone_snacks_normal })

      -- Plain :terminal windows (the \d dev-layout claude/pi panes) are not
      -- snacks windows, so the relink above never reaches them -- they use the
      -- global Normal. Map their Normal to NormalFloat on open so they tone with
      -- the explorer too. Skipped when a Normal mapping already exists, which
      -- leaves the snacks \c terminal (Normal:SnacksNormal) untouched.
      vim.api.nvim_create_autocmd("TermOpen", {
        callback = function()
          local wh = vim.wo.winhighlight
          if not wh:find("Normal:", 1, true) then
            vim.wo.winhighlight = (wh == "" and "" or wh .. ",")
              .. "Normal:NormalFloat,NormalNC:NormalFloat"
          end
        end,
      })

      -- Explorer follow that SELECTS but never expands. On focusing a file
      -- window, walk up from the file revealing the deepest path already shown
      -- in the tree: if the file is visible it lands on the file, otherwise on
      -- its nearest collapsed ancestor -- folders stay closed. snacks' own
      -- follow_file expands the path (explorer/actions.lua:84), so it's off
      -- above. Snacks.picker.get + Actions.reveal are the only snacks touchpoints;
      -- reveal only views an item already in the list, so it never opens a folder.
      vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter" }, {
        callback = function(ev)
          if ev.buf ~= vim.api.nvim_get_current_buf() or vim.bo[ev.buf].buftype ~= "" then
            return
          end
          local file = vim.api.nvim_buf_get_name(ev.buf)
          if file == "" then
            return
          end
          local ok, pickers = pcall(Snacks.picker.get, { source = "explorer" })
          local p = ok and pickers[1]
          if not p or p.closed or p:is_focused() or not p:on_current_tab() then
            return
          end
          pcall(function()
            local reveal = require("snacks.explorer.actions").reveal
            local target = vim.fs.normalize(file)
            for _ = 1, 40 do
              if target == "" or target == "/" or reveal(p, target) then
                break
              end
              target = vim.fs.dirname(target)
            end
          end)
        end,
      })

      -- Open :help (and K / keywordprg) in a centered float instead of a split.
      -- FileType fires as the help window is set up, so defer one tick, then move
      -- the help buffer out of its split into a Snacks.win float (keeping the tag
      -- cursor). Following a help link reuses the float: if the buffer is already
      -- in a floating window we leave it, so navigation stays distraction-free.
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "help",
        callback = function(ev)
          vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(ev.buf) or vim.bo[ev.buf].buftype ~= "help" then
              return
            end
            local wins = vim.fn.win_findbuf(ev.buf)
            for _, w in ipairs(wins) do
              if vim.api.nvim_win_get_config(w).relative ~= "" then return end
            end
            local cursor
            for _, w in ipairs(wins) do
              cursor = cursor or vim.api.nvim_win_get_cursor(w)
              pcall(vim.api.nvim_win_close, w, false)
            end
            local win = Snacks.win({
              buf = ev.buf,
              width = 80,
              height = 0.85,
              border = "rounded",
              title = " Help ",
              title_pos = "center",
            })
            if cursor and win and win.win and vim.api.nvim_win_is_valid(win.win) then
              pcall(vim.api.nvim_win_set_cursor, win.win, cursor)
            end
          end)
        end,
      })
    end,
  },
  -- Icon provider: used by snacks picker/explorer and by lua/winbar.lua
  -- (replaces VimScript vim-devicons; get_icon_color lazily self-setups).
  { "nvim-tree/nvim-web-devicons" },
}
