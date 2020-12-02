let s:is_win = has('win32') || has('win64')
let s:bin_dir = expand('<sfile>:p:h:h').'/bin/'
let s:bin = { 'preview': s:bin_dir.'preview.sh' }

fun! s:extend(l, e)
  for x in a:e
    call add(a:l, x)
  endfor
endfun

fun! s:escape(path)
  let path = fnameescape(a:path)
  return s:is_win ? escape(path, '$') : path
endfun

fun! s:open(cmd, target)
  if stridx('edit', a:cmd) == 0 && fnamemodify(a:target, ':p') ==# expand('%:p')
    return
  endif
  execute a:cmd s:escape(a:target)
endfun

fun! s:jump_to_file(filename, lnum, col)
  call s:open('e', a:filename)
  call cursor(a:lnum, a:col)
endfun

fun! s:jump_to_entry(entry)
  call s:jump_to_file(a:entry[0], a:entry[1], a:entry[2])
endfun

fun! s:make_entry(entry)
  let e_split = split(a:entry, ':')
  let filename = e_split[0]
  let lnum = get(e_split, 1, 0)
  let col = get(e_split, 2, 0)

  return [filename, lnum, col]
endfun

fun! s:fzf_entry_sink(lines)
  for l in a:lines
    call s:jump_to_entry(s:make_entry(l))
  endfor
endfun

fun! s:fzf_entry_sink_shorten(stripped, lines)
  for l in a:lines
    let entry = s:make_entry(l)
    let entry[0] = a:stripped . '/' . entry[0]
    call s:jump_to_entry(entry)
  endfor
endfun

fun! fzf_lsp#definitions(bang, options) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['definition']()

  if lines is v:null || len(lines) == 0
    return
  endif

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#references(bang, options)
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['references']()

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#document_symbols(bang, options) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['document_symbols']()
  let stripped = fnamemodify(expand('%'), ':h')

  call fzf#run(fzf#wrap('LSP Document Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink_shorten', [stripped]),
    \ 'options': ['--preview', s:bin['preview'] . ' ' . stripped . '/{}']
    \}, a:bang))
endfun

fun! fzf_lsp#workspace_symbols(bang, options) abort
  let l:options = split(a:options)

  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['workspace_symbols']({'query': get(l:options, 0, '')})

  call fzf#run(fzf#wrap('LSP Workspace Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

