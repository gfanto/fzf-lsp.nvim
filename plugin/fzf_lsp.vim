let g:fzf_lsp_timeout = get(g:, 'fzf_lsp_timeout', 10000)

let s:prefix = get(g:, 'fzf_command_prefix', '')

let s:references_command = s:prefix . 'LSPReferences'
let s:definitions_command = s:prefix . 'LSPDefinitions'
let s:document_sym_command = s:prefix . 'LSPDocumentSymbols'
let s:workspace_sym_command = s:prefix . 'LSPWorkspaceSymbols'
execute 'command! -bang ' . s:definitions_command . ' call fzf_lsp#definitions(<bang>0, <q-args>)'
execute 'command! -bang ' . s:references_command . ' call fzf_lsp#references(<bang>0, <q-args>)'
execute 'command! -bang ' . s:document_sym_command . ' call fzf_lsp#document_sym(<bang>0, <q-args>)'
execute 'command! -bang ' . s:workspace_sym_command . ' call fzf_lsp#workspace_sym(<bang>0, <q-args>)'
