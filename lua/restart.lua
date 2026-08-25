-- :Restart -- restart Nvim, restoring the whole layout. Port of
-- autoload/restart.vim.
--
-- :restart (Nvim 0.12+) quits, re-execs the server with the same argv and
-- reattaches the UI; :mksession captures tabs, windows and buffers. A running
-- process can't be checkpointed, so terminal panes would relaunch from
-- scratch -- rewrite their commands to resume the previous session instead.
-- The snacks explorer is a scratch picker mksession cannot carry: it is
-- closed before saving and reopened by a line injected into the session file.

local M = {}

local session_file = vim.fn.stdpath('state') .. '/restart-session.vim'
local resumable = { 'claude', 'pi', 'omp' }   -- CLIs whose sessions survive via --continue
-- auto-session auto-restores at VimEnter whenever nvim starts with no file
-- arguments -- exactly what :restart does. Drop a sentinel the pre_restore hook
-- in lua/plugins/sessions.lua checks, so auto-session stands down for this one restart.
local skip_flag = vim.fn.stdpath('state') .. '/restart-skip-autosession'

-- All three CLIs store sessions per working directory, under a mangled directory
-- name. Passing --continue with no saved session makes them abort, so only add
-- the flag when one actually exists. Regex/glob strings are kept identical to
-- the VimScript original.
local function has_session(cmd, cwd)
  local c = vim.fn.fnamemodify(vim.fn.expand(cwd), ':p:h')
  local dir
  if cmd == 'claude' then        -- ~/.claude/projects/<cwd with / and . as ->
    dir = vim.fn.expand('~/.claude/projects/') .. vim.fn.substitute(c, '[/.]', '-', 'g')
  elseif cmd == 'pi' then        -- ~/.pi/agent/sessions/-<cwd+/ with / as ->-
    dir = vim.fn.expand('~/.pi/agent/sessions/-') .. vim.fn.substitute(c .. '/', '/', '-', 'g') .. '-'
  elseif cmd == 'omp' then       -- ~/.omp/agent/sessions/<$HOME-relative cwd, / as ->
    local home = vim.fn.substitute(vim.fn.expand('~'), '/$', '', '')
    local rel
    if c == home or vim.fn.stridx(c, home .. '/') == 0 then
      rel = string.sub(c, #home + 1)
    else
      rel = c
    end
    dir = vim.fn.expand('~/.omp/agent/sessions/') .. vim.fn.substitute(rel, '/', '-', 'g')
  else
    return false
  end
  return not vim.tbl_isempty(vim.fn.glob(dir .. '/*.jsonl', 1, 1))
end

-- Callable from the substitute() \= expression below via v:lua. Returns 1/0 so
-- the Vim ternary in that expression works unchanged.
function _G.__RestartHasSession(cmd, cwd)
  return has_session(cmd, cwd) and 1 or 0
end

-- A pane opened as a plain `:terminal` and then used to launch claude/pi by
-- hand records only the shell (term://cwd//PID:/bin/zsh) -- nvim never knew
-- about the child process. Look for a resumable CLI among the shell's
-- descendants and record that instead.
local function resumable_descendant(pid, depth)
  if depth > 3 then
    return ''
  end
  for _, kid in ipairs(vim.fn.split(vim.fn.system('pgrep -P ' .. vim.fn.shellescape(pid)), "\n")) do
    kid = vim.fn.trim(kid)
    if kid ~= '' then
      local name = vim.fn.fnamemodify(vim.fn.trim(vim.fn.system('ps -o comm= -p ' .. vim.fn.shellescape(kid))), ':t')
      if vim.fn.index(resumable, name) >= 0 then
        return name
      end
      local deeper = resumable_descendant(kid, depth + 1)
      if deeper ~= '' then
        return deeper
      end
    end
  end
  return ''
end

-- Returns {session-file buffer name -> replacement name}
local function terminal_overrides()
  local map = {}
  for _, b in ipairs(vim.fn.getbufinfo()) do
    if vim.fn.getbufvar(b.bufnr, '&buftype') == 'terminal' and b.name ~= '' then
      -- Already records a resumable CLI -- the normal path handles it
      if vim.fn.match(b.name, ':\\%(' .. table.concat(resumable, '\\|') .. '\\)\\>') < 0 then
        local pid = vim.fn.getbufvar(b.bufnr, 'terminal_job_pid', 0)
        local cmd = (pid == 0 or pid == '') and '' or resumable_descendant(pid, 0)
        if cmd ~= '' then
          local base = vim.fn.matchstr(b.name, '^term://.\\{-}//\\d\\+:')
          local cwd = vim.fn.matchstr(b.name, '^term://\\zs.\\{-}\\ze//\\d\\+:')
          map[b.name] = base .. cmd .. (has_session(cmd, cwd) and '\\ --continue' or '')
        end
      end
    end
  end
  return map
end

-- Rewrite resumable-CLI terminal commands in SESSION LINES to add --continue
-- wherever a saved session exists, with both fix-ups: the regex handles panes
-- launched as the CLI directly, terminal_overrides the shells running one as a
-- child. The \@! guard means a name already ending in --continue is left alone,
-- so re-saving a restored layout never stacks the flag.
local function resume_rewrite(lines)
  -- Terminal buffers are stored as  term://{cwd}//{pid}:{cmd}\ {args}
  local pattern = [[term://\(.\{-}\)//\d\+:\(]] .. table.concat(resumable, [[\|]])
    .. [[\)\%(\\ --continue\)\@!\ze\%(\\ \|\>\)]]
  local repl = [[\=submatch(0) . (v:lua.__RestartHasSession(submatch(2), submatch(1)) ? "\\ --continue" : "")]]
  for i, l in ipairs(lines) do
    lines[i] = vim.fn.substitute(l, pattern, repl, 'g')
  end
  -- Shell panes running a resumable CLI as a child (see terminal_overrides)
  for name, replacement in pairs(terminal_overrides()) do
    local from = vim.fn.escape(vim.fn.substitute(name, ' ', '\\\\ ', 'g'), '\\')
    for i, l in ipairs(lines) do
      lines[i] = vim.fn.substitute(l, '\\V' .. from, vim.fn.escape(replacement, '\\&~'), 'g')
    end
  end
  return lines
end

-- Patch a just-written session file in place. auto-session's post_save hook
-- passes it v:this_session, which mksession sets to the file it wrote.
function M.resume_patch(path)
  if path == nil or path == '' or vim.fn.filereadable(path) == 0 then
    return
  end
  vim.fn.writefile(resume_rewrite(vim.fn.readfile(path)), path)
end

-- Explorer pickers are scratch buffers and do not survive mksession: close
-- them (across all tabs) before a session is written. snacks schedules the
-- window teardown (picker/core/picker.lua M:close), so drain the event loop
-- until the sidebar windows are really gone -- otherwise mksession captures a
-- half-closed picker window as a spurious empty split. Returns whether any
-- explorer was open. Also used by auto-session's pre_save hook
-- (lua/plugins/sessions.lua).
function M.close_explorers()
  if not package.loaded['snacks'] then return false end
  local explorers = Snacks.picker.get({ source = 'explorer', tab = false })
  for _, p in ipairs(explorers) do p:close() end
  if #explorers > 0 then
    vim.wait(500, function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
        if ft:find('snacks_picker', 1, true) then
          return false
        end
      end
      return true
    end, 10)
  end
  return #explorers > 0
end

-- Paths of the currently-expanded explorer folders, so :Restart can reopen
-- exactly those on the fresh tree (the snacks Tree is per-process and comes
-- back collapsed after the re-exec). Walks the snacks.explorer.tree singleton;
-- pcall-guarded to return {} if the internals change.
function M.open_dirs()
  local dirs = {}
  pcall(function()
    local Tree = require("snacks.explorer.tree")
    Tree:walk(Tree.root, function(node)
      if node.dir and node.open and node.path and node.path ~= "" then
        dirs[#dirs + 1] = node.path
      end
    end)
  end)
  return dirs
end

-- Reopen the explorer and restore the pre-restart window sizes. mksession
-- records sizes AFTER the explorer is closed (the other panes expand to fill
-- the freed columns), and reopening the sidebar reflows them again -- so the
-- saved layout loses its widths. Re-apply the winrestcmd captured while the
-- explorer was still open, once the reopened sidebar window actually exists
-- (Snacks.explorer.open schedules the window, so poll briefly for it). Each
-- sub-command is pcall'd so a stale winnr (e.g. a transient float) can't abort
-- the rest. winrestcmd already double-passes to converge.
function M.restore_layout(winsizes, open_dirs)
  Snacks.explorer.open()
  local tries = 0
  local done = false
  local timer = (vim.uv or vim.loop).new_timer()
  timer:start(30, 30, vim.schedule_wrap(function()
    -- schedule_wrap defers each tick, so several can queue before the timer is
    -- stopped; the done guard makes the teardown+apply run exactly once.
    if done then
      return
    end
    tries = tries + 1
    local ready = false
    for _, w in ipairs(vim.api.nvim_list_wins()) do
      if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "snacks_picker_list" then
        ready = true
        break
      end
    end
    if ready or tries > 30 then
      done = true
      timer:stop()
      if not timer:is_closing() then
        timer:close()
      end
      if ready then
        -- Reopen the folders that were expanded before the restart. The snacks
        -- Tree is per-process and comes back collapsed after the re-exec, so
        -- re-open each saved path and re-render before sizing.
        if open_dirs and #open_dirs > 0 then
          pcall(function()
            local Tree = require("snacks.explorer.tree")
            for _, d in ipairs(open_dirs) do
              Tree:open(d)
            end
            local p = Snacks.picker.get({ source = "explorer" })[1]
            if p then
              require("snacks.explorer.actions").update(p, { refresh = true })
            end
          end)
        end
        for _, c in ipairs(vim.split(winsizes, "|", { trimempty = true })) do
          pcall(vim.cmd, c)
        end
        -- Clear any stale cells left by the re-exec + async resize.
        pcall(vim.cmd, "redraw!")
      end
    end
  end))
end

-- Write the session file, with the two fix-ups above applied.
function M.save()
  -- Close explorer sidebars first, remembering whether any were open so the
  -- session file can reopen one. Capture, before closing: the full-layout window
  -- sizes (explorer still open) and the set of expanded folders, both restored
  -- after the sidebar is reopened -- see M.restore_layout.
  local winsizes = vim.fn.winrestcmd()
  local open_dirs = M.open_dirs()
  -- Snacks terminals (lua/terminals.lua) don't survive mksession as managed
  -- windows -- capture which are open and which resumable CLI (claude/pi/omp)
  -- is running inside each, then wipe them so the session doesn't restore them
  -- as unmanaged (non-toggleable) plain terminals. Reopened after restore.
  local _term_states = require("terminals").open_state()
  local term_ids, term_cmds = {}, {}
  for _, ts in ipairs(_term_states) do
    term_ids[#term_ids + 1] = ts.id
    local pid = vim.fn.getbufvar(ts.bufnr, 'terminal_job_pid', 0)
    if pid and pid ~= 0 and pid ~= '' then
      local bname = vim.api.nvim_buf_get_name(ts.bufnr)
      local cwd = vim.fn.matchstr(bname, '^term://\\zs.\\{-}\\ze//\\d\\+:')
      local cli = resumable_descendant(pid, 0)
      if cli ~= '' then
        term_cmds[ts.id] = cli .. (has_session(cli, cwd) and ' --continue' or '')
      end
    end
  end
  local had_explorer = M.close_explorers()
  require("terminals").close_all()
  vim.cmd('mksession! ' .. vim.fn.fnameescape(session_file))
  local lines = resume_rewrite(vim.fn.readfile(session_file))
  -- The restore can leave an empty unnamed buffer listed but windowless -- an
  -- unwanted [No Name] tab. Sweep those.
  vim.list_extend(lines, {
    [[]],
    [[" added by :Restart -- drop empty unnamed buffers left by the restore]],
    [[for s:b in getbufinfo({"buflisted": 1})]],
    [[  if empty(s:b.name) && empty(s:b.windows) && !s:b.changed]],
    [[    silent! execute "bwipeout" s:b.bufnr]],
    [[  endif]],
    [[endfor]],
    [[unlet! s:b]],
  })
  if had_explorer then
    local parts = {}
    for _, d in ipairs(open_dirs) do
      parts[#parts + 1] = string.format("%q", d)
    end
    vim.list_extend(lines, {
      '',
      '" added by :Restart -- reopen the explorer, its expanded folders and pane sizes',
      'silent! lua require("restart").restore_layout([==[' .. winsizes .. ']==], {'
        .. table.concat(parts, ',') .. '})',
    })
  end
  -- Per-window buffer strips (lua/winbar.lua). Appended last so the lists
  -- resolve against the final buffer set.
  vim.list_extend(lines, require("winbar").session_lines())
  -- Reopen the snacks terminals that were open, as managed (toggleable) ones,
  -- resuming any claude/pi/omp sessions that were running inside them.
  if #term_ids > 0 then
    local cmds_lua = ''
    if not vim.tbl_isempty(term_cmds) then
      local kv = {}
      for id, cmd in pairs(term_cmds) do
        kv[#kv + 1] = '[' .. id .. ']=' .. string.format('%q', cmd)
      end
      cmds_lua = ',{' .. table.concat(kv, ',') .. '}'
    end
    vim.list_extend(lines, {
      '',
      '" added by :Restart -- reopen the snacks terminals (toggleable again)',
      'silent! lua require("terminals").reopen({' .. table.concat(term_ids, ',') .. '}' .. cmds_lua .. ')',
    })
  end
  -- Confirm the restore in the new instance, once the layout is back. Deferred
  -- so it lands after the synchronous restore (and reads as "done").
  local restored = had_explorer and 'layout, explorer and claude/pi/omp sessions'
    or 'layout and claude/pi/omp sessions'
  vim.list_extend(lines, {
    '',
    '" added by :Restart -- confirm the restore',
    'silent! lua vim.schedule(function() vim.notify("Restart complete: restored ' .. restored .. '", vim.log.levels.INFO, { title = "Restart" }) end)',
  })
  vim.fn.writefile(lines, session_file)
  return session_file
end

function M.run()
  vim.api.nvim_echo({
    { 'restart: restoring everything (layout, explorer, claude/pi/omp sessions)' },
  }, true, {})
  M.save()
  vim.fn.writefile({ tostring(vim.fn.localtime()) }, skip_flag)
  vim.cmd('restart source ' .. vim.fn.fnameescape(session_file))
end

return M
