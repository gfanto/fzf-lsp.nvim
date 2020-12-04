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

fun! s:fzf_entry_sink_local(lines)
  for l in a:lines
    let entry = s:make_entry(l)
    call cursor(entry[1], entry[2])
  endfor
endfun

fun! s:fzf_action_sink(results, lines)
  let fzf_lsp = v:lua.require('fzf_lsp')

  for l in a:lines
    call fzf_lsp['code_action_execute'](a:results[str2nr(l) - 1])
  endfor
endfun

fun! fzf_lsp#definitions(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['definition']({'timeout': g:fzf_lsp_timeout})

  if lines is v:null || len(lines) == 0
    return
  endif

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#references(bang)
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['references']({'timeout': g:fzf_lsp_timeout})

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#document_symbols(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['document_symbols']({'timeout': g:fzf_lsp_timeout})
  let stripped = fnamemodify(expand('%'), ':h')

  call fzf#run(fzf#wrap('LSP Document Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink_local'),
    \ 'options': ['--preview', s:bin['preview'] . ' ' . stripped . '/{}']
    \}, a:bang))
endfun

fun! fzf_lsp#workspace_symbols(bang, options) abort
  let l:options = split(a:options)

  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['workspace_symbols']({
    \ 'query': get(l:options, 0, ''),
    \ 'timeout': g:fzf_lsp_timeout
    \ })

  call fzf#run(fzf#wrap('LSP Workspace Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#code_actions(bang) abort
  let l:options = split(a:options)

  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['code_actions']({'timeout': g:fzf_lsp_timeout})

  if results is v:null || len(results) == 0
    return
  end

  let lines = []
  for action in results
    call add(lines, action['idx'] . '. ' . action['title'])
  endfor

  call fzf#run(fzf#wrap('LSP Code Actions', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_action_sink', [results])
    \}, a:bang))
endfun

fun! fzf_lsp#range_code_actions(bang, range, line1, line2) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['range_code_actions']({'timeout': g:fzf_lsp_timeout})

  if results is v:null || len(results) == 0
    return
  end

  let lines = []
  for action in results
    call add(lines, action['idx'] . '. ' . action['title'])
  endfor

  call fzf#run(fzf#wrap('LSP Range Code Actions', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_action_sink', [results])
    \}, a:bang))
endfun
