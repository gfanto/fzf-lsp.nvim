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

fun! s:fzf_references_sink(lines)
  " TODO: handle multiple lines
  let entry = a:lines[0]
  let e_split = split(entry, '|')
  let filename = e_split[0]
  let c_split = split(e_split[1])
  let lnum = get(c_split, 0, 0)
  let col = get(c_split, 2, 0)
  call s:open('e', filename)
  call cursor(lnum, col)
endfun

fun! fzf_lsp#definitions(bang, options) abort
  let params = v:lua.vim.lsp.util.make_position_params()
  let params.context = { 'includeDeclaration': v:true }
  let results_lsp = v:lua.vim.lsp.buf_request_sync(0, 'textDocument/definition', params, g:fzf_lsp_timeout)
  if results_lsp is v:null || len(results_lsp) == 0
    echo "No results from textDocument/definition"
    return
  endif

  let result = results_lsp[0].result
  if type(result) == v:t_list
    call v:lua.vim.lsp.util.jump_to_location(result[0])

    if len(result) > 1
      let locations = []
      for server_results in results_lsp
        let items = v:lua.vim.lsp.util.locations_to_items(server_results.result, 0)
        if items isnot v:null && len(items) != 0
          call s:extend(locations, items)
        endif
      endfor
      if len(locations) == 0
        return
      endif

      let lines = []
      for loc in locations
        " XXX: path will be absolute if i'm not in the project directory
        call add(lines, fnamemodify(loc['filename'], ':.') . '|' . loc['lnum'] . ' col ' . loc['col'] . '| ' . trim(loc['text']))
      endfor

      call fzf#run(fzf#wrap('LSP References', {
        \ 'source': lines,
        \ 'sink*': function('s:fzf_references_sink'),
        \ 'options': ['--preview', s:bin['preview'] . ' {}']
        \}, a:bang))
    endif
  else
    call v:lua.vim.lsp.util.jump_to_location(result)
  endif
endfun

fun! fzf_lsp#references(bang, options)
  let params = v:lua.vim.lsp.util.make_position_params()
  let params.context = { 'includeDeclaration': v:true }
  let results_lsp = v:lua.vim.lsp.buf_request_sync(0, 'textDocument/references', params, g:fzf_lsp_timeout)
  if results_lsp is v:null || len(results_lsp) == 0
    echo 'No results from textDocument/references'
    return
  endif

  let locations = []
  for server_results in results_lsp
    let items = v:lua.vim.lsp.util.locations_to_items(server_results.result, 0)
    if items isnot v:null && len(items) != 0
      call s:extend(locations, items)
    endif
  endfor

  if len(locations) == 0
    return
  endif

  let lines = []
  for loc in locations
    " XXX: path will be absolute if i'm not in the project directory
    call add(lines, fnamemodify(loc['filename'], ':.') . '|' . loc['lnum'] . ' col ' . loc['col'] . '| ' . trim(loc['text']))
  endfor

  call fzf#run(fzf#wrap('LSP References', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_references_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#document_sym(bang, options) abort
  let params = v:lua.vim.lsp.util.make_position_params()
  let results_lsp = v:lua.vim.lsp.buf_request_sync(0, 'textDocument/documentSymbol', params, g:fzf_lsp_timeout)
  if results_lsp is v:null || len(results_lsp) == 0
    echo 'No results from textDocument/documentSymbol'
    return
  endif

  let locations = []
  for server_results in results_lsp
    let items = v:lua.vim.lsp.util.symbols_to_items(server_results.result, 0)
    if items isnot v:null && len(items) != 0
      call s:extend(locations, items)
    endif
  endfor

  if len(locations) == 0
    return
  endif

  let lines = []
  for loc in locations
    " XXX: path will be absolute if i'm not in the project directory
    call add(lines, fnamemodify(loc['filename'], ':.') . '|' . loc['lnum'] . ' col ' . loc['col'] . '| ' . trim(loc['text']))
  endfor

  call fzf#run(fzf#wrap('LSP Document Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_references_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

fun! fzf_lsp#workspace_sym(bang, options) abort
  let l:options = split(a:options)
  let params = {'query': get(l:options, 0, '')}
  let results_lsp = v:lua.vim.lsp.buf_request_sync(0, 'workspace/symbol', params, g:fzf_lsp_timeout)
  if results_lsp is v:null || len(results_lsp) == 0
    echo 'No results from workspace/symbol'
    return
  endif

  let locations = []
  for server_results in results_lsp
    let items = v:lua.vim.lsp.util.symbols_to_items(server_results.result, 0)
    if items isnot v:null && len(items) != 0
      call s:extend(locations, items)
    endif
  endfor

  if len(locations) == 0
    return
  endif

  let lines = []
  for loc in locations
    " XXX: path will be absolute if i'm not in the project directory
    call add(lines, fnamemodify(loc['filename'], ':.') . '|' . loc['lnum'] . ' col ' . loc['col'] . '| ' . trim(loc['text']))
  endfor

  call fzf#run(fzf#wrap('LSP Workspace Symbols', {
    \ 'source': lines,
    \ 'sink*': function('s:fzf_references_sink'),
    \ 'options': ['--preview', s:bin['preview'] . ' {}']
    \}, a:bang))
endfun

