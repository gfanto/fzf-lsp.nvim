if exists('g:loaded_fzf_lsp')
  finish
endif
let g:loaded_fzf_lsp = 1

let s:fzf_lsp_default_action = {
  \ "ctrl-t": "tabedit",
  \ "ctrl-v": "vsplit",
  \ "ctrl-x": "split",
  \ }

let g:fzf_lsp_action = get(g:, 'fzf_lsp_action',
  \ get(g:, 'fzf_action', copy(s:fzf_lsp_default_action)
  \ ))
let g:fzf_lsp_timeout = get(g:, 'fzf_lsp_timeout', 5000)

let s:prefix = get(g:, 'fzf_command_prefix', '')

let s:references_command = s:prefix . 'References'
let s:definition_command = s:prefix . 'Definitions'
let s:declaration_command = s:prefix . 'Declarations'
let s:type_definition_command = s:prefix . 'TypeDefinitions'
let s:implementation_command = s:prefix . 'Implementations'
let s:document_symbol_command = s:prefix . 'DocumentSymbols'
let s:workspace_symbol_command = s:prefix . 'WorkspaceSymbols'
let s:code_action_command = s:prefix . 'CodeActions'
let s:range_code_action_command = s:prefix . 'RangeCodeActions'
let s:diagnostics = s:prefix . 'Diagnostics'

fun! s:call_fzf_lsp(method_fn, bang, options)
  let fzf_lsp = v:lua.require('fzf_lsp')
  call fzf_lsp[a:method_fn](a:bang, a:options)
endfun

fun! s:definition(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('definition', a:bang, options)
endfun

fun! s:declaration(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('declaration', a:bang, options)
endfun

fun! s:type_definition(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('type_definition', a:bang, options)
endfun

fun! s:implementation(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('implementation', a:bang, options)
endfun

fun! s:references(bang)
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('references', a:bang, options)
endfun

fun! s:document_symbol(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('document_symbol', a:bang, options)
endfun

fun! s:workspace_symbol(bang, args) abort
  let l:args = split(a:args)
  let options = {
    \ 'query': get(l:args, 0, ''),
    \ 'timeout': g:fzf_lsp_timeout
    \ }
  call s:call_fzf_lsp('workspace_symbol', a:bang, options)
endfun

fun! s:code_action(bang) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('code_action', a:bang, options)
endfun

fun! s:range_code_action(bang, range, line1, line2) abort
  let options = {'timeout': g:fzf_lsp_timeout}
  call s:call_fzf_lsp('range_code_action', a:bang, options)
endfun

fun! s:diagnostic(bang, args) abort
  let l:args = split(a:args)

  let options = {'timeout': g:fzf_lsp_timeout}

  let severity = get(l:args, 0)
  if severity
    let options.severity = severity
  endif
  let severity_limit = get(l:args, 1)
  if severity_limit
    let options.severity_limit = severity_limit
  endif

  call s:call_fzf_lsp('diagnostic', a:bang, options)
endfun

execute 'command! -bang ' . s:definition_command . ' call s:definition(<bang>0)'
execute 'command! -bang ' . s:declaration_command . ' call s:declaration(<bang>0)'
execute 'command! -bang ' . s:type_definition_command . ' call s:type_definition(<bang>0)'
execute 'command! -bang ' . s:implementation_command . ' call s:implementation(<bang>0)'
execute 'command! -bang ' . s:references_command . ' call s:references(<bang>0)'
execute 'command! -bang ' . s:document_symbol_command . ' call s:document_symbol(<bang>0)'
execute 'command! -bang -nargs=? ' . s:workspace_symbol_command . ' call s:workspace_symbol(<bang>0, <q-args>)'
execute 'command! -bang ' . s:code_action_command . ' call s:code_action(<bang>0)'
execute 'command! -bang -range ' . s:range_code_action_command . ' call s:range_code_action(<bang>0, <range>, <line1>, <line2>)'
execute 'command! -bang -nargs=* ' . s:diagnostics . ' call s:diagnostic(<bang>0, <q-args>)'
