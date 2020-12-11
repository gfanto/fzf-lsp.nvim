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

  normal zz
endfun

fun! s:fzf_entry_sink_local(lines)
  for l in a:lines
    let entry = s:make_entry(l)
    call cursor(entry[0], entry[1])
  endfor

  normal zz
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
  if lines is v:null
    return
  endif
  if len(lines) == 0
    echo "Definitions not found"
    return
  endif

  if len(lines) == 1
    for l in lines
      call s:jump_to_entry(s:make_entry(l))
    endfor

    return
  endif

  call fzf#run(fzf#wrap('LSP Definitions', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#references(bang)
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['references']({'timeout': g:fzf_lsp_timeout})
  if lines is v:null
    return
  endif
  if len(lines) == 0
    echo "References not found"
    return
  endif

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#document_symbols(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['document_symbols']({'timeout': g:fzf_lsp_timeout})
  if lines is v:null
    return
  endif
  if len(lines) == 0
    echo "Documents symbols not found"
    return
  endif

  call fzf#run(fzf#wrap('LSP Document Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink_local'),
    \ 'options': ['--preview', s:bin['preview'] . ' ' . expand("%") . ':{}']
    \}, a:bang))
endfun

fun! fzf_lsp#workspace_symbols(bang, options) abort
  let l:options = split(a:options)

  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['workspace_symbols']({
    \ 'query': get(l:options, 0, ''),
    \ 'timeout': g:fzf_lsp_timeout
    \ })
  if lines is v:null
    return
  endif
  if len(lines) == 0
    echo "Workspace symbols not found"
    return
  endif

  call fzf#run(fzf#wrap('LSP Workspace Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#code_actions(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['code_actions']({'timeout': g:fzf_lsp_timeout})
  if results is v:null
    return
  endif
  if len(results) == 0
    echo "Code actions not available"
    return
  endif

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
  if results is v:null
    return
  endif
  if len(results) == 0
    echo "Code actions not available in range"
    return
  endif

  let lines = []
  for action in results
    call add(lines, action['idx'] . '. ' . action['title'])
  endfor

  call fzf#run(fzf#wrap('LSP Range Code Actions', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_action_sink', [results])
    \}, a:bang))
endfun

fun! fzf_lsp#diagnostics(bang, options) abort
  let l:options = split(a:options)

  let diag_opts = {'timeout': g:fzf_lsp_timeout}

  let severity = get(l:options, 0)
  if severity
    let diag_opts.severity = severity
  endif
  let severity_limit = get(l:options, 1)
  if severity_limit
    let diag_opts.severity_limit = severity_limit
  endif

  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['diagnostics'](diag_opts)
  if lines is v:null || len(lines) == 0
    echo "Empty diagnostic"
    return
  endif

  call fzf#run(fzf#wrap('LSP Diagnostics', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_entry_sink_local'),
    \ 'options': ['--preview', s:bin['preview'] . ' ' . expand("%") . ':{}']
    \}, a:bang))
endfun
