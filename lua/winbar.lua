-- Per-window buffer strip, drawn in 'winbar'. Port of config/winbar.vim.
--
-- 'winbar' is the only bar Neovim draws per window, so it is the only
-- place a per-pane buffer list can go.
--
-- Each window keeps its own list in w:winbar_bufs, oldest first. Window-local
-- variables are not copied when a window splits, so a new pane starts with just
-- the buffer it was opened on rather than inheriting its neighbour's history.
--
-- Module M holds track/next/prev/drop/session_lines; the statusline callbacks
-- (WinbarRender/WinbarClick/WinbarClose/WinbarRestore) are _G globals because
-- 'winbar' and session files reach them by name (v:lua.*).

local M = {}

-- ---- Glyphs ----
-- nr2char keeps these correct without depending on how the source file is
-- read: nf-md-close (private-use) for the close marker, plain-Unicode BLACK
-- CIRCLE for the modified marker so it renders without a patched font.
local close_glyph = vim.fn.nr2char(0xF0156, 1)    -- nf-md-close, as keymaps.lua uses
local modified_glyph = vim.fn.nr2char(0x25CF, 1)  -- BLACK CIRCLE

-- ---- Colours ----
--
-- Icon colours come from nvim-web-devicons (get_icon_color). Highlight groups
-- are built on demand per colour, cached, and wiped on ColorScheme so the tab
-- background (TabLine / TabLineSel) tracks the theme. The modified marker
-- takes the theme's WarningMsg foreground.

local function tab_bg(sel)
  local bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(sel and 'TabLineSel' or 'TabLine')), 'bg#')
  return bg == '' and 'NONE' or bg
end

-- First non-empty foreground among the groups, so a theme that leaves
-- WarningMsg unset still yields a sensible marker colour.
local function group_fg(names)
  for _, n in ipairs(names) do
    local fg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID(n)), 'fg#')
    if fg ~= '' then
      return fg
    end
  end
  return ''
end

local function build_modified_hl()
  local fg = group_fg({ 'WarningMsg', 'DiffChange', 'Special', 'Statement' })
  for _, sel in ipairs({ false, true }) do
    vim.cmd(string.format('hi WinbarModified%s guibg=%s %s',
      sel and '_S' or '_N', tab_bg(sel),
      fg == '' and 'guifg=NONE' or ('guifg=' .. fg)))
  end
end

-- On-demand icon highlight groups, one per devicons colour and selection state
-- (WinbarIcon_<hex>_<S|N>, hex without '#'). Cached until the colourscheme
-- changes, when the cache is wiped and groups rebuild as they are asked for.
local hl_cache = {}
local function ensure_icon_hl(hex, sel)
  local key = hex .. (sel and '_S' or '_N')
  if not hl_cache[key] then
    vim.cmd(string.format('hi WinbarIcon_%s guifg=#%s guibg=%s', key, hex, tab_bg(sel)))
    hl_cache[key] = true
  end
  return 'WinbarIcon_' .. key
end

-- ---- Tracking ----

function M.track()
  -- No bar in plugin windows (explorer, pickers), terminals or quickfix. The
  -- test has to be on the option, not the rendered text: the bar exists
  -- whenever 'winbar' is non-empty, so returning an empty string from the
  -- function would still cost those windows a screen line. Snacks terminal
  -- splits own their winbar (title), so only clear OUR bar.
  if vim.fn.buflisted(vim.fn.bufnr('')) == 0 or vim.bo.buftype ~= '' then
    if vim.wo.winbar == '%!v:lua.WinbarRender()' then vim.wo.winbar = '' end
    return
  end
  vim.wo.winbar = '%!v:lua.WinbarRender()'
  -- Append only when new, never move an existing entry to the end. Order is
  -- first appearance, so a tab keeps its slot.
  local cur = vim.fn.bufnr('')
  local list = {}
  for _, b in ipairs(vim.w.winbar_bufs or {}) do
    if vim.fn.buflisted(b) == 1 then
      table.insert(list, b)
    end
  end
  local found = false
  for _, b in ipairs(list) do
    if b == cur then
      found = true
      break
    end
  end
  if not found then
    table.insert(list, cur)
  end
  vim.w.winbar_bufs = list
end

