local vim, fn, api, g = vim, vim.fn, vim.api, vim.g

local ansi = require("fzf_lsp.ansicolors")
local strings = require("plenary.strings")

local kind_to_color = {
  ["Class"] = "blue",
  ["Constant"] = "cyan",
  ["Field"] = "yellow",
  ["Interface"] = "yellow",
  ["Function"] = "green",
  ["Method"] ="green",
  ["Module"] = "magenta",
  ["Property"] = "yellow",
  ["Struct"] = "red",
  ["Variable"] = "cyan",
}

local M = {}

-- binary paths {{{
local __file = debug.getinfo(1, "S").source:match("@(.*)$")
assert(__file ~= nil)
local bin_dir = fn.fnamemodify(__file, ":p:h:h") .. "/bin"
local bin = { preview = (bin_dir .. "/preview.sh") }
-- }}}

-- utility functions {{{
local function partial(func, arg)
  return (function(...)
    return func(arg, ...)
  end)
end

local function perror(err)
  print("ERROR: " .. tostring(err))
end

local function mk_handler(fn)
  return function(...)
    local config_or_client_id = select(4, ...)
    local is_new = type(config_or_client_id) ~= 'number'
    if is_new then
      fn(...)
    else
      local err = select(1, ...)
      local method = select(2, ...)
      local result = select(3, ...)
      local client_id = select(4, ...)
      local bufnr = select(5, ...)
      local config = select(6, ...)
      fn(err, result, { method = method, client_id = client_id, bufnr = bufnr }, config)
    end
  end
end

local function colored_kind(kind)
  local width = 10 -- max lenght of listed kinds
  local color = kind_to_color[kind] or "white"
  return ansi.noReset("%{bright}%{" .. color .. "}")
    .. strings.align_str(strings.truncate(kind or "", width), width)
    .. ansi.noReset("%{reset}")
end
-- }}}

