-- Session management: save the layout (files, windows, explorer, per-window
-- buffer strips, toggleable terminals, and the active colorscheme) and restore
--
-- Restore works by generating a session file: :mksession captures tabs, windows
-- and buffers, then fix-up lines are appended that rebuild what mksession can't
-- carry -- the snacks explorer, the winbar strips, and the snacks terminals --
-- and that resume claude/pi/omp/btop where they left off. The same generated
-- file also backs the restart command, which re-execs nvim and sources it.

local M = {}

local session_file = vim.fn.stdpath('state') .. '/restart-session.vim'
-- Commands worth restoring in a terminal. claude/pi/omp resume via --continue
-- when a saved session exists (has_session); btop and any other entry just
-- relaunch (has_session returns false, so no flag is appended).
local resumable = { 'claude', 'pi', 'omp', 'btop' }
-- Sentinel the restart command drops before re-execing, so the launch after the
-- re-exec restores from the global file only and does not ALSO restore the
-- per-cwd session (double restore). See M.run and M.setup's VimEnter handler.
local skip_flag = vim.fn.stdpath('state') .. '/restart-skip-autosession'

-- claude/pi/omp store sessions per working directory, under a mangled directory
-- name. Passing --continue with no saved session makes them abort, so only add
-- the flag when one actually exists. Any other command (e.g. btop) has no
-- session store and falls through to the else branch -> false, so it just
-- relaunches.
local function has_session(cmd, cwd)
  -- cmd may carry args (e.g. "claude --model opus"); match on the binary only.
  local bin = vim.fn.matchstr(cmd, [[^\S\+]])
  local c = vim.fn.fnamemodify(vim.fn.expand(cwd), ':p:h')
  local dir
  if bin == 'claude' then        -- ~/.claude/projects/<cwd with / and . as ->
    dir = vim.fn.expand('~/.claude/projects/') .. vim.fn.substitute(c, '[/.]', '-', 'g')
  elseif bin == 'pi' then        -- ~/.pi/agent/sessions/-<cwd+/ with / as ->-
    dir = vim.fn.expand('~/.pi/agent/sessions/-') .. vim.fn.substitute(c .. '/', '/', '-', 'g') .. '-'
  elseif bin == 'omp' then       -- ~/.omp/agent/sessions/<$HOME-relative cwd, / as ->
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
function _G.__SessionHasSession(cmd, cwd)
  return has_session(cmd, cwd) and 1 or 0
end

