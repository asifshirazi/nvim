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

-- Write the session file, with the two fix-ups above applied.
function M.save()
  -- Close explorer sidebars first, remembering whether any were open so the
  -- session file can reopen one. Expanded-folder state is not restored -- the
  -- reopened sidebar starts at the cwd root.
  local had_explorer = M.close_explorers()
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
    vim.list_extend(lines, {
      '',
      '" added by :Restart -- reopen the explorer sidebar',
      'silent! lua Snacks.explorer.open()',
    })
  end
  -- Per-window buffer strips (lua/winbar.lua). Appended last so the lists
  -- resolve against the final buffer set.
  vim.list_extend(lines, require("winbar").session_lines())
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
