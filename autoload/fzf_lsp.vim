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
  let l:esplit = split(a:entry, ':')
  let l:filename = l:esplit[0]
  let l:lnum = get(l:esplit, 1, 0)
  let l:col = get(l:esplit, 2, 0)

  return [l:filename, l:lnum, l:col]
endfun

fun! s:_make_lines_from_codeactions(results)
  let lines = []
  for action in a:results
    call add(lines, action['idx'] . '. ' . action['title'])
  endfor

  return lines
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

fun! s:fzf_run_command(bang, title, lines, local)
  let l:Sink = function(a:local ? 's:fzf_entry_sink_local' : 's:fzf_entry_sink')
  let l:expand_line = a:local ? (expand("%") . ':{}') : '{}'

  call fzf#run(fzf#wrap(a:title, {
    \ 'source': a:lines,
    \ 'sink*': l:Sink,
    \ 'options': ['--preview', s:bin['preview'] . ' ' . l:expand_line]
    \}, a:bang))
endfun

fun! s:fzf_run(title, lines, local)
  call s:fzf_run_command(0, a:title, a:lines, a:local)
endfun

fun! s:fzf_action_sink(results, lines)
  let fzf_lsp = v:lua.require('fzf_lsp')

  for l in a:lines
    call fzf_lsp['code_action_execute'](a:results[str2nr(l) - 1])
  endfor
endfun

fun! s:fzf_run_actions_command(bang, title, lines, results)
  call fzf#run(fzf#wrap(a:title, {
    \ 'source': a:lines,
    \ 'sink*': function('s:fzf_action_sink', [a:results])
    \}, a:bang))
endfun

fun! s:fzf_run_actions(title, lines, results)
  call s:fzf_run_actions_command(0, a:title, a:lines, a:results)
endfun

fun! fzf_lsp#definitions(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['definition']({'timeout': g:fzf_lsp_timeout})
  if lines is v:null || len(lines) == 0
    return
  endif

  if len(lines) == 1
    for l in lines
      call s:jump_to_entry(s:make_entry(l))
    endfor

    return
  endif

  call s:fzf_run_command(bang, 'LSP Definitions', lines, v:false)
endfun

fun! fzf_lsp#references(bang)
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['references']({'timeout': g:fzf_lsp_timeout})
  if lines is v:null || len(lines) == 0
    return
  endif

  call s:fzf_run_command(a:bang, 'LSP References', lines, v:false)
endfun

fun! fzf_lsp#document_symbols(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['document_symbols']({'timeout': g:fzf_lsp_timeout})
  if lines is v:null || len(lines) == 0
    return
  endif

  call s:fzf_run_command(a:bang, 'LSP Document Symbols', lines, v:true)
endfun

fun! fzf_lsp#workspace_symbols(bang, options) abort
  let l:options = split(a:options)

  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp['workspace_symbols']({
    \ 'query': get(l:options, 0, ''),
    \ 'timeout': g:fzf_lsp_timeout
    \ })
  if lines is v:null || len(lines) == 0
    return
  endif

  call s:fzf_run_command(a:bang, 'LSP Workspace Symbols', lines, v:false)
endfun

fun! fzf_lsp#code_actions(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['code_actions']({'timeout': g:fzf_lsp_timeout})
  if results is v:null || len(results) == 0
    return
  endif

  let lines = s:_make_lines_from_codeactions(results)
  call s:fzf_run_actions_command(a:bang,'LSP Code Actions', lines, results)
endfun

fun! fzf_lsp#range_code_actions(bang, range, line1, line2) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['range_code_actions']({'timeout': g:fzf_lsp_timeout})
  if results is v:null || len(results) == 0
    return
  endif

  let lines = s:_make_lines_from_codeactions(results)
  call s:fzf_run_actions_command(a:bang, 'LSP Range Code Actions', lines, results)
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

  call s:fzf_run_command(a:bang, 'LSP Diagnostics', lines, v:true)
endfun

fun! fzf_lsp#async_handler(_, method, locations, client_id, bufnr) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['handlers'][a:method](a:_, a:method, a:locations, a:client_id, a:bufnr)

  if results is v:null || len(results) == 0
    return
  endif

  if a:method == 'textDocument/codeAction'
    let lines = s:_make_lines_from_codeactions(results)
    call s:fzf_run_actions('lsp', lines, results)
  elseif a:method == 'textDocument/definition'
    if len(results) == 1
      for l in results
        call s:jump_to_entry(s:make_entry(l))
      endfor
    else
      call s:fzf_run('lsp', results, v:false)
    endif
  elseif a:method == 'textDocument/documentSymbol'
    call s:fzf_run('lsp', results, v:true)
  else
    call s:fzf_run('lsp', results, v:false)
  endif
endfun
