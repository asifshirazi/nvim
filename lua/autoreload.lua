-- Auto-detect external file changes. Port of config/autoreload.vim.
--
-- 'autoread' only reloads a buffer when something asks it to, via :checktime.
-- The usual autocmd triggers all depend on you (focus, entering a window,
-- CursorHold never fires while typing in a terminal pane). So poll on a timer as
-- well -- that reloads a file edited outside Nvim without clicking into it.
--
-- The snacks explorer needs no help here: it watches the filesystem itself
-- (fs-events, watch = true default) and refreshes on demand with `u`.

local M = {}

-- Module-local so a re-require never stacks a second polling timer.
local timer = -1

-- :checktime throws inside the command-line window (q: / q/); the pcall mirrors
-- the VimScript `silent!`.
local function tick()
  if vim.fn.getcmdwintype() ~= '' then
    return
  end
  pcall(vim.cmd, 'checktime')
end

function M.enable(interval)
  interval = interval or 1000

  local grp = vim.api.nvim_create_augroup('autoreload', { clear = true })
  vim.api.nvim_create_autocmd({ 'FocusGained', 'CursorHold', 'CursorHoldI', 'BufEnter' }, {
    group = grp,
    pattern = '*',
    callback = tick,
  })

  if timer == -1 then
    timer = vim.fn.timer_start(interval, tick, { ['repeat'] = -1 })
  end
  return timer
end

function M.disable()
  pcall(vim.api.nvim_del_augroup_by_name, 'autoreload')
  if timer ~= -1 then
    vim.fn.timer_stop(timer)
    timer = -1
  end
end

return M
