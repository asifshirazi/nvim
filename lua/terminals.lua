-- Named, toggleable snacks terminals, shared by lua/config/keymaps.lua (the
-- \c / \v mappings) and lua/restart.lua (reopen across :Restart).
--
-- snacks keys a terminal by { cmd, cwd, env, count } -- NOT its window position
-- (snacks/terminal.lua M.tid). Two toggles with cmd=nil and no count therefore
-- collide on count=1 and drive the same terminal. Fixed `count` ids below keep
-- \c and \v distinct AND let :Restart reopen the very same ids, so the keymaps
-- keep toggling them after a restart.

local M = {}

-- id -> window placement. relative='win' splits the current window (not the
-- full editor edge). See lua/config/keymaps.lua for the bindings.
local specs = {
  [1] = { position = "bottom", height = 10, relative = "win" }, -- \c
  [2] = { position = "right", width = 0.4, relative = "win" },  -- \v
}

local function toggle(id, opts)
  opts = opts or {}
  opts.count = id
  opts.win = specs[id]
  Snacks.terminal.toggle(nil, opts)
end

function M.bottom()
  toggle(1)
end

function M.vertical()
  toggle(2)
end

-- State of snacks terminals currently open in a window. Returns {id, bufnr}
-- pairs so restart.lua can inspect each terminal's running process before
-- closing. Used by :Restart; see lua/restart.lua M.save.
function M.open_state()
  local states = {}
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == 'snacks_terminal' then
      local st = vim.b[b].snacks_terminal
      if st and st.id and specs[st.id] then
        states[#states + 1] = { id = st.id, bufnr = b }
      end
    end
  end
  return states
end

-- Wipe all open snacks terminal windows. Used by :Restart before mksession, so
-- the session never captures them as unmanaged plain terminals (which come back
-- non-toggleable). The shell dies on the re-exec regardless, like every other
-- terminal pane.
function M.close_all()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.bo[b].filetype == "snacks_terminal" then
      pcall(vim.api.nvim_buf_delete, b, { force = true })
    end
  end
end

-- Reopen the given ids as managed snacks terminals (so \c / \v toggle them
-- again). Opened with snacks' normal opts so auto-insert etc. stay intact.
-- cmds: optional {[id] = 'shell command string'} -- sent to the new shell once
-- its job channel is ready, used by :Restart to resume claude/pi/omp sessions
-- that were running inside a terminal before the restart.
function M.reopen(ids, cmds)
  if not ids or #ids == 0 then return end
  local cur = vim.api.nvim_get_current_win()
  for _, id in ipairs(ids) do
    if specs[id] then
      toggle(id)
      local cmd_str = cmds and cmds[id]
      if cmd_str then
        -- Poll until the terminal job channel exists, then send the command.
        local tries, sent = 0, false
        local timer = (vim.uv or vim.loop).new_timer()
        timer:start(50, 50, vim.schedule_wrap(function()
          if sent then return end
          tries = tries + 1
          for _, b in ipairs(vim.api.nvim_list_bufs()) do
            local st = vim.b[b].snacks_terminal
            if st and st.id == id then
              local chan = vim.b[b].terminal_job_id
              if chan and chan > 0 then
                sent = true
                timer:stop()
                if not timer:is_closing() then timer:close() end
                vim.api.nvim_chan_send(chan, cmd_str .. '\r')
                return
              end
            end
          end
          if tries > 20 then
            sent = true
            timer:stop()
            if not timer:is_closing() then timer:close() end
          end
        end))
      end
    end
  end
  if vim.api.nvim_win_is_valid(cur) then
    pcall(vim.api.nvim_set_current_win, cur)
  end
  pcall(vim.cmd, 'stopinsert')
end

return M
