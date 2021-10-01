# fzf-lsp.nvim

![Show document symbols](https://raw.githubusercontent.com/gfanto/fzf-lsp.nvim/main/.github/images/document-symbol-example-multi.gif)

# Installation

Install using [vim-plug](https://github.com/junegunn/vim-plug).
Put this in your `init.vim`.

```vim
Plug 'gfanto/fzf-lsp.nvim'
```

## Requirements

* Neovim 0.5+
* `fzf` installed in addition to use this plugin. See <https://github.com/junegunn/fzf/blob/master/README-VIM.md#installation>.
* `bat` installed for the preview. See <https://github.com/sharkdp/bat>

## Features

This is an extension for fzf that give you the ability to search for symbols
using the neovim builtin lsp.

## Commands and settings

If you have [fzf.vim](https://github.com/junegunn/fzf.vim) installed,
this plugin will respect your `g:fzf_command_prefix` setting.

#### Settings:

In general fzf-lsp.vim will respect your fzf.vim settings, alternatively you can override a specific settings with the fzf-lsp.vim equivalent:
* `g:fzf_lsp_action`: the equivalent of `g:fzf_action`, it's a dictionary containing all the actions that fzf will do in case of specific input
* `g:fzf_lsp_layout`: the equivalent of `g:fzf_layout`, dictionary with the fzf_window layout
* `g:fzf_lsp_colors`: the equivalent of `g:fzf_colors`, it's a string that will be passed to fzf to set colors
* `g:fzf_lsp_preview_window`: the equivalent of `g:fzf_preview_window`, it's a list containing the preview windows position and key bindings

fzf-lsp.vim only settings:
* `g:fzf_lsp_timeout`: integer value, number of milliseconds after command calls will go to timeout

#### Commands:

*** Commands accepts and respect the ! if given ***

- Call `:Definitions` to show the definition for the symbols under the cursor
- Call `:Declarations` to show the declaration for the symbols under the cursor\*
- Call `:TypeDefinitions` to show the type definition for the symbols under the cursor\*
- Call `:Implementations` to show the implementation for the symbols under the cursor\*
- Call `:References` to show the references for the symbol under the cursor
- Call `:DocumentSymbols` to show all the symbols in the current buffer
- Call `:WorkspaceSymbols` to show all the symbols in the workspace, you can optionally pass the query as argument to the command
- Call `:IncomingCalls` to show the incoming calls
- Call `:OutgoingCalls` to show the outgoing calls
- Call `:CodeActions` to show the list of available code actions
- Call `:RangeCodeActions` to show the list of available code actions in the visual selection
- Call `:Diagnostics` to show all the available diagnostic informations in the current buffer, you can optionally pass the desired severity level as first argument or the severity limit level as second argument
- Call `:DiagnosticsAll` to show all the available diagnostic informations in all the opened buffers, you can optionally pass the desired severity level as first argument or the severity limit level as second argument

**Note(\*)**: this methods may not be implemented in your language server, especially textDocument/declaration (`Declarations`) it's usually not implemented in favour of textDocument/definition (`Definitions`).

### Functions

Commands are just wrappers to the following function, each function take one optional parameter: a dictionary containing the options.

- `require'fzf_lsp'.code_action_call`
- `require'fzf_lsp'.range_code_action_call`
- `require'fzf_lsp'.definition_call`
- `require'fzf_lsp'.declaration_call`
- `require'fzf_lsp'.type_definition_call`
- `require'fzf_lsp'.implementation_call`
- `require'fzf_lsp'.references_call`
- `require'fzf_lsp'.document_symbol_call`
- `require'fzf_lsp'.workspace_symbol_call`
    * options:
        * query
- `require'fzf_lsp'.incoming_calls_call`
- `require'fzf_lsp'.outgoing_calls_call`
- `require'fzf_lsp'.diagnostic_call`
    * options:
        * bufnr: the buffer number, default on current buffer
        * severity: the minimum severity level
        * severity_limit: the maximum severity level

### Handlers

Functions and commands are implemented using sync calls, if you want your calls to be async you can use the standard neovim calls setting his relative handler.
To do that you can use the provided `setup` function, keeping in mind that this will replace all your handlers:
```lua
require'fzf_lsp'.setup()
```

or you can manually setup your handlers. The provided handlers are:

```lua
vim.lsp.handlers["textDocument/codeAction"] = require'fzf_lsp'.code_action_handler
vim.lsp.handlers["textDocument/definition"] = require'fzf_lsp'.definition_handler
vim.lsp.handlers["textDocument/declaration"] = require'fzf_lsp'.declaration_handler
vim.lsp.handlers["textDocument/typeDefinition"] = require'fzf_lsp'.type_definition_handler
vim.lsp.handlers["textDocument/implementation"] = require'fzf_lsp'.implementation_handler
vim.lsp.handlers["textDocument/references"] = require'fzf_lsp'.references_handler
vim.lsp.handlers["textDocument/documentSymbol"] = require'fzf_lsp'.document_symbol_handler
vim.lsp.handlers["workspace/symbol"] = require'fzf_lsp'.workspace_symbol_handler
vim.lsp.handlers["callHierarchy/incomingCalls"] = require'fzf_lsp'.incoming_calls_handler
vim.lsp.handlers["callHierarchy/outgoingCalls"] = require'fzf_lsp'.outgoing_calls_handler
```

### Compatibility

If you have some compatibility issues with neovim 0.6+ try with the `0.6.x`
branch.

For example if you use vim-plug:
```vim
Plug 'gfanto/fzf_lsp.nvim', { 'branch': 'branches/0.6.x' }
```
