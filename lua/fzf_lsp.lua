local vim = vim

local M = {}
M.handlers = {}

local function perror(err)
  print("ERROR: " .. tostring(err))
end

local function string_trim (s)
  return s:gsub("^%s+", ""):gsub("%s+$", "")
end

local function string_plain (s)
  return s:gsub("%s", " ")
end

local function make_lines_from_locations (locations, include_filename)
  local fnamemodify = (function (filename)
    if include_filename then
      return vim.fn.fnamemodify(filename, ":.") .. ":"
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
        .. string_trim(loc["text"])
    ))
  end

  return lines
end

local function code_actions_call(opts)
  local params = opts.params or vim.lsp.util.make_range_params()

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, opts.timeout or 5000)

  if err then
    perror(err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/codeAction")
    return
  end

  local _, response = next(results_lsp)

  local results = response and response.result or {}
  for i, x in ipairs(results or {}) do
    x.idx = i
  end

  return results
end

local function location_call(method, params, opts, error_message)
  local results_lsp, err = vim.lsp.buf_request_sync(nil, method, params, opts.timeout or 5000)

  if err ~= nil then
    perror(err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from " .. method)
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  if #locations == 0 then
    print(error_message)
  elseif #locations == 1 then
    for _, server_results in pairs(results_lsp) do
      if server_results.result then

        if vim.tbl_islist(server_results.result) then
          vim.lsp.util.jump_to_location(server_results.result[1])
        else
          vim.lsp.uti.jump_to_location(server_results.result)
        end

        return
      end
    end
  else
    return make_lines_from_locations(locations, true)
  end
end

local function refereces_call(method, params, opts, error_message)
  opts = opts or {}
  params = params or {}
  local results_lsp, err = vim.lsp.buf_request_sync(0, method, params, opts.timeout or 5000)

  if err ~= nil then
    perror(err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from " .. method)
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    print(error_message)
    return
  end

  return make_lines_from_locations(locations, true)
end

local function symbol_call(method, params, opts, error_message, include_filename)
  opts = opts or {}
  params = params or {}
  local results_lsp, err = vim.lsp.buf_request_sync(0, method, params, opts.timeout or 5000)

  if err ~= nil then
    perror(err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from " .. method)
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    print(error_message)
    return
  end

  return make_lines_from_locations(locations, include_filename)
end

M.definition = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()

  return location_call("textDocument/definition", params, opts, "Definition not found")
end

M.declaration = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()

  return location_call("textDocument/declaration", params, opts, "Declaration not found")
end

M.type_definition = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()

  return location_call("textDocument/typeDefinition", params, opts, "Type Definition not found")
end

M.implementation = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()

  return location_call("textDocument/implementation", params, opts, "Implementation not found")
end

M.references = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  return refereces_call("textDocument/references", params, opts, "References not found")
end

M.document_symbol = function(opts)
  opts = opts or {}
  local params = vim.lsp.util.make_position_params()

  return symbol_call("textDocument/documentSymbol", params, opts, "Document Symbol not found", false)
end

M.workspace_symbol = function(opts)
  opts = opts or {}
  local params = {query = opts.query or ''}

  return symbol_call("workspace/symbol", params, opts, "Workspace Symbol not found", true)
end

M.code_action = function(opts)
  opts = opts or {}
  local results = code_actions_call(opts)
  if vim.tbl_isempty(results) then
    print("Code Action not available")
    return
  end

  return results
end

M.range_code_action = function(opts)
  opts = opts or {}
  opts.params = vim.lsp.util.make_given_range_params()

  local results = code_actions_call(opts)
  if vim.tbl_isempty(results) then
    print("Code Action not available in range")
    return
  end

  return results
end

M.code_action_execute = function(action)
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

M.diagnostic = function(opts)
  local bufnr = vim.api.nvim_get_current_buf()
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
      .. string_plain(e["text"])
    )
  end

  if vim.tbl_isempty(entries) then
    print("Empty diagnostic")
    return
  end

  return entries
end

local function _code_actions_handler (err, _, actions, _, _, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not actions or vim.tbl_isempty(actions) then
    print(error_message)
    return
  end

  for i, x in ipairs(actions) do
    x.idx = i
  end

  return actions
end

local function _location_handler (err, _, locations, _, bufnr, error_message)
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

  return make_lines_from_locations(vim.lsp.util.locations_to_items(locations, bufnr), true)
end

local function _references_handler(err, _, locations, _, bufnr, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not locations or vim.tbl_isempty(locations) then
    print(error_message)
    return
  end

  return make_lines_from_locations(vim.lsp.util.locations_to_items(locations, bufnr), true)
end

local function _document_symbol_handler (err, _, symbols, _, bufnr, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not symbols or vim.tbl_isempty(symbols) then
    print(error_message)
    return
  end

  return make_lines_from_locations(vim.lsp.util.symbols_to_items(symbols, bufnr), false)
end

local function _symbol_handler(err, _, symbols, _, bufnr, error_message)
  if err ~= nil then
    perror(err)
    return
  end

  if not symbols or vim.tbl_isempty(symbols) then
    print(error_message)
    return
  end

  return make_lines_from_locations(vim.lsp.util.symbols_to_items(symbols, bufnr), true)
end

M.code_action_handler = function(err, method, result, client_id, bufnr)
  local results = _code_actions_handler(err, method, result, client_id, bufnr, "Code Action not available")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#code_action_handler"](results)
  end
end

M.definition_handler = function(err, method, result, client_id, bufnr)
  local results = _location_handler(err, method, result, client_id, bufnr, "Definition not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#definition_handler"](results)
  end
end

M.declaration_handler = function(err, method, result, client_id, bufnr)
  local results = _location_handler(err, method, result, client_id, bufnr, "Declaration not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#declaration_handler"](results)
  end
end

M.type_definition_handler = function(err, method, result, client_id, bufnr)
  local results = _location_handler(err, method, result, client_id, bufnr, "Type Definition not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#type_definition_handler"](results)
  end
end

M.implementation_handler = function(err, method, result, client_id, bufnr)
  local results = _location_handler(err, method, result, client_id, bufnr, "Implementation not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#implementation_handler"](results)
  end
end

M.references_handler = function(err, method, result, client_id, bufnr)
  local results = _references_handler(err, method, result, client_id, bufnr, "References not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#references_handler"](results)
  end
end

M.document_symbol_handler = function(err, method, result, client_id, bufnr)
  local results = _document_symbol_handler(err, method, result, client_id, bufnr, "Document Symbol not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#document_symbol_handler"](results)
  end
end

M.workspace_symbol_handler = function(err, method, result, client_id, bufnr)
  local results = _symbol_handler(err, method, result, client_id, bufnr, "Workspace Symbol not found")
  if results and not vim.tbl_isempty(results) then
    vim.fn["fzf_lsp#workspace_symbol_handler"](results)
  end
end

return M
