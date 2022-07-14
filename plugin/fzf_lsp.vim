if exists('g:loaded_fzf_lsp')
  finish
endif
let g:loaded_fzf_lsp = 1

" fzf_lsp_action default
let s:fzf_lsp_action = {
  \ 'ctrl-t': 'tabedit',
  \ 'ctrl-v': 'vsplit',
  \ 'ctrl-x': 'split',
  \ }

" fzf_lsp_layout example
" let g:fzf_lsp_layout = { 'down': '30% }

" fzf_lsp_colors variable example
" let g:fzf_lsp_colors = 'bg+:-1'

let g:fzf_lsp_action = get(g:, 'fzf_lsp_action', get(g:, 'fzf_action'))
if type(g:fzf_lsp_action) is type(0) && g:fzf_lsp_action == 0
  let g:fzf_lsp_action = s:fzf_lsp_action
else
  if type(g:fzf_lsp_action) != type({})
    echoerr 'Invalid value for g:fzf_lsp_action detected'
  endif
endif

let g:fzf_lsp_preview_window = get(
  \ g:, 'fzf_lsp_preview_window', get(
  \ g:, 'fzf_preview_window', ['right', 'ctrl-/']
  \ ))
if empty(g:fzf_lsp_preview_window)
  let g:fzf_lsp_preview_window = ['hidden']
elseif type(g:fzf_lsp_preview_window) == type('')
  let g:fzf_lsp_preview_window = [g:fzf_lsp_preview_window]
endif

let g:fzf_lsp_timeout = get(g:, 'fzf_lsp_timeout', 5000)
let g:fzf_lsp_width = get(g:, 'fzf_lsp_width', 38)

let g:fzf_lsp_override_ui_select = get(g:, 'fzf_lsp_override_ui_select', 1)
if g:fzf_lsp_override_ui_select
  let g:fzf_lsp_override_ui_select = 1
else
  let g:fzf_lsp_override_ui_select = 0
endif

let s:prefix = get(
  \ g:, 'fzf_lsp_command_prefix', get(
  \ g:, 'fzf_command_prefix', ''
  \ ))

let s:references_command = s:prefix . 'References'
let s:definition_command = s:prefix . 'Definitions'
let s:declaration_command = s:prefix . 'Declarations'
let s:type_definition_command = s:prefix . 'TypeDefinitions'
let s:implementation_command = s:prefix . 'Implementations'
let s:document_symbol_command = s:prefix . 'DocumentSymbols'
let s:workspace_symbol_command = s:prefix . 'WorkspaceSymbols'
let s:incoming_calls_command = s:prefix . 'IncomingCalls'
let s:outgoing_calls_command = s:prefix . 'OutgoingCalls'
let s:code_action_command = s:prefix . 'CodeActions'
let s:range_code_action_command = s:prefix . 'RangeCodeActions'
let s:diagnostics_single = s:prefix . 'Diagnostics'
let s:diagnostics_all = s:prefix . 'DiagnosticsAll'

fun! s:definition(bang) abort
  call v:lua.require('fzf_lsp')['definition'](a:bang)
endfun

fun! s:declaration(bang) abort
  call v:lua.require('fzf_lsp')['declaration'](a:bang)
endfun

fun! s:type_definition(bang) abort
  call v:lua.require('fzf_lsp')['type_definition'](a:bang)
endfun

fun! s:implementation(bang) abort
  call v:lua.require('fzf_lsp')['implementation'](a:bang)
endfun

fun! s:references(bang)
  call v:lua.require('fzf_lsp')['references'](a:bang)
endfun

fun! s:document_symbol(bang) abort
  call v:lua.require('fzf_lsp')['document_symbol'](a:bang)
endfun

fun! s:workspace_symbol(bang, args) abort
  let l:args = split(a:args)
  let options = { 'query': get(l:args, 0, '') }

  call v:lua.require('fzf_lsp')['workspace_symbol'](a:bang, options)
endfun

fun! s:incoming_calls(bang) abort
  call v:lua.require('fzf_lsp')['incoming_calls'](a:bang)
endfun

fun! s:outgoing_calls(bang) abort
  call v:lua.require('fzf_lsp')['outgoing_calls'](a:bang)
endfun

fun! s:code_action(bang) abort
  call v:lua.require('fzf_lsp')['code_action'](a:bang)
endfun

fun! s:range_code_action(bang, range, line1, line2) abort
  call v:lua.require('fzf_lsp')['range_code_action'](a:bang)
endfun

fun! s:diagnostic(bang, args) abort
  let options = {}

  let severity = get(a:args, 0)
  if severity
    let options.severity = severity
  endif

  let severity_limit = get(a:args, 1)
  if severity_limit
    let options.severity_limit = severity_limit
  endif

  " XXX: can bufnr be 0?
  let bufnr = get(a:args, 2)
  if (type(bufnr) == type("") && bufnr != "")|| bufnr != 0
    let options.bufnr = bufnr
  endif

  call v:lua.require('fzf_lsp')['diagnostic'](a:bang, options)
endfun

fun! s:diagnostic_single(bang, args) abort
  let l:args = split(a:args)[:2]

  call s:diagnostic(a:bang, l:args)
endfun

fun! s:diagnostic_all(bang, args) abort
  let l:args = split(a:args)[:2]
  if len(l:args) == 0
    let l:args = [0, 0, "*"]
  elseif len(l:args) == 1
    let l:args = [get(l:args, 0), 0, "*"]
  elseif len(l:args) == 2
    let l:args = [get(l:args, 0), get(l:args, 1), "*"]
  endif

  call s:diagnostic(a:bang, l:args)
endfun

execute 'command! -bang ' . s:definition_command . ' call s:definition(<bang>0)'
execute 'command! -bang ' . s:declaration_command . ' call s:declaration(<bang>0)'
execute 'command! -bang ' . s:type_definition_command . ' call s:type_definition(<bang>0)'
execute 'command! -bang ' . s:implementation_command . ' call s:implementation(<bang>0)'
execute 'command! -bang ' . s:references_command . ' call s:references(<bang>0)'
execute 'command! -bang ' . s:document_symbol_command . ' call s:document_symbol(<bang>0)'
execute 'command! -bang -nargs=? ' . s:workspace_symbol_command . ' call s:workspace_symbol(<bang>0, <q-args>)'
execute 'command! -bang ' . s:incoming_calls_command . ' call s:incoming_calls(<bang>0)'
execute 'command! -bang ' . s:outgoing_calls_command . ' call s:outgoing_calls(<bang>0)'
execute 'command! -bang ' . s:code_action_command . ' call s:code_action(<bang>0)'
execute 'command! -bang -range ' . s:range_code_action_command . ' call s:range_code_action(<bang>0, <range>, <line1>, <line2>)'
execute 'command! -bang -nargs=* ' . s:diagnostics_single . ' call s:diagnostic_single(<bang>0, <q-args>)'
execute 'command! -bang -nargs=* ' . s:diagnostics_all . ' call s:diagnostic_all(<bang>0, <q-args>)'