local grp = vim.api.nvim_create_augroup('winbar_bufs', { clear = true })
vim.api.nvim_create_autocmd({ 'BufWinEnter', 'BufEnter', 'WinEnter', 'TermOpen' }, {
  group = grp,
  pattern = '*',
  callback = function() M.track() end,
})
-- OptionSet catches the plugin windows: a picker or terminal buffer is often
-- still buftype-less at BufEnter and only becomes nofile a moment later.
vim.api.nvim_create_autocmd('OptionSet', {
  group = grp,
  pattern = 'buftype',
  callback = function() M.track() end,
})
-- Build highlight groups once the UI is up, and rebuild on every colourscheme
-- change, when explicit highlights are wiped and the tab background moves.
vim.api.nvim_create_autocmd('VimEnter', {
  group = grp,
  pattern = '*',
  callback = function() build_modified_hl() end,
})
vim.api.nvim_create_autocmd('ColorScheme', {
  group = grp,
  pattern = '*',
  callback = function()
    hl_cache = {}
    build_modified_hl()
  end,
})

-- ---- Drawing ----

-- Icon + colour from nvim-web-devicons. pcall-guarded so a missing plugin
-- degrades to a bare filename. With default = true every file gets an icon
-- and a colour (unknown types use devicons' default grey #6d8086).
local function icon(buf)
  local ok, devicons = pcall(require, 'nvim-web-devicons')
  if not ok then return nil, nil end
  local name = vim.fn.fnamemodify(vim.fn.bufname(buf), ':t')
  if name == '' then return nil, nil end
  return devicons.get_icon_color(name, vim.fn.fnamemodify(name, ':e'), { default = true })
end

function _G.WinbarRender()
  -- A '%!' expression is evaluated in the context of the *current* window, not
  -- the one being drawn, so a bare w: here would read the focused pane for every
  -- pane. g:statusline_winid names the window this bar belongs to.
  local win = vim.g.statusline_winid
  if win == nil or win == 0 then
    win = vim.fn.win_getid()
  end
  local cur = vim.fn.winbufnr(win)
  local out = ''
  for _, buf in ipairs(vim.fn.getwinvar(win, 'winbar_bufs', {})) do
    if vim.fn.buflisted(buf) == 1 then
      local sel = (buf == cur)
      local tab = sel and 'TabLineSel' or 'TabLine'
      local name = vim.fn.fnamemodify(vim.fn.bufname(buf), ':t')
      if name == '' then
        name = '[No Name]'
      end
      -- Icon coloured via its devicons colour; with default=true the colour is
      -- always set, so there is no uncoloured-icon branch.
      local ic, color = icon(buf)
      local label
      if not ic then
        label = name
      else
        label = string.format('%%#%s#%s%%#%s# %s', ensure_icon_hl(color:sub(2), sel), ic, tab, name)
      end
      -- Two click regions per tab, each ended with its own %X: the label
      -- switches to the buffer, the trailing glyph closes the tab. A modified
      -- buffer shows the dot in the theme's warning colour instead of the close
      -- glyph.
      local mark
      if vim.fn.getbufvar(buf, '&modified') == 1 then
        mark = string.format('%%#WinbarModified%s#%s%%#%s#', sel and '_S' or '_N', modified_glyph, tab)
      else
        mark = close_glyph
      end
      out = out .. '%#' .. tab .. '#'
        .. string.format('%%%d@v:lua.WinbarClick@ %s %%X', buf, label)
        .. string.format('%%%d@v:lua.WinbarClose@%s %%X', buf, mark)
    end
  end
  return out .. '%#TabLineFill#'
end

-- ---- Clicking ----
--
-- Left click switches, middle click closes. Closing drops the buffer from THIS
-- pane's strip only and leaves it loaded. Killing the buffer outright is
-- <C-q>'s job (lua/config/keymaps.lua). Which pane was clicked has to be asked
-- for via getmousepos().winid, not assumed.

local function filter_out(list, bufnr)
  local out = {}
  for _, b in ipairs(list or {}) do
    if b ~= bufnr then
      table.insert(out, b)
    end
  end
  return out
end

local function index_of(list, bufnr)
  for i, b in ipairs(list or {}) do
    if b == bufnr then
      return i - 1 -- 0-based, matching Vim's index()
    end
  end
  return -1
end

function _G.WinbarClick(minwid, clicks, button, mods)
  local win = vim.fn.getmousepos().winid
  if win <= 0 then
    return
  end
  if button == 'm' then
    M.drop(win, minwid)
  else
    vim.fn.win_gotoid(win)
    vim.cmd('buffer ' .. minwid)
  end
end

-- The close glyph at the right of each tab.
function _G.WinbarClose(minwid, clicks, button, mods)
  local win = vim.fn.getmousepos().winid
  if win <= 0 then
    return
  end
  M.drop(win, minwid)
end

function M.drop(win, bufnr)
  if vim.fn.win_id2win(win) == 0 then
    return
  end
  vim.fn.win_gotoid(win)
  if vim.fn.bufnr('') ~= bufnr then
    vim.w.winbar_bufs = filter_out(vim.w.winbar_bufs, bufnr)
    -- Nothing moved, so nothing would trigger a repaint on its own.
    vim.cmd('redrawstatus')
    return
  end
  -- Dropping the buffer on display means moving off it first. Land on the
  -- neighbour that slides into the closed tab's slot.
  local list = vim.w.winbar_bufs or {}
  local slot = index_of(list, bufnr)
  local rest = filter_out(list, bufnr)
  if #rest == 0 then
    vim.cmd('enew')
  else
    vim.cmd('buffer ' .. rest[math.min(slot, #rest - 1) + 1])
  end
  -- M.track ran on that switch and rebuilt the list with bufnr still in it.
  vim.w.winbar_bufs = filter_out(vim.w.winbar_bufs, bufnr)
end

-- ---- Cycling (<Tab> / <S-Tab>, mapped in lua/config/keymaps.lua) ----

local function cycle(step)
  local list = {}
  for _, b in ipairs(vim.w.winbar_bufs or {}) do
    if vim.fn.buflisted(b) == 1 then
      table.insert(list, b)
    end
  end
  local n = #list
  if n < 2 then
    return
  end
  -- Lua's % differs from Vim's truncation for negatives, so wrap explicitly:
  -- ((idx + step) % n + n) % n, indexed 1-based.
  local idx = index_of(list, vim.fn.bufnr('')) -- 0-based
  local target = ((idx + step) % n + n) % n
  vim.cmd('buffer ' .. list[target + 1])
end

-- Two named wrappers rather than one function taking a direction: which-key
-- matches its icon rules against the lowercased mapping description.
function M.next()
  cycle(1)
end

function M.prev()
  cycle(-1)
end

-- ---- Sessions ----
--
-- :mksession cannot carry these lists ('sessionoptions' has no word for
-- window-local variables), so lua/session.lua appends the lines below to the
-- session file it writes; they run after the whole layout is back.

function M.session_lines()
  local spec = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local names = {}
    for _, buf in ipairs(vim.fn.getwinvar(win, 'winbar_bufs', {})) do
      if vim.fn.buflisted(buf) == 1 and vim.fn.bufname(buf) ~= '' then
        table.insert(names, vim.fn.fnamemodify(vim.fn.bufname(buf), ':p'))
      end
    end
    -- Paths, not buffer numbers: numbers are handed out in load order and mean
    -- something different after the restart.
    local cur = vim.fn.bufname(vim.fn.winbufnr(win))
    -- One entry is whatever M.track would rebuild by itself, so only a real
    -- strip is worth writing down.
    if #names > 1 and cur ~= '' then
      table.insert(spec, { vim.fn.fnamemodify(cur, ':p'), names })
    end
  end
  if #spec == 0 then
    return {}
  end
  -- Old pre-migration session files reference a VimScript WinbarRestore behind
  -- an exists() guard, so they skip strip-restore once and re-save in this
  -- format. `silent!` degrades gracefully if v:lua.WinbarRestore is absent.
  return {
    '',
    '" added by session save -- rebuild the per-window buffer',
    '" strips (lua/winbar.lua), which mksession cannot carry.',
    'silent! call v:lua.WinbarRestore(' .. vim.fn.string(spec) .. ')',
  }
end

function _G.WinbarRestore(spec)
  local by_name = {}
  for _, buf in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    if buf.name ~= '' then
      by_name[buf.name] = buf.bufnr
    end
  end
  -- Windows are matched by the file they are showing, never by number: the
  -- explorer reopen closes and reopens its pane, which renumbers everything
  -- after it. Each window is claimed once.
  local claimed = {}
  for _, pair in ipairs(spec) do
    local cur, names = pair[1], pair[2]
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if not claimed[win]
        and vim.fn.fnamemodify(vim.fn.bufname(vim.fn.winbufnr(win)), ':p') == cur then
        local list = {}
        for _, name in ipairs(names) do
          local bn = by_name[name]
          if bn ~= nil then
            local present = false
            for _, x in ipairs(list) do
              if x == bn then
                present = true
                break
              end
            end
            if not present then
              table.insert(list, bn)
            end
          end
        end
        -- Whatever the session said, the window's own buffer belongs in its
        -- strip: the bar highlights it as the current tab.
        local wb = vim.fn.winbufnr(win)
        local has_wb = false
        for _, x in ipairs(list) do
          if x == wb then
            has_wb = true
            break
          end
        end
        if not has_wb then
          table.insert(list, wb)
        end
        vim.fn.setwinvar(win, 'winbar_bufs', list)
        claimed[win] = true
        break
      end
    end
  end
  vim.cmd('redrawstatus!')
end

return M