-- A pane opened as a plain `:terminal` and then used to launch claude/pi/btop
-- by hand records only the shell (term://cwd//PID:/bin/zsh) -- nvim never knew
-- about the child process. Look for a known command among the shell's
-- descendants and record its FULL command line (binary basenamed, flags kept),
-- so e.g. `btop -p 0` is restored with its flags, not bare `btop`.
local function resumable_descendant(pid, depth)
  if depth > 3 then
    return ''
  end
  for _, kid in ipairs(vim.fn.split(vim.fn.system('pgrep -P ' .. vim.fn.shellescape(pid)), "\n")) do
    kid = vim.fn.trim(kid)
    if kid ~= '' then
      -- 'command=' gives the full argv (binary + flags); 'comm=' would drop flags.
      local full = vim.fn.trim(vim.fn.system('ps -o command= -p ' .. vim.fn.shellescape(kid)))
      if full ~= '' then
        local first = vim.fn.matchstr(full, [[^\S\+]])          -- binary, maybe a full path
        local name = vim.fn.fnamemodify(first, ':t')            -- basename for matching
        if vim.fn.index(resumable, name) >= 0 then
          return name .. string.sub(full, #first + 1)           -- basename + " flags..."
        end
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
          -- In a term:// buffer name, argv separators are backslash-escaped
          -- spaces, so escape the flags cmd now carries before splicing it in.
          local escaped = cmd:gsub(' ', '\\ ')
          map[b.name] = base .. escaped .. (has_session(cmd, cwd) and '\\ --continue' or '')
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
  local repl = [[\=submatch(0) . (v:lua.__SessionHasSession(submatch(2), submatch(1)) ? "\\ --continue" : "")]]
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

-- Patch a just-written session file in place, adding --continue to resumable
-- terminal commands. Callers pass the file mksession just wrote.
function M.resume_patch(path)
  if path == nil or path == '' or vim.fn.filereadable(path) == 0 then
    return
  end
  vim.fn.writefile(resume_rewrite(vim.fn.readfile(path)), path)
end

-- Capture snacks terminals and what resumable CLI each is running. Returns
-- { ids = [...], cmds = {[id] = 'cmd --continue'} }. include_hidden picks
-- all_state (toggled-off terminals too) over open_state (visible only).
local function capture_terminals(include_hidden)
  local terminals = require("terminals")
  local states = include_hidden and terminals.all_state() or terminals.open_state()
  local ids, cmds = {}, {}
  for _, ts in ipairs(states) do
    ids[#ids + 1] = ts.id
    local pid = vim.fn.getbufvar(ts.bufnr, 'terminal_job_pid', 0)
    if pid and pid ~= 0 and pid ~= '' then
      local bname = vim.api.nvim_buf_get_name(ts.bufnr)
      local cwd = vim.fn.matchstr(bname, '^term://\\zs.\\{-}\\ze//\\d\\+:')
      local cli = resumable_descendant(pid, 0)
      if cli ~= '' then
        cmds[ts.id] = cli .. (has_session(cli, cwd) and ' --continue' or '')
      end
    end
  end
  return { ids = ids, cmds = cmds }
end

-- Explorer pickers are scratch buffers and do not survive mksession. Only a
-- bare p:close is safe here: force-deleting the buffer, force-closing the
-- window, or draining with vim.wait all HANG the quit when the picker is the
-- focused window on ExitPre (the scheduled teardown can't complete mid-exit).
--
-- p:close only schedules the teardown, so mksession still captures the sidebar
-- as a spurious empty window. That residue is cleaned on the restore side by
-- restore_layout (close_empty_windows), not here. Returns whether any explorer
-- was open.
function M.close_explorers()
  if not package.loaded['snacks'] then return false end
  local explorers = Snacks.picker.get({ source = 'explorer', tab = false })
  for _, p in ipairs(explorers) do pcall(function() p:close() end) end
  return #explorers > 0
end

-- Paths of the currently-expanded explorer folders, so restore can reopen
-- exactly those on the fresh tree (the snacks Tree is per-process and comes
-- back collapsed). Walks the snacks.explorer.tree singleton; pcall-guarded to
-- return {} if the internals change.
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

-- Close windows showing an empty, unnamed, unmodified buffer -- the residue
-- mksession leaves where the explorer sidebar was (p:close only scheduled its
-- teardown, so the closed sidebar was captured as an empty split). Skipped for
-- floats and never closes the last window. Used by restore_layout after the
-- real explorer is reopened, so the restored layout has no leftover empty pane.
local function close_empty_windows()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if #vim.api.nvim_list_wins() <= 1 then break end
    if vim.api.nvim_win_is_valid(w) and vim.api.nvim_win_get_config(w).relative == '' then
      local b = vim.api.nvim_win_get_buf(w)
      local empty = vim.api.nvim_buf_get_name(b) == ''
        and vim.bo[b].buftype == ''
        and not vim.bo[b].modified
        and vim.api.nvim_buf_line_count(b) <= 1
        and (vim.api.nvim_buf_get_lines(b, 0, 1, false)[1] or '') == ''
      if empty then
        pcall(vim.api.nvim_win_close, w, false)
      end
    end
  end
end

-- Reopen the explorer and restore the saved window sizes. mksession records
-- sizes AFTER the explorer is closed (the other panes expand to fill the freed
-- columns), and reopening the sidebar reflows them again -- so the saved layout
-- loses its widths. Re-apply the winrestcmd captured while the explorer was
-- still open, once the reopened sidebar window actually exists (Snacks.explorer
-- .open schedules the window, so poll briefly for it). Each sub-command is
-- pcall'd so a stale winnr (e.g. a transient float) can't abort the rest.
function M.restore_layout(winsizes, open_dirs)
  -- The window mksession left focused is a real file window. Snacks.explorer.open
  -- steals focus to the sidebar, so remember it and hand focus back at the end --
  -- restore should land on the file, not the tree.
  local file_win = vim.api.nvim_get_current_win()
  Snacks.explorer.open()
  local tries = 0
  local done = false
  local timer = vim.uv.new_timer()
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
        -- Reopen the folders that were expanded before. The snacks Tree is
        -- per-process and comes back collapsed, so re-open each saved path and
        -- re-render before sizing.
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
        -- Remove the empty split mksession left where the sidebar was, before
        -- sizing -- so winsizes apply to the real (explorer+file+terminals) set.
        close_empty_windows()
        -- Empty winsizes means the session file already carries correct sizes;
        -- re-applying stale ones with different window numbers clobbers them.
        if winsizes and winsizes ~= '' then
          for _, c in ipairs(vim.split(winsizes, "|", { trimempty = true })) do
            pcall(vim.cmd, c)
          end
        end
        pcall(vim.cmd, "redraw!")
        -- Hand focus back to the file window (the explorer/terminal reopens
        -- stole it). Fall back to any listed file window if the original is gone.
        if vim.api.nvim_win_is_valid(file_win)
          and vim.bo[vim.api.nvim_win_get_buf(file_win)].buftype == '' then
          pcall(vim.api.nvim_set_current_win, file_win)
        else
          for _, w in ipairs(vim.api.nvim_list_wins()) do
            local b = vim.api.nvim_win_get_buf(w)
            if vim.bo[b].buftype == '' and vim.bo[b].buflisted then
              pcall(vim.api.nvim_set_current_win, w)
              break
            end
          end
        end
      end
    end
  end))
end

-- Append the restore fix-up lines to a captured session: [No Name] sweep,
-- explorer reopen (+ pane sizes), winbar strips, snacks-terminal reopen, and an
-- optional confirmation notify. Shared by the restart-command save and the
-- per-cwd session save below.
local function append_restore(lines, o)
  -- The restore can leave an empty unnamed buffer listed but windowless -- an
  -- unwanted [No Name] tab. Sweep those.
  vim.list_extend(lines, {
    [[]],
    [[" added by session save -- drop empty unnamed buffers left by the restore]],
    [[for s:b in getbufinfo({"buflisted": 1})]],
    [[  if empty(s:b.name) && empty(s:b.windows) && !s:b.changed]],
    [[    silent! execute "bwipeout" s:b.bufnr]],
    [[  endif]],
    [[endfor]],
    [[unlet! s:b]],
  })
  -- Restore the active colorscheme. The picker commits a pick only for the
  -- session, so without this a quit-reopen or :RestartRestoreSession would snap
  -- back to the default (lua/plugins/colorschemes.lua). background is
  -- forced after the scheme loads, to reproduce exactly what was on screen --
  -- some schemes (e.g. modus_operandi) render light without setting it.
  local scheme = vim.g.colors_name
  if scheme and scheme ~= '' then
    vim.list_extend(lines, {
      '',
      '" added by session save -- restore the active colorscheme',
      'silent! colorscheme ' .. scheme,
      'silent! set background=' .. vim.o.background,
    })
  end
  if o.had_explorer then
    local parts = {}
    for _, d in ipairs(o.open_dirs or {}) do
      parts[#parts + 1] = string.format("%q", d)
    end
    vim.list_extend(lines, {
      '',
      '" added by session save -- reopen the explorer, its expanded folders and pane sizes',
      'silent! lua require("session").restore_layout([==[' .. (o.winsizes or '') .. ']==], {'
        .. table.concat(parts, ',') .. '})',
    })
  end
  -- Per-window buffer strips (lua/winbar.lua). Appended after the layout is
  -- back so the lists resolve against the final buffer set.
  vim.list_extend(lines, require("winbar").session_lines())
  -- Reopen snacks terminals as managed (toggleable) ones, resuming any
  -- claude/pi/omp session that was running inside each. Skipped by the light
  -- periodic save, which leaves terminals running and lets mksession capture
  -- them as plain resumable term:// panes instead.
  if o.term_ids and #o.term_ids > 0 then
    local cmds_lua = ''
    if o.term_cmds and not vim.tbl_isempty(o.term_cmds) then
      local kv = {}
      for id, cmd in pairs(o.term_cmds) do
        kv[#kv + 1] = '[' .. id .. ']=' .. string.format('%q', cmd)
      end
      cmds_lua = ',{' .. table.concat(kv, ',') .. '}'
    end
    vim.list_extend(lines, {
      '',
      '" added by session save -- reopen the snacks terminals (toggleable again)',
      'silent! lua require("terminals").reopen({' .. table.concat(o.term_ids, ',') .. '}' .. cmds_lua .. ')',
    })
  end
  if o.notify then
    vim.list_extend(lines, {
      '',
      '" added by session save -- confirm the restore',
      'silent! lua vim.schedule(function() vim.notify("Session restored", vim.log.levels.INFO, { title = "Session" }) end)',
    })
  end
  return lines
end

-- Capture, close, mksession, patch, append -- the common write path. Uses
-- `term` (from open_state or all_state) for the terminals to reopen, writes
-- `path`, and returns the captured { winsizes, open_dirs, had_explorer } so a
-- live caller can reopen what it closed.
local function write_session(path, term, notify)
  local winsizes = vim.fn.winrestcmd()
  local open_dirs = M.open_dirs()
  local had_explorer = M.close_explorers()
  require("terminals").close_all()
  vim.cmd('mksession! ' .. vim.fn.fnameescape(path))
  local lines = resume_rewrite(vim.fn.readfile(path))
  append_restore(lines, {
    winsizes = winsizes, open_dirs = open_dirs, had_explorer = had_explorer,
    term_ids = term.ids, term_cmds = term.cmds, notify = notify,
  })
  vim.fn.writefile(lines, path)
  return { winsizes = winsizes, open_dirs = open_dirs, had_explorer = had_explorer }
end

-- The restart command's save: global file, visible terminals only, confirmation
-- notify. The re-exec kills everything, so nothing is reopened here -- the
-- session file does it all on source.
function M.save()
  local term = capture_terminals(false)  -- visible terminals only
  write_session(session_file, term, true)
  return session_file
end

function M.run()
  vim.api.nvim_echo({ { 'restart: restoring session' } }, true, {})
  M.save()
  vim.fn.writefile({ tostring(vim.fn.localtime()) }, skip_flag)
  vim.cmd('restart source ' .. vim.fn.fnameescape(session_file))
end

-- ============================================================================
-- Per-cwd sessions: saved on quit (ExitPre) and periodically, restored on
-- launch. Reuses the machinery above, so a plain quit + reopen restores the
-- same layout the restart command does.
-- ============================================================================

local sessions_dir = vim.fn.stdpath('state') .. '/sessions'
-- Bare home/root dirs never get a session.
local suppressed = {
  vim.fn.fnamemodify(vim.fn.expand('~'), ':p:h'),
  vim.fn.fnamemodify(vim.fn.expand('~/Downloads'), ':p:h'),
  '/',
}

-- Per-cwd session file, or nil for a suppressed dir. cwd is percent-encoded
-- so it survives as a single flat filename.
function M.session_path()
  local cwd = vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h')
  for _, s in ipairs(suppressed) do
    if cwd == s then return nil end
  end
  local enc = cwd:gsub('[^%w%-_]', function(ch)
    return string.format('%%%02X', string.byte(ch))
  end)
  vim.fn.mkdir(sessions_dir, 'p')
  return sessions_dir .. '/' .. enc .. '.vim'
end

-- True if the current layout is worth saving: at least one named buffer or a
-- snacks terminal. Prevents a failed/empty restore (single [No Name]) from
-- overwriting a good session on the next quit.
local function worth_saving()
  if #require("terminals").all_state() > 0 then return true end
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.name ~= '' then return true end
  end
  return false
end

-- Full save for a normal quit (ExitPre): close explorer + terminals, write the
-- per-cwd file with toggleable-terminal reopen lines. No reopen here (nvim is
-- exiting). close_explorers uses a bare p:close (safe on ExitPre); the empty
-- split it leaves is cleaned by restore_layout on the next launch.
function M.save_cwd()
  local path = M.session_path()
  if not path or not worth_saving() then return end
  write_session(path, capture_terminals(true), false)  -- include hidden terminals
end

-- Lightweight periodic save for crash recovery. Fully non-destructive: it never
-- closes the explorer or terminals and never moves focus -- doing any of that
-- every interval would yank the cursor to a file window and reset the sidebar.
-- Focus is only handed to the file window on a real load/restart (restore_cwd /
-- the restart command), never here. mksession captures the live layout as-is
-- (an open explorer becomes an empty split), and restore_layout's
-- close_empty_windows cleans that residue on the next launch. Guarded against
-- the command-line window, where mksession throws.
function M.save_cwd_light()
  if vim.fn.getcmdwintype() ~= '' then return false end
  local path = M.session_path()
  if not path or not worth_saving() then return false end
  local had_explorer = false
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if vim.bo[vim.api.nvim_win_get_buf(w)].filetype:find('snacks_picker', 1, true) then
      had_explorer = true
      break
    end
  end
  local winsizes = vim.fn.winrestcmd()
  local open_dirs = M.open_dirs()
  local ok = pcall(vim.cmd, 'mksession! ' .. vim.fn.fnameescape(path))
  if ok then
    local lines = resume_rewrite(vim.fn.readfile(path))
    append_restore(lines, { winsizes = winsizes, open_dirs = open_dirs, had_explorer = had_explorer })
    vim.fn.writefile(lines, path)
  end
  return ok
end

-- :SessionSave -- manual checkpoint. Uses the light (non-destructive) save so
-- it never kills a running claude/omp/btop; the quit save (ExitPre) still does
-- the full toggleable-terminal save.
function M.save_now()
  local path = M.session_path()
  if not path then
    vim.notify('No session for this directory (suppressed)', vim.log.levels.WARN, { title = 'Session' })
    return
  end
  if M.save_cwd_light() then
    vim.notify('Session saved', vim.log.levels.INFO, { title = 'Session' })
  else
    vim.notify('Nothing to save for this directory', vim.log.levels.WARN, { title = 'Session' })
  end
end

-- :SessionDelete -- remove the current directory's saved session and reset to
-- a clean slate: close the explorer + terminals, collapse to one window, park
-- on a fresh blank buffer, wipe the previous unmodified buffers (modified ones
-- are kept so no unsaved work is lost), then open the snacks dashboard -- or
-- stay on the blank buffer if the dashboard is disabled/unavailable.
function M.delete_session()
  local path = M.session_path()
  local existed = path and vim.fn.filereadable(path) == 1
  if existed then vim.fn.delete(path) end
  pcall(function() M.close_explorers() end)
  pcall(function() require("terminals").close_all() end)
  pcall(vim.cmd, 'silent! only')
  pcall(vim.cmd, 'enew')  -- park on a blank buffer before wiping the old ones
  local keep = vim.api.nvim_get_current_buf()
  for _, b in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if b.changed == 0 and b.bufnr ~= keep then
      pcall(vim.api.nvim_buf_delete, b.bufnr, {})
    end
  end
  -- Dashboard when enabled; otherwise the blank buffer above is the end state.
  if (Snacks.config.dashboard or {}).enabled ~= false then
    pcall(function() Snacks.dashboard.open() end)
  end
  vim.notify('Session removed', vim.log.levels.INFO, { title = 'Session' })
end

-- Source the per-cwd session file if one exists, then announce it. Deferred so
-- the message lands after the async layout restore (restore_layout's timer).
function M.restore_cwd()
  local path = M.session_path()
  if not path or vim.fn.filereadable(path) == 0 then return end
  vim.cmd('silent! source ' .. vim.fn.fnameescape(path))
  vim.defer_fn(function()
    -- Skip the stale "restored" toast if the session was deleted (:SessionDelete)
    -- or we've since landed on the dashboard -- both mean nothing is restored now.
    if vim.fn.filereadable(path) == 0 then return end
    if vim.bo[vim.api.nvim_get_current_buf()].filetype == 'snacks_dashboard' then return end
    vim.notify('Session restored', vim.log.levels.INFO, { title = 'Session' })
  end, 200)
end

-- Register the autocmds and periodic timer. Called once from init.lua.
function M.setup()
  local grp = vim.api.nvim_create_augroup('session', { clear = true })
  -- Restore on a clean launch (no file args). The restart command re-execs and
  -- sources its own global file, dropping the skip flag first -- honour it so
  -- this launch does not also source the per-cwd file (double restore).
  vim.api.nvim_create_autocmd('VimEnter', {
    group = grp, nested = true,
    callback = function()
      if vim.fn.argc(-1) > 0 then return end
      if vim.fn.filereadable(skip_flag) == 1 then
        local stamp = tonumber(vim.fn.readfile(skip_flag)[1] or '') or 0
        vim.fn.delete(skip_flag)
        if (os.time() - stamp) <= 60 then return end
      end
      -- Deferred via a short timer, not vim.schedule: at VimEnter the snacks
      -- dashboard still opens (on a scheduled tick) and would clobber the
      -- restore. An 80ms timer lands restore_cwd after the dashboard and other
      -- startup handlers have settled, so the restored layout is the last word.
      local t = vim.uv.new_timer()
      t:start(80, 0, vim.schedule_wrap(function()
        t:stop()
        if not t:is_closing() then t:close() end
        M.restore_cwd()
      end))
    end,
  })
  -- Save on ExitPre, NOT VimLeavePre: by VimLeavePre the snacks terminal
  -- buffers are already torn down, so a VimLeavePre save captures no terminals.
  -- ExitPre fires earlier, while they are still alive.
  vim.api.nvim_create_autocmd('ExitPre', {
    group = grp,
    callback = function() pcall(M.save_cwd) end,
  })
  -- Periodic crash-recovery save (non-destructive to terminals).
  local timer = vim.uv.new_timer()
  timer:start(60000, 60000, vim.schedule_wrap(function() pcall(M.save_cwd_light) end))
end

return M
