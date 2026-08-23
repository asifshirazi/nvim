" NERDTree and its icon/highlight companions. Sourced from init.vim section 7.
"
" Must be sourced IN PLACE, not at the top of init.vim: s:NeutralTreeNames()
" calls `hi link` immediately, so the colorscheme from sections 3 and 6 has to
" be applied first.

" ---- NERDTree (toggled with <C-t>, see keybinds.vim) ----
let g:NERDTreeWinPos = 'left'            " sidebar side: 'left' or 'right'
let g:NERDTreeWinSize = 22               " sidebar width in columns
let g:NERDTreeShowHidden = 1             " show dotfiles by default (toggle with I)
let g:NERDTreeMinimalUI = 1              " hide the '? for help' header
let g:NERDTreeShowLineNumbers = 0        " no line numbers in the tree
let g:NERDTreeAutoDeleteBuffer = 1       " delete the buffer of a file removed in the tree
let g:NERDTreeQuitOnOpen = 0             " set to 1 to auto-close the tree after opening a file
" Straight from the Nerd Font, no icon plugin involved. DOUBLE quotes are
" required: in single quotes Vim takes \u literally and you get the six
" characters \uf44d on screen. Single character each (NERDTree.txt:1281).
let g:NERDTreeDirArrowExpandable = "\uf44d"   " closed directory (nf-oct-plus)
let g:NERDTreeDirArrowCollapsible = "\uf068"  " open directory   (nf-fa-minus)
let g:NERDTreeLimitedSyntax = 1          " colour only common extensions -- keeps large trees fast
"let g:NERDTreeChDirMode = 2             " uncomment to :cd into the tree root as you browse

" ---- NERDTree icons (vim-devicons) ----
" The icon is rendered as a NERDTree flag: '[ icon ]'. The brackets are concealed
" (vim-devicons conceals them by default); these two control the
" padding *inside* them -- set either to '' to tighten the spacing.
let g:WebDevIconsNerdTreeBeforeGlyphPadding = ''  " gap between arrow and icon
let g:WebDevIconsNerdTreeAfterGlyphPadding = ' '   " gap between icon and filename
let g:WebDevIconsUnicodeDecorateFolderNodes = 1  " uncomment for icons on directories too
let g:DevIconsEnableFoldersOpenClose = 1         " ...with distinct open/closed folder glyphs
let g:NERDTreeHighlightFolders = 1

" NERDTree links its own name groups to Directory/Identifier with `hi def link`
" (syntax/nerdtree.vim:84,66). `def` means default, so an explicit link wins.
" Applied twice on purpose: once now, because section 3's `colorscheme` has
" already run and the autocmd below would never fire for it; and again on every
" ColorScheme, because switching theme via <leader>h wipes explicit highlights.
" The arrows are NOT affected -- they link to Directory, not to NERDTreeDir.
function! s:NeutralTreeNames() abort
  hi link NERDTreeDir Normal
  hi link NERDTreeDirSlash Normal
endfunction
call s:NeutralTreeNames()
augroup nerdtree_neutral_names
  autocmd!
  autocmd ColorScheme * call s:NeutralTreeNames()
augroup END

" Don't let devicons force its default green/white symbol colours
let g:WebDevIconsDisableDefaultFolderSymbolColorFromNERDTreeDir = 0
let g:WebDevIconsDisableDefaultFileSymbolColorFromNERDTreeFile = 0

" Close Vim if NERDTree is the only window left (a regular :NERDTree is a
" 'window'-type tree; 'tab'-type is the pinned-in-tab variant)
autocmd BufEnter * if winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isWinTree() | quit | endif
