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

fun! s:make_lines_from_codeactions(results)
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

  normal! zz
endfun

fun! s:fzf_entry_sink_local(lines)
  for l in a:lines
    let entry = s:make_entry(l)
    call cursor(entry[0], entry[1])
  endfor

  normal! zz
endfun

fun! s:location_call(bang, options, method_fn, title, local)
  let fzf_lsp = v:lua.require('fzf_lsp')
  let lines = fzf_lsp[a:method_fn](a:options)
  if lines is v:null || len(lines) == 0
    return
  endif

  call s:fzf_run_location_command(a:bang, a:title, lines, a:local)
endfun

fun! s:fzf_run_location_command(bang, title, lines, local)
  let l:Sink = function(a:local ? 's:fzf_entry_sink_local' : 's:fzf_entry_sink')
  let l:expand_line = a:local ? (expand("%") . ':{}') : '{}'

  call fzf#run(fzf#wrap(a:title, {
    \ 'source': a:lines,
    \ 'sink*': l:Sink,
    \ 'options': ['--preview', s:bin['preview'] . ' ' . l:expand_line]
    \}, a:bang))
endfun

fun! s:fzf_run_location(title, lines, local)
  call s:fzf_run_location_command(0, a:title, a:lines, a:local)
endfun

fun! s:fzf_action_sink(results, lines)
  let fzf_lsp = v:lua.require('fzf_lsp')

  for l in a:lines
    call fzf_lsp['code_action_execute'](a:results[str2nr(l) - 1])
  endfor
endfun

fun! s:fzf_run_codeaction_command(bang, title, lines, results)
  call fzf#run(fzf#wrap(a:title, {
    \ 'source': a:lines,
    \ 'sink*': function('s:fzf_action_sink', [a:results])
    \}, a:bang))
endfun

fun! s:fzf_run_codeaction(title, lines, results)
  call s:fzf_run_codeaction_command(0, a:title, a:lines, a:results)
endfun

fun! fzf_lsp#definition(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'definition', 'LSP Definition', v:false)
endfun

fun! fzf_lsp#declaration(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'declaration', 'LSP Declaration', v:false)
endfun

fun! fzf_lsp#type_definition(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'type_definition', 'LSP Type Definition', v:false)
endfun

fun! fzf_lsp#implementation(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'implementation', 'LSP Implementation', v:false)
endfun

fun! fzf_lsp#references(bang)
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'references', 'LSP References', v:false)
endfun

fun! fzf_lsp#document_symbol(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:location_call(a:bang, options, 'document_symbol', 'LSP Document Symbol', v:true)
endfun

fun! fzf_lsp#workspace_symbol(bang, args) abort
  let l:args = split(a:args)
  let options = {
    \ 'query': get(l:args, 0, ''),
    \ 'timeout': g:fzf_lsp_timeout
    \ }
  call s:location_call(a:bang, options, 'workspace_symbol', 'LSP Workspace Symbol', v:false)
endfun

fun! fzf_lsp#code_action(bang) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['code_action']({'timeout': g:fzf_lsp_timeout})
  if results is v:null || len(results) == 0
    return
  endif

  let lines = s:make_lines_from_codeactions(results)
  call s:fzf_run_codeaction_command(a:bang,'LSP Code Action', lines, results)
endfun

fun! fzf_lsp#range_code_action(bang, range, line1, line2) abort
  let fzf_lsp = v:lua.require('fzf_lsp')
  let results = fzf_lsp['range_code_action']({'timeout': g:fzf_lsp_timeout})
  if results is v:null || len(results) == 0
    return
  endif

  let lines = s:make_lines_from_codeactions(results)
  call s:fzf_run_codeaction_command(a:bang, 'LSP Range Code Action', lines, results)
endfun

fun! fzf_lsp#diagnostic(bang, options) abort
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
  let lines = fzf_lsp['diagnostic'](diag_opts)
  if lines is v:null || len(lines) == 0
    return
  endif

  call s:fzf_run_location_command(a:bang, 'LSP Diagnostic', lines, v:true)
endfun

fun! fzf_lsp#code_action_handler(results)
  let lines = s:make_lines_from_codeactions(a:results)
  call s:fzf_run_codeaction('LSP Code Action', lines, a:results)
endfun

fun! fzf_lsp#definition_handler(lines)
  call s:fzf_run_location("LSP Definition", a:lines, v:false)
endfun

fun! fzf_lsp#declaration_handler(lines)
  call s:fzf_run_location("LSP Declaration", a:lines, v:false)
endfun

fun! fzf_lsp#type_definition_handler(lines)
  call s:fzf_run_location("LSP Type Definition", a:lines, v:false)
endfun

fun! fzf_lsp#implementation_handler(lines)
  call s:fzf_run_location("LSP Implementation", a:lines, v:false)
endfun

fun! fzf_lsp#references_handler(lines)
  call s:fzf_run_location("LSP References", a:lines, v:false)
endfun

fun! fzf_lsp#document_symbol_handler(lines)
  call s:fzf_run_location("LSP Document Symbol", a:lines, v:true)
endfun

fun! fzf_lsp#workspace_symbol_handler(lines)
  call s:fzf_run_location("LSP Workspace Symbol", a:lines, v:false)
endfun
