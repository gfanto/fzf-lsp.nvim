let g:fzf_lsp_timeout = get(g:, 'fzf_lsp_timeout', 10000)

let s:prefix = get(g:, 'fzf_command_prefix', '')

let s:references_command = s:prefix . 'References'
let s:definitions_command = s:prefix . 'Definitions'
let s:document_sym_command = s:prefix . 'DocumentSymbols'
let s:workspace_sym_command = s:prefix . 'WorkspaceSymbols'
execute 'command! -bang ' . s:definitions_command . ' call fzf_lsp#definitions(<bang>0, <q-args>)'
execute 'command! -bang ' . s:references_command . ' call fzf_lsp#references(<bang>0, <q-args>)'
execute 'command! -bang ' . s:document_sym_command . ' call fzf_lsp#document_symbols(<bang>0, <q-args>)'
execute 'command! -bang ' . s:workspace_sym_command . ' call fzf_lsp#workspace_symbols(<bang>0, <q-args>)'