-- LSP utility {{{
local function extract_result(results_lsp)
  if results_lsp then
    local results = {}
    for client_id, response in pairs(results_lsp) do
      if response.result then
        for _, result in pairs(response.result) do
          result.client_id = client_id
          table.insert(results, result)
        end
      end
    end

    return results
  end
end

local function call_sync(method, params, opts, handler)
  params = params or {}
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local results_lsp, err = vim.lsp.buf_request_sync(
    bufnr, method, params, opts.timeout or g.fzf_lsp_timeout
  )

  local ctx = {
    method = method,
    bufnr = bufnr,
    client_id = results_lsp and next(results_lsp) or nil,
  }
  handler(err, extract_result(results_lsp), ctx, nil)
end

local function check_capabilities(provider, client_id)
  local clients = vim.lsp.buf_get_clients(client_id or 0)

  local supported_client = false
  for _, client in pairs(clients) do
    supported_client = client.server_capabilities[provider]
    if supported_client then goto continue end
  end

  ::continue::
  if supported_client then
    return true
  else
    if #clients == 0 then
      print("LSP: no client attached")
    else
      print("LSP: server does not support " .. provider)
    end
    return false
  end
end

local function code_action_execute(action, offset_encoding)
  if action.edit or type(action.command) == "table" then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit, offset_encoding)
    end
    if type(action.command) == "table" then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

local function lines_from_locations(locations, include_filename)
  local fnamemodify = function (filename)
    if include_filename then
      return fn.fnamemodify(filename, ":~:.") .. ":"
    else
      return ""
    end
  end

  local width = vim.g.fzf_lsp_width

  local lines = {}
  for _, loc in ipairs(locations) do
    local text = vim.trim(loc["text"]:gsub("%b[]", ""))
    table.insert(
      lines,
      strings.align_str(strings.truncate(text, width), width)
        .. " "
        .. colored_kind(loc["kind"])
        .. string.rep(" ", 50)
        .. "\x01 "
        .. fnamemodify(loc["filename"])
        .. loc["lnum"]
        .. ":"
        .. loc["col"]
    )
  end

  return lines
end

local function locations_from_lines(lines, filename_included)
  local extract_location = function(l)
    local path, lnum, col, text, bufnr

    if filename_included then
      local split = vim.split(l, "\x01 ")
      local text = split[1]
      local file = split[2]
      path, lnum, col = file:match("([^:]*):([^:]*):([^:]*)")
    else
      local split = vim.split(l, "\x01 ")
      local text = split[1]
      local file = split[2]
      bufnr = api.nvim_get_current_buf()
      path = fn.expand("%")
      lnum, col = file:match("([^:]*):([^:]*)")
    end

    return {
      bufnr = bufnr,
      filename = path,
      lnum = lnum,
      col = col,
      text = text or "",
    }
  end

  local locations = {}
  for _, l in ipairs(lines) do
    table.insert(locations, extract_location(l))
  end

  return locations
end

local function location_handler(err, locations, ctx, _, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not locations or vim.tbl_isempty(locations) then
    print(error_message)
    return
  end

  local client = vim.lsp.get_client_by_id(ctx.client_id)

  if vim.tbl_islist(locations) then
    if #locations == 1 then
      vim.lsp.util.jump_to_location(locations[1], client.offset_encoding)

      return
    end
  else
    vim.lsp.util.jump_to_location(locations, client.offset_encoding)
  end

  return lines_from_locations(
    vim.lsp.util.locations_to_items(locations, client.offset_encoding), true
  )
end

local function call_hierarchy_handler(direction, err, result, _, _, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print(error_message)
    return
  end

  local items = {}
  for _, call_hierarchy_call in pairs(result) do
    local call_hierarchy_item = call_hierarchy_call[direction]
    for _, range in pairs(call_hierarchy_call.fromRanges) do
      table.insert(items, {
        filename = assert(vim.uri_to_fname(call_hierarchy_item.uri)),
        text = call_hierarchy_item.name,
        lnum = range.start.line + 1,
        col = range.start.character + 1,
      })
    end
  end

  return lines_from_locations(items, true)
end

local call_hierarchy_handler_from = partial(call_hierarchy_handler, "from")
local call_hierarchy_handler_to = partial(call_hierarchy_handler, "to")
-- }}}

-- FZF functions {{{
local function fzf_wrap(name, opts, bang)
  name = name or ""
  opts = opts or {}
  bang = bang or 0

  if g.fzf_lsp_layout then
    opts = vim.tbl_extend('keep', opts, g.fzf_lsp_layout)
  end

  if g.fzf_lsp_colors then
    vim.list_extend(opts.options, {"--color", g.fzf_lsp_colors})
  end

  local sink_fn = opts["sink*"] or opts["sink"]
  if sink_fn ~= nil then
    opts["sink"] = nil; opts["sink*"] = 0
  else
    -- if no sink function is given i automatically put the actions
    if g.fzf_lsp_action and not vim.tbl_isempty(g.fzf_lsp_action) then
      vim.list_extend(
        opts.options, {"--expect", table.concat(vim.tbl_keys(g.fzf_lsp_action), ",")}
      )
    end
  end
  local wrapped = fn["fzf#wrap"](name, opts, bang)
  wrapped["sink*"] = sink_fn

  return wrapped
end

local function fzf_run(...)
  return fn["fzf#run"](...)
end

local function common_sink(infile, lines)
  local action
  if g.fzf_lsp_action and not vim.tbl_isempty(g.fzf_lsp_action) then
    local key = table.remove(lines, 1)
    action = g.fzf_lsp_action[key]
  end

  local locations = locations_from_lines(lines, not infile)
  if action == nil and #lines > 1 then
    vim.fn.setqflist({}, ' ', {
        title = 'Language Server';
        items = locations;
      })
    api.nvim_command("copen")
    api.nvim_command("wincmd p")

    return
  end

  action = action or "e"

  for _, loc in ipairs(locations) do
    local edit_infile = (
      (infile or fn.expand("%:~:.") == loc["filename"]) and
      (action == "e" or action == "edit")
    )
    -- if i'm editing the same file i'm in, i can just move the cursor
    if not edit_infile then
      -- otherwise i can start executing the actions
      local err = api.nvim_command(action .. " " .. loc["filename"])
      if err ~= nil then
        api.nvim_command("echoerr " .. err)
      end
    end

    fn.cursor(loc["lnum"], loc["col"])
    api.nvim_command("normal! zvzz")
  end
end

local function fzf_ui_select(items, opts, on_choice)
  local prompt = opts.prompt or "Select one of:"
  local format_item = opts.format_item or tostring

  local source = {}
  for i, item in pairs(items) do
    table.insert(source, string.format('%d: %s', i, format_item(item)))
  end

  local function sink_fn(lines)
    local _, line = next(lines)
    local choice = -1
    for i, s in pairs(source) do
      if s == line then
        choice = i
        goto continue
      end
    end

    ::continue::
    if choice < 1 then
      on_choice(nil, nil)
    else
      on_choice(items[choice], choice)
    end
  end

  fzf_run(fzf_wrap("fzf_lsp", {
      source = source,
      sink = sink_fn,
      options = {
        "--prompt", prompt,
        "--ansi",
      }
  }, 0))
end

local function fzf_locations(bang, prompt, header, source, infile)
  local preview_cmd = (infile and (bin.preview .. " " .. fn.expand("%") .. ":{-1}") or (bin.preview .. " {-1}"))
  local options = {
    "--prompt",
    prompt .. ">",
    "--header",
    header,
    "--ansi",
    "--delimiter",
    "\x01 ",
    "--nth",
    "1",
    "--multi",
    "--bind",
    "ctrl-a:select-all,ctrl-d:deselect-all",
  }

  if g.fzf_lsp_action and not vim.tbl_isempty(g.fzf_lsp_action) then
    vim.list_extend(
      options, {"--expect", table.concat(vim.tbl_keys(g.fzf_lsp_action), ",")}
    )
  end

  if g.fzf_lsp_preview_window then
    if #g.fzf_lsp_preview_window == 0 then
      g.fzf_lsp_preview_window = {"hidden"}
    end

    vim.list_extend(options, {"--preview-window", g.fzf_lsp_preview_window[1]})
    if #g.fzf_lsp_preview_window > 1 then
      local preview_bindings = {}
      for i=2, #g.fzf_lsp_preview_window, 1 do
        table.insert(preview_bindings, g.fzf_lsp_preview_window[i] .. ":toggle-preview")
      end
      vim.list_extend(options, {"--bind", table.concat(preview_bindings, ",")})
    end
  end

  vim.list_extend(options, {"--preview", preview_cmd})
  fzf_run(fzf_wrap("fzf_lsp", {
    source = source,
    sink = partial(common_sink, infile),
    options = options,
  }, bang))
end

local function fzf_code_actions(bang, prompt, header, actions)
  local lines = {}
  for i, a in ipairs(actions) do
    lines[i] = a["idx"] .. ". " .. a["title"]
  end

  local sink_fn = (function(source)
    local _, line = next(source)
    local idx = tonumber(line:match("(%d+)[.]"))
    local action = actions[idx]
    local client = vim.lsp.get_client_by_id(action.client_id)
    if
      not action.edit
      and client
      and type(client.server_capabilities.codeActionProvider) == "table"
      and client.server_capabilities.codeActionProvider.resolveProvider
      then
      client.request("codeAction/resolve", action, function(resolved_err, resolved_action)
        if resolved_err then
          vim.notify(resolved_err.code .. ": " .. resolved_err.message, vim.log.levels.ERROR)
          return
        end
        if resolved_action then
          code_action_execute(resolved_action, client.offset_encoding)
        else
          code_action_execute(action, client.offset_encoding)
        end
      end)
    else
      code_action_execute(action, client.offset_encoding)
    end
  end)

  fzf_run(fzf_wrap("fzf_lsp", {
      source = lines,
      sink = sink_fn,
      options = {
        "--prompt", prompt .. ">",
        "--header", header,
        "--ansi",
      }
  }, bang))
end
-- }}}

-- LSP reponse handlers {{{
local function code_action_handler(bang, err, result, _, _)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("Code Action not available")
    return
  end

  for i, a in ipairs(result) do
    a.idx = i
  end

  fzf_code_actions(bang, "", "Code Actions", result)
end

local function definition_handler(bang, err, result, ctx, config)
  local results = location_handler(
    err, result, ctx, config, "Definition not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Definitions", results, false)
  end
end

local function declaration_handler(bang, err, result, ctx, config)
  local results = location_handler(
    err, result, ctx, config, "Declaration not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Declarations", results, false)
  end
end

local function type_definition_handler(bang, err, result, ctx, config)
  local results = location_handler(
    err, result, ctx, config, "Type Definition not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Type Definitions", results, false)
  end
end

local function implementation_handler(bang, err, result, ctx, config)
  local results = location_handler(
    err, result, ctx, config, "Implementation not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Implementations", results, false)
  end
end

local function references_handler(bang, err, result, ctx, _)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("References not found")
    return
  end

  local client = vim.lsp.get_client_by_id(ctx.client_id)

  local lines = lines_from_locations(
    vim.lsp.util.locations_to_items(result, client.offset_encoding), true
  )
  fzf_locations(bang, "", "References", lines, false)
end

local function document_symbol_handler(bang, err, result, ctx, _)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("Document Symbol not found")
    return
  end

  local lines = lines_from_locations(
    vim.lsp.util.symbols_to_items(result, ctx.bufnr), false
  )
  fzf_locations(bang, "", "Document Symbols", lines, true)
end

local function workspace_symbol_handler(bang, err, result, ctx, _)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("Workspace Symbol not found")
    return
  end

  local lines = lines_from_locations(
    vim.lsp.util.symbols_to_items(result, ctx.bufnr), true
  )
  fzf_locations(bang, "", "Workspace Symbols", lines, false)
end

local function incoming_calls_handler(bang, err, result, ctx, config)
  local results = call_hierarchy_handler_from(
    err, result, ctx, config, "Incoming calls not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Incoming Calls", results, false)
  end
end

local function outgoing_calls_handler(bang, err, result, ctx, config)
  local results = call_hierarchy_handler_to(
    err, result, ctx, config, "Outgoing calls not found"
  )
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Outgoing Calls", results, false)
  end
end
-- }}}

-- COMMANDS {{{
function M.definition(bang, opts)
  if not check_capabilities("definitionProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "textDocument/definition", params, opts, partial(definition_handler, bang)
  )
end

function M.declaration(bang, opts)
  if not check_capabilities("declarationProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "textDocument/declaration", params, opts, partial(declaration_handler, bang)
  )
end

function M.type_definition(bang, opts)
  if not check_capabilities("typeDefinitionProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "textDocument/typeDefinition", params, opts, partial(type_definition_handler, bang)
  )
end

function M.implementation(bang, opts)
  if not check_capabilities("implementationProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "textDocument/implementation", params, opts, partial(implementation_handler, bang)
  )
end

function M.references(bang, opts)
  if not check_capabilities("referencesProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  call_sync(
    "textDocument/references", params, opts, partial(references_handler, bang)
  )
end

function M.document_symbol(bang, opts)
  if not check_capabilities("documentSymbolProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "textDocument/documentSymbol", params, opts, partial(document_symbol_handler, bang)
  )
end

function M.workspace_symbol(bang, opts)
  if not check_capabilities("workspaceSymbolProvider") then
    return
  end

  local params = {query = opts.query or ''}
  call_sync(
    "workspace/symbol", params, opts, partial(workspace_symbol_handler, bang)
  )
end

function M.incoming_calls(bang, opts)
  if not check_capabilities("callHierarchyProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "callHierarchy/incomingCalls", params, opts, partial(incoming_calls_handler, bang)
  )
end

function M.outgoing_calls(bang, opts)
  if not check_capabilities("callHierarchyProvider") then
    return
  end

  local params = vim.lsp.util.make_position_params()
  call_sync(
    "callHierarchy/outgoingCalls", params, opts, partial(outgoing_calls_handler, bang)
  )
end

function M.code_action(bang, opts)
  if not check_capabilities("codeActionProvider") then
    return
  end

  local params = vim.lsp.util.make_range_params()
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics(),
  }
  call_sync(
    "textDocument/codeAction", params, opts, partial(code_action_handler, bang)
  )
end

function M.range_code_action(bang, opts)
  if not check_capabilities("codeActionProvider") then
    return
  end

  local params = vim.lsp.util.make_given_range_params()
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }
  call_sync(
    "textDocument/codeAction", params, opts, partial(code_action_handler, bang)
  )
end

function M.diagnostic(bang, opts)
  opts = opts or {}

  local bufnr = opts.bufnr or api.nvim_get_current_buf()
  local show_all = bufnr == "*"

  local buffer_diags
  if show_all then
    buffer_diags = vim.diagnostic.get(nil)
  else
    buffer_diags = vim.diagnostic.get(bufnr)
  end

  local severity = opts.severity
  local severity_limit = opts.severity_limit

  local items = {}
  for _, diag in ipairs(buffer_diags) do
    if severity then
      if not diag.severity then
        goto continue
      end

      if severity ~= diag.severity then
        goto continue
      end
    elseif severity_limit then
      if not diag.severity then
        goto continue
      end

      if severity_limit < diag.severity then
        goto continue
      end
    end

    table.insert(items, {
      filename = vim.api.nvim_buf_get_name(diag.bufnr),
      lnum = diag.lnum + 1,
      col = diag.col + 1,
      text = diag.message,
      type = vim.lsp.protocol.DiagnosticSeverity[diag.severity or
      vim.lsp.protocol.DiagnosticSeverity.Error]
    })
    ::continue::
  end

  table.sort(items, function(a, b) return a.lnum < b.lnum end)

  local fnamemodify = (function (filename)
    if filename ~= nil and show_all then
      return fn.fnamemodify(filename, ":~:.") .. ":"
    else
      return ""
    end
  end)

  local entries = {}
  for i, e in ipairs(items) do
    entries[i] = (
      e["type"]
      .. ": "
      .. e["text"]:gsub("%s", " ")
      .. "\x01 "
      .. fnamemodify(e["filename"])
      .. e["lnum"]
      .. ":"
      .. e["col"]
      .. ":"
    )
  end

  if vim.tbl_isempty(entries) then
    print("Empty diagnostic")
    return
  end

  fzf_locations(bang, "", "Diagnostics", entries, not show_all)
end
-- }}}

