" Setup window local variables for quickfix and location list windows


lua require'qf'.on_ft()

" setlocal nobuflisted
" setlocal nonumber
" setlocal norelativenumber

" " Determine if current window is location list or quickfix list
" let b:list = get(get(getwininfo(win_getid()), 0, {}), 'loclist', 0) ? 'l' : 'c'

" if luaeval("require'qf'.config." . b:list . ".wide_bottom") == v:true
"   wincmd J
" endif

" let height = luaeval("require'qf'.get_height('" . b:list . "')")
