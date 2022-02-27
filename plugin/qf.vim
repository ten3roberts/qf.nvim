" === QUICKFIX ===

" Opens the quickfix list
command! -nargs=* Qopen   lua require'qf'.open('c', <q-args>)
" Qlose the quickfix list
command! -nargs=* Qclose  lua require'qf'.close('c', <q-args>)
" Toggle the quickfix list
command! -nargs=* Qtoggle lua require'qf'.close('c', <q-args>)
" Qlear the contents of quickfix list
command! -nargs=* Qclear  lua require'qf'.clear('c', <q-args>)

" Move to the next item in quickfix list and wrap around.
" Second argument denotes wrap>
command! -nargs=* Qnext   lua require'qf'.next('c', <q-args>)
" Move to the previous item in quickfix list.
" Second argument denotes wrap>
command! -nargs=* Qprev   lua require'qf'.prev('c', <q-args>)
" Move to the previous item in quickfix list.
" Second argument denotes wrap>
command! -nargs=* Qabove  lua require'qf'.above('c', <q-args>)
" Move to the previous item in quickfix list.
" Second argument denotes wrap>
command! -nargs=* Qbelow  lua require'qf'.below('c', <q-args>)

" Save the quickfix list
command! -nargs=* Qsave   lua require'qf'.save('c', <q-args>)
" Load a saved quickfix list
command! -nargs=* Qload   lua require'qf'.load('c', <q-args>)
" Set the item in quickfix list
command! -nargs=* Qset    lua require'qf'.below('c', <q-args>)

" === LOCATION ===

" Opens the quickfix list
command! -nargs=* Lopen   lua require'qf'.open('l', <q-args>)
" Close the quickfix list
command! -nargs=* Lclose  lua require'qf'.close('l', <q-args>)
" Toggle the quickfix list
command! -nargs=* Ltoggle lua require'qf'.close('l', <q-args>)
" Clear the contents of quickfix list
command! -nargs=* Lclear  lua require'qf'.clear('l', <q-args>)

" Move to the next item in quickfix list and wrap around.
" Second argument denotes wrap>
command! -nargs=* Lnext   lua require'qf'.next('l', <q-args>)
" Move to the previous item in quickfix list.
" Second argument denotes wrap>
command! -nargs=* Lprev   lua require'qf'.prev('l', <q-args>)
" Move to the previous item in the location list.
" Second argument denotes wrap>
command! -nargs=* Labove  lua require'qf'.above('l', <q-args>)
" Move to the previous item in the location list.
" Second argument denotes wrap>
command! -nargs=* Lbelow  lua require'qf'.below('l', <q-args>)
" Move to the previous item in visible list.
" Second argument denotes wrap>
command! -nargs=* Vabove  lua require'qf'.above('visible', <q-args>)
" Move to the previous item in visible list.
" Second argument denotes wrap>
command! -nargs=* Vbelow  lua require'qf'.below('visible', <q-args>)

" Save the quickfix list
command! -nargs=* Lsave   lua require'qf'.save('l', <q-args>)
" Load a saved quickfix list
command! -nargs=* Lload   lua require'qf'.load('l', <q-args>)
" Set the item in quickfix list
command! -nargs=* Lset    lua require'qf'.below('l', <q-args>)
