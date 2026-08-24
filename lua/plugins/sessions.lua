-- Sessions. Ported from config/plugins.vim and init.vim section 9.
--
-- Saves the layout on exit and restores it when nvim starts in the same cwd
-- with no file arguments. The two cross-file hooks call into lua/winbar.lua and
-- lua/restart.lua via require().

return {
  {
    "rmagatti/auto-session",
    config = function()
      require('auto-session').setup {
        -- Explorer pickers are scratch buffers and do not survive a session:
        -- close them (across all tabs, with the scheduled window teardown
        -- drained) before saving. Like the old tree close, auto-session does
        -- NOT reopen the explorer on restore -- only :Restart does
        -- (lua/restart.lua).
        pre_save_cmds = {
          function() require('restart').close_explorers() end,
        },
        -- mksession cannot save the per-window buffer strips (lua/winbar.lua):
        -- 'sessionoptions' has no word for window-local variables. These lines go to
        -- the session's companion x.vim, which Vim sources once the layout is back
        -- (:h :mksession, step 10). Returning an empty list deletes any stale file.
        save_extra_cmds = { function() return require("winbar").session_lines() end },
        -- After each save, rewrite resumable-CLI terminal commands to add --continue,
        -- the same fix-up :Restart applies (lua/restart.lua): without it a plain
        -- quit and reopen relaunches claude/pi/omp fresh instead of resuming. mks!
        -- above has just set v:this_session to the file it wrote.
        post_save_cmds = {
          function() require("restart").resume_patch(vim.v.this_session) end,
        },
        -- Don't restore a session for a bare home/root directory
        suppressed_dirs = { '~/', '~/Downloads', '/' },
        -- :Restart (lua/restart.lua) leaves a sentinel before re-execing nvim.
        -- :restart starts with no file args, which is our auto-restore trigger, so
        -- without this BOTH sessions would load and every terminal would be spawned
        -- twice (two each of claude, pi and omp -- one set hidden but still running).
        pre_restore_cmds = {
          function()
            local flag = vim.fn.stdpath('state') .. '/restart-skip-autosession'
            if vim.fn.filereadable(flag) == 0 then
              return true                        -- normal start: restore as usual
            end
            local stamp = tonumber(vim.fn.readfile(flag)[1] or '') or 0
            vim.fn.delete(flag)                  -- one-shot; never block a later start
            if os.time() - stamp > 60 then
              return true                        -- stale flag (crash): restore anyway
            end
            return false                         -- :Restart will restore instead
          end,
        },
      }
    end,
  },
}
