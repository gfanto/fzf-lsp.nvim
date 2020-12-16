local vim, fn, api, g = vim, vim.fn, vim.api, vim.g

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
-- }}}

-- LSP utility {{{
local function extract_result(results_lsp)
  local results = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(results, server_results.result)
    end
  end

  return results
end

local function call_sync(method, params, opts, handler)
  params = params or {}
  opts = opts or {}
  local results_lsp, err = vim.lsp.buf_request_sync(
    nil, method, params, opts.timeout or g.fzf_lsp_timeout
  )

  handler(err, method, extract_result(results_lsp), nil, nil)
end

local function code_action_execute(action)
  if action.edit or type(action.command) == "table" then
    if action.edit then
      vim.lsp.util.apply_workspace_edit(action.edit)
    end
    if type(action.command) == "table" then
      vim.lsp.buf.execute_command(action.command)
    end
  else
    vim.lsp.buf.execute_command(action)
  end
end

local function lines_from_locations(locations, include_filename)
  local fnamemodify = (function (filename)
    if include_filename then
      return fn.fnamemodify(filename, ":~:.") .. ":"
    else
      return ""
    end
  end)

  local lines = {}
  for _, loc in ipairs(locations) do
    table.insert(lines, (
        fnamemodify(loc['filename'])
        .. loc["lnum"]
        .. ":"
        .. loc["col"]
        .. ": "
        .. vim.trim(loc["text"])
    ))
  end

  return lines
end

local function location_handler(err, _, locations, _, bufnr, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not locations or vim.tbl_isempty(locations) then
    print(error_message)
    return
  end

  if vim.tbl_islist(locations) then
    if #locations == 1 then
      vim.lsp.util.jump_to_location(locations[1])

      return
    end
  else
    vim.lsp.util.jump_to_location(locations)
  end

  return lines_from_locations(vim.lsp.util.locations_to_items(locations, bufnr), true)
end

-- }}}

-- FZF functions {{{
local function fzf_wrap(name, options, bang)
  name = name or ""
  options = options or {}
  bang = bang or 0

  local sink_fn = options["sink*"] or options["sink"]
  options["sink"] = nil; options["sink*"] = 0
  local wrapped_options = fn["fzf#wrap"](name, options, bang)
  wrapped_options["sink*"] = sink_fn

  return wrapped_options
end

local function fzf_run(...)
  return fn["fzf#run"](...)
end

local function fzf_locations(bang, prompt, header, source, infile)
  local sink_fn
  local preview_cmd = (infile and
    (bin.preview .. " " .. fn.expand("%") .. ":{}") or
    (bin.preview .. " {}")
  )
  local options = {
    "--prompt", prompt .. ">",
    "--header", header,
    "--ansi",
    "--preview", preview_cmd,
  }

  if infile then
    sink_fn = (function(lines)
      local _, l = next(lines)
      local lnum, col = l:match("([^:]*):([^:]*)")
      fn.cursor(lnum, col)

      api.nvim_command("normal! zz")
    end)
  else
    vim.list_extend(options, {
      "--multi",
      '--bind', 'ctrl-a:select-all,ctrl-d:deselect-all',
      "--expect",
      table.concat(vim.tbl_keys(g.fzf_lsp_action), ",")
    })
    sink_fn = (function(lines)
      local key = table.remove(lines, 1)

      for _, l in ipairs(lines) do
        local path, lnum, col = l:match("([^:]*):([^:]*):([^:]*)")
        api.nvim_command((g.fzf_lsp_action[key] or "edit") .. " " .. path)
        fn.cursor(lnum, col)
      end

      api.nvim_command("normal! zz")
    end)
  end

  fzf_run(fzf_wrap("fzf_lsp", {
    source = source,
    sink = sink_fn,
    options = options,
  }, bang))
end

local function fzf_code_actions(bang, prompt, header, actions)
  local lines = {}
  for i, a in ipairs(actions) do
    a["idx"] = i
    lines[i] = a["idx"] .. ". " .. a["title"]
  end

  local sink_fn = (function(source)
    local _, line = next(source)
    local idx = tonumber(line:match("(%d+)[.]"))
    code_action_execute(actions[idx])
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
local code_action_handler = function(bang, err, _, result, _, _)
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

local definition_handler = function(bang, err, method, result, client_id, bufnr)
  local results = location_handler(err, method, result, client_id, bufnr, "Definition not found")
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Definitions", results, false)
  end
end

local declaration_handler = function(bang, err, method, result, client_id, bufnr)
  local results = location_handler(err, method, result, client_id, bufnr, "Declaration not found")
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Declarations", results, false)
  end
end

local type_definition_handler = function(bang, err, method, result, client_id, bufnr)
  local results = location_handler(err, method, result, client_id, bufnr, "Type Definition not found")
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Type Definitions", results, false)
  end
end

local implementation_handler = function(bang, err, method, result, client_id, bufnr)
  local results = location_handler(err, method, result, client_id, bufnr, "Implementation not found")
  if results and not vim.tbl_isempty(results) then
    fzf_locations(bang, "", "Implementations", results, false)
  end
end

local references_handler = function(bang, err, _, result, _, bufnr)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("References not found")
    return
  end

  local lines = lines_from_locations(vim.lsp.util.locations_to_items(result, bufnr), true)
  fzf_locations(bang, "", "References", lines, false)
end

local document_symbol_handler = function(bang, err, _, result, _, bufnr)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("Document Symbol not found")
    return
  end

  local lines = lines_from_locations(vim.lsp.util.symbols_to_items(result, bufnr), false)
  fzf_locations(bang, "", "Document Symbols", lines, true)
end

local workspace_symbol_handler = function(bang, err, _, result, _, bufnr)
  if err ~= nil then
    perror(err)
    return
  end

  if not result or vim.tbl_isempty(result) then
    print("Workspace Symbol not found")
    return
  end

  local lines = lines_from_locations(vim.lsp.util.symbols_to_items(result, bufnr), true)
  fzf_locations(bang, "", "Workspace Symbols", lines, false)
end
-- }}}

-- COMMANDS {{{
M.definition = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  call_sync("textDocument/definition", params, opts, partial(definition_handler, bang))
end

M.declaration = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  call_sync("textDocument/declaration", params, opts, partial(declaration_handler, bang))
end

M.type_definition = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  call_sync("textDocument/typeDefinition", params, opts, partial(type_definition_handler, bang))
end

M.implementation = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  call_sync("textDocument/implementation", params, opts, partial(implementation_handler, bang))
end

M.references = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }
  call_sync("textDocument/references", params, opts, partial(references_handler, bang))
end

M.document_symbol = function(bang, opts)
  local params = vim.lsp.util.make_position_params()
  call_sync("textDocument/documentSymbol", params, opts, partial(document_symbol_handler, bang))
end

M.workspace_symbol = function(bang, opts)
  local params = {query = opts.query or ''}
  call_sync("workspace/symbol", params, opts, partial(workspace_symbol_handler, bang))
end

M.code_action = function(bang, opts)
  local params = vim.lsp.util.make_range_params()
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }
  call_sync("textDocument/codeAction", params, opts, partial(code_action_handler, bang))
end

M.range_code_action = function(bang, opts)
  local params = vim.lsp.util.make_given_range_params()
  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }
  call_sync("textDocument/codeAction", params, opts, partial(code_action_handler, bang))
end

M.diagnostic = function(bang, opts)
  local bufnr = api.nvim_get_current_buf()
  local buffer_diags = vim.lsp.diagnostic.get(bufnr)

  local severity = opts.severity
  local severity_limit = opts.severity_limit

  local items = {}
  local insert_diag = function(diag)
    if severity then
      if not diag.severity then
        return
      end

      if severity ~= diag.severity then
        return
      end
    elseif severity_limit then
      if not diag.severity then
        return
      end

      if severity_limit < diag.severity then
        return
      end
    end

    local pos = diag.range.start
    local row = pos.line
    local col = vim.lsp.util.character_offset(bufnr, row, pos.character)

    table.insert(items, {
      lnum = row + 1,
      col = col + 1,
      text = diag.message,
      type = vim.lsp.protocol.DiagnosticSeverity[diag.severity or vim.lsp.protocol.DiagnosticSeverity.Error]
    })
  end

  for _, diag in ipairs(buffer_diags) do
    insert_diag(diag)
  end

  table.sort(items, function(a, b) return a.lnum < b.lnum end)

  local entries = {}
  for i, e in ipairs(items) do
    entries[i] = (
      e["lnum"]
      .. ':'
      .. e["col"]
      .. ':'
      .. e["type"]
      .. ': '
      .. e["text"]:gsub("%s", " ")
    )
  end

  if vim.tbl_isempty(entries) then
    print("Empty diagnostic")
    return
  end

  fzf_locations(bang, "", "Diagnostics", entries, true)
end
-- }}}

-- LSP HANDLERS {{{
M.code_action_handler = partial(code_action_handler, 0)
M.definition_handler = partial(definition_handler, 0)
M.declaration_handler = partial(declaration_handler, 0)
M.type_definition_handler = partial(type_definition_handler, 0)
M.implementation_handler = partial(implementation_handler, 0)
M.references_handler = partial(references_handler, 0)
M.document_symbol_handler = partial(document_symbol_handler, 0)
M.workspace_symbol_handler = partial(workspace_symbol_handler, 0)
-- }}}

return M
