-- Named, toggleable snacks terminals, shared by lua/config/keymaps.lua (the
-- \tt / \tv / \tc / \tx / \tp / \to mappings) and lua/restart.lua (reopen
-- across :Restart).
--
-- snacks keys a terminal by { cmd, cwd, env, count } -- NOT its window position
-- (snacks/terminal.lua M.tid). All terminals use cmd=nil (the default shell) so
-- restart.lua's resumable_descendant can walk the process tree, find claude/omp
-- running as a child, and resume it with --continue. Fixed count ids keep each
-- pair distinct AND let :Restart reopen the very same ids toggleably.

local M = {}

-- id -> window placement. relative='win' splits the current window (not the
-- full editor edge). See lua/config/keymaps.lua for the \t* bindings.
local specs = {
  [1] = { position = "bottom", height = 10, relative = "win" }, -- \tt shell
  [2] = { position = "right",  width  = 0.4, relative = "win" }, -- \tv shell
  [3] = { position = "bottom", height = 10, relative = "win" }, -- \tc claude
  [4] = { position = "right",  width  = 0.4, relative = "win" }, -- \tx claude
  [5] = { position = "bottom", height = 10, relative = "win" }, -- \tp omp
  [6] = { position = "right",  width  = 0.4, relative = "win" }, -- \to omp
}

local function toggle(id)
  Snacks.terminal.toggle(nil, { count = id, win = specs[id] })
end

-- For claude/omp terminals: check for an existing buffer BEFORE toggle (toggle
-- creates the buffer, so checking after always finds it and skips the send).
-- If the terminal is new, poll until the shell's job channel is live, then type
-- cmd. Subsequent toggles show/hide the existing pane -- no send. On :Restart,
-- reopen() handles resume via its own polling + cmds table.
local function open_with_cmd(id, cmd)
  local is_new = true
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if (vim.b[b].snacks_terminal or {}).id == id then
      is_new = false
      break
    end
  end
  toggle(id)
  if not is_new then return end
  local tries, sent = 0, false
  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(50, 50, vim.schedule_wrap(function()
    if sent then return end
    tries = tries + 1
    for _, b in ipairs(vim.api.nvim_list_bufs()) do
      if (vim.b[b].snacks_terminal or {}).id == id then
        local chan = vim.b[b].terminal_job_id
        if chan and chan > 0 then
          sent = true
          timer:stop()
          if not timer:is_closing() then timer:close() end
          vim.api.nvim_chan_send(chan, cmd .. '\r')
          return
        end
      end
    end
    if tries > 40 then  -- 2 s timeout
      sent = true
      timer:stop()
      if not timer:is_closing() then timer:close() end
    end
  end))
end

-- Generic shell terminals.
function M.bottom()   toggle(1) end
function M.vertical() toggle(2) end

-- Dedicated terminals: open a shell and auto-launch the command on first open.
-- Subsequent toggles show/hide the existing pane without sending anything.
function M.claude_bottom()   open_with_cmd(3, 'claude') end
function M.claude_vertical() open_with_cmd(4, 'claude') end
function M.omp_bottom()      open_with_cmd(5, 'omp')    end
function M.omp_vertical()    open_with_cmd(6, 'omp')    end

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

-- Reopen the given ids as managed snacks terminals (so \tt/\tv/\tc/\tx/\tp/\to
-- toggle them again). Opened with cmd=nil so auto-insert etc. stay intact.
-- cmds: optional {[id] = 'shell command string'} -- sent to the new shell once
-- its job channel is ready, used by :Restart to resume claude/omp sessions
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
