-- whleucka/reverb.nvim -- sound effects bound to autocmd events.
--
-- reverb maps an autocmd event to a sound file and plays it through an external
-- player when the event fires. Options are passed as `opts`; lazy calls
-- require("reverb").setup(opts). Toggle at runtime with :ReverbToggle (also
-- :ReverbEnable / :ReverbDisable).
--
-- Player note: reverb supports ONLY paplay, pw-play and mpv. paplay and pw-play
-- are Linux audio daemons (PulseAudio / PipeWire); on macOS the only usable one
-- is mpv -- `brew install mpv`. afplay (the macOS built-in) is not supported
-- upstream. It spawns a player process per sound, so onset is not instant.
--
-- reverb ships no sounds; drop .ogg/.mp3 files under <config>/sounds/ (free CC0
-- interface sounds: https://www.kenney.nl/assets/interface-sounds) and wire them
-- into `sounds` below (event -> { path, volume = 0-100, pattern? }).
local sound_dir = vim.fn.stdpath("config") .. "/sounds/"

return {
  {
    "whleucka/reverb.nvim",
    opts = {
      player = "mpv",
      max_sounds = 20,
      sounds = {
        BufRead = { path = sound_dir .. "click_003.ogg", volume = 45 },
        BufWrite = { path = sound_dir .. "glass_004.ogg", volume = 60 },
        -- Entering the : command line (pattern scopes to ":", so / and ? search
        -- do not trigger it).
        CmdlineEnter = { path = sound_dir .. "drop_001.ogg", volume = 45, pattern = ":" },
        -- Applying a colorscheme (the \h picker applies each theme live as you
        -- scroll, so this fires on every selection there -- and once at startup
        -- / session restore when the saved theme loads).
        ColorScheme = { path = sound_dir .. "select_008.ogg", volume = 55 },
        -- A snacks picker opening: every picker (files, grep, git, colorschemes,
        -- explorer, ...) creates a list window with filetype snacks_picker_list,
        -- and that FileType fires once per open.
        FileType = { path = sound_dir .. "glass_006.ogg", volume = 55, pattern = "snacks_picker_list" },
        -- Notifications are not autocmd events, so they are bridged into these
        -- User events by the config function below: every notification fires
        -- `User ReverbNotify`, and error-level ones fire `User ReverbNotifyError`
        -- instead -- a distinct sound.
        User = {
          { path = sound_dir .. "bong_001.ogg", volume = 55, pattern = "ReverbNotify" },
          { path = sound_dir .. "error_001.ogg", volume = 65, pattern = "ReverbNotifyError" },
          { path = sound_dir .. "select_008.ogg", volume = 55, pattern = "ReverbWhichKey" },
        },
      },
    },
    config = function(_, opts)
      require("reverb").setup(opts)
      -- Bridge things that are NOT autocmd events into reverb's User events, on
      -- VimEnter so the relevant modules are initialised.
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          -- Notifications. Do NOT wrap vim.notify (noice owns it and errors when
          -- replaced). noice renders through the snacks notifier, calling
          -- Snacks.notifier.notify(msg, level, opts) -- wrap that. Fires
          -- `User ReverbNotify`, or `User ReverbNotifyError` for error level.
          if _G.Snacks and Snacks.notifier and type(Snacks.notifier.notify) == "function" then
            local notify = Snacks.notifier.notify
            Snacks.notifier.notify = function(msg, level, o)
              local is_err = level == vim.log.levels.ERROR
                or (type(level) == "string" and level:lower() == "error")
              pcall(vim.api.nvim_exec_autocmds, "User",
                { pattern = is_err and "ReverbNotifyError" or "ReverbNotify" })
              return notify(msg, level, o)
            end
          end
          -- which-key opens its window under eventignore="all", so no autocmd
          -- sees it. Patch which-key.win.show to fire `User ReverbWhichKey` when a
          -- FRESH window is created (self:valid() false) -- not on the per-keystroke
          -- updates while the popup stays open.
          local ok, Win = pcall(require, "which-key.win")
          if ok and type(Win.show) == "function" then
            local show = Win.show
            Win.show = function(self, o)
              if not self:valid() then
                pcall(vim.api.nvim_exec_autocmds, "User", { pattern = "ReverbWhichKey" })
              end
              return show(self, o)
            end
          end
        end,
      })
    end,
  },
}
