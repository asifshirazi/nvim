" vim-airline -- the statusline and the buffer tabline.
"
" Sourced from init.vim section 5. Position is not load-bearing: these are all
" g: variables, read when airline's own plugin file is sourced, which happens
" after init.vim finishes either way.

let g:airline#extensions#tabline#enabled = 1                " buffer tabs in built-in tabline
let g:airline#extensions#tabline#formatter = 'unique_tail'  " filename only (path shown only on name clashes)
let g:airline_powerline_fonts = 1                           " powerline glyphs (needs Nerd font)
" Airline enables its xkblayout (keyboard-layout) extension for any nvim, and
" its status() then calls luaeval('require"ime".current()') -- a module we
" don't have, which throws E5108 on redraw. Nothing here uses it.
let g:airline#extensions#xkblayout#enabled = 0
" Commented on purpose: setting this at all disables airline's colorscheme
" matching (plugin/airline.vim:24). Uncomment only to pin one theme.
"let g:airline_theme = 'onedark'
