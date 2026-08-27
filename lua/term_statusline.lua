-- Show/hide the lualine statusline in snacks terminals, as a persisted global
-- preference. The snacks terminal carries its own winbar label, so its bottom
-- bar is optional; \ut (lua/config/keymaps.lua) flips it.
--
-- Two facts drive the design:
--   * lualine reads options.disabled_filetypes live, per window, on every
--     statusline render (lualine.lua status_dispatch), and applies the result
--     per window in refresh(). So the toggle is global by filetype -- every
--     snacks_terminal follows it -- but only windows that actually refresh
--     redraw. setup() schedules a tabpage-scoped refresh, which is why other
--     tabpages lagged; set() below forces a scope='all' refresh so every
--     terminal updates at once.
--   * get_config() returns a deepcopy (lualine/config.lua), so the only way to
--     change the live disabled list is lualine.setup(cfg).
--
-- The state is one file under stdpath('state'), read on every launch, so the
-- choice survives both a :RestartRestoreSession re-exec and a plain session
-- restore. Default (no file) is visible.
local M = {}

local FT = "snacks_terminal"
local statefile = vim.fn.stdpath("state") .. "/snacks_term_statusline"

-- true when the statusline is hidden in snacks terminals (persisted).
function M.hidden()
  local f = io.open(statefile, "r")
  if not f then return false end
  local v = f:read("*l")
  f:close()
  return v == "hidden"
end

local function persist(hidden)
  local f = io.open(statefile, "w")
  if f then
    f:write(hidden and "hidden" or "visible")
    f:close()
  end
end

-- The disabled_filetypes.statusline list lualine should start with, honoring the
-- persisted choice. Consumed by lua/plugins/statusline.lua at setup time.
function M.initial_disabled()
  return M.hidden() and { FT } or {}
end

-- Whether the statusline is currently shown in snacks terminals. Reads lualine's
-- live config when loaded, else falls back to the persisted value.
function M.shown()
  local ok, lualine = pcall(require, "lualine")
  if not ok then return not M.hidden() end
  local d = (lualine.get_config().options.disabled_filetypes or {}).statusline or {}
  return not vim.tbl_contains(d, FT)
end

-- Apply `shown` to every snacks terminal and persist it. Rewrites lualine's
-- disabled list (get_config is a copy, so setup re-applies).
--
-- lualine's refresh re-fills a window's statusline but never CLEARS one that was
-- already shown once its filetype becomes disabled -- the stale bar lingers,
-- most visibly on the focused terminal (the one you pressed \ut in). So drop
-- every snacks_terminal window's local statusline first (`setlocal statusline<`
-- reverts it to the global transparent bar -- the hidden look), then let a
-- forced all-window refresh re-fill only the now-enabled case. Clearing both
-- ways is harmless: on show, refresh repaints them.
function M.set(shown)
  persist(not shown)
  local ok, lualine = pcall(require, "lualine")
  if not ok then return end
  local cfg = lualine.get_config()
  cfg.options.disabled_filetypes = cfg.options.disabled_filetypes or {}
  local sl = cfg.options.disabled_filetypes.statusline or {}
  if shown then
    sl = vim.tbl_filter(function(ft) return ft ~= FT end, sl)
  elseif not vim.tbl_contains(sl, FT) then
    sl[#sl + 1] = FT
  end
  cfg.options.disabled_filetypes.statusline = sl
  lualine.setup(cfg)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_get_option_value("filetype", { buf = vim.api.nvim_win_get_buf(win) }) == FT then
      vim.api.nvim_win_call(win, function() vim.cmd("setlocal statusline<") end)
    end
  end
  pcall(lualine.refresh, { scope = "all", place = { "statusline" }, force = true })
end

return M