-- LSP FUNCTIONS {{{
M.code_action_call = partial(M.code_action, 0)
M.range_code_action_call = partial(M.range_code_action, 0)
M.definition_call = partial(M.definition, 0)
M.declaration_call = partial(M.declaration, 0)
M.type_definition_call = partial(M.type_definition, 0)
M.implementation_call = partial(M.implementation, 0)
M.references_call = partial(M.references, 0)
M.document_symbol_call = partial(M.document_symbol, 0)
M.workspace_symbol_call = partial(M.workspace_symbol, 0)
M.incoming_calls_call = partial(M.incoming_calls, 0)
M.outgoing_calls_call = partial(M.outgoing_calls, 0)
M.diagnostic_call = partial(M.diagnostic, 0)
-- }}}

-- LSP HANDLERS {{{
M.code_action_handler = mk_handler(partial(code_action_handler, 0))
M.definition_handler = mk_handler(partial(definition_handler, 0))
M.declaration_handler = mk_handler(partial(declaration_handler, 0))
M.type_definition_handler = mk_handler(partial(type_definition_handler, 0))
M.implementation_handler = mk_handler(partial(implementation_handler, 0))
M.references_handler = mk_handler(partial(references_handler, 0))
M.document_symbol_handler = mk_handler(partial(document_symbol_handler, 0))
M.workspace_symbol_handler = mk_handler(partial(workspace_symbol_handler, 0))
M.incoming_calls_handler = mk_handler(partial(incoming_calls_handler, 0))
M.outgoing_calls_handler = mk_handler(partial(outgoing_calls_handler, 0))
-- }}}

-- Lua SETUP {{{
M.setup = function(opts)
  opts = opts or {
    override_ui_select = true,
  }

  local function setup_nvim_0_6()
    if opts.override_ui_select then
      vim.ui.select = fzf_ui_select
    end
  end

  if vim.version()["major"] >= 0 and vim.version()["minor"] >= 6 then
    setup_nvim_0_6()
  end

  vim.lsp.handlers["textDocument/codeAction"] = M.code_action_handler
  vim.lsp.handlers["textDocument/definition"] = M.definition_handler
  vim.lsp.handlers["textDocument/declaration"] = M.declaration_handler
  vim.lsp.handlers["textDocument/typeDefinition"] = M.type_definition_handler
  vim.lsp.handlers["textDocument/implementation"] = M.implementation_handler
  vim.lsp.handlers["textDocument/references"] = M.references_handler
  vim.lsp.handlers["textDocument/documentSymbol"] = M.document_symbol_handler
  vim.lsp.handlers["workspace/symbol"] = M.workspace_symbol_handler
  vim.lsp.handlers["callHierarchy/incomingCalls"] = M.incoming_calls_handler
  vim.lsp.handlers["callHierarchy/outgoingCalls"] = M.outgoing_calls_handler
end
-- }}}

return M
