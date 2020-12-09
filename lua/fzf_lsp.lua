local M = {}

local _make_entries_from_locations = function(locations, shorten_path)
  local modifier = shorten_path and ":t" or ":."
  local fnamemodify = vim.fn.fnamemodify
  local entries = {}
  for i, loc in ipairs(locations) do
    entries[i] = fnamemodify(loc['filename'], modifier) .. ":" .. loc["lnum"] .. ":" .. loc["col"] .. ": " .. loc["text"]:gsub("^%s+", ""):gsub("%s+$", "")
  end

  return entries
end

M.definition = function(opts)
  local opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/definition", params, opts.timeout or 10000)
  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/definition")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  return _make_entries_from_locations(locations)
end

M.references = function(opts)
  local opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/references")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  return _make_entries_from_locations(locations)
end

M.document_symbols = function(opts)
  local opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/documentSymbol", params, opts.timeout or 10000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/documentSymbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
  end

  return _make_entries_from_locations(locations, true)
end

M.workspace_symbols = function(opts)
  local opts = opts or {}
  local params = {query = opts.query or ''}
  local results_lsp = vim.lsp.buf_request_sync(0, "workspace/symbol", params, opts.timeout or 10000)

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from workspace/symbol")
    return
  end

  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.symbols_to_items(server_results.result, 0) or {})
    end
  end

  return _make_entries_from_locations(locations)
end

M.code_actions = function(opts)
  local opts = opts or {}
  local params = opts.params or vim.lsp.util.make_range_params()

  params.context = {
    diagnostics = vim.lsp.diagnostic.get_line_diagnostics()
  }

  local results_lsp, err = vim.lsp.buf_request_sync(0, "textDocument/codeAction", params, opts.timeout or 10000)

  if err then
    print("ERROR: " .. err)
    return
  end

  if not results_lsp or vim.tbl_isempty(results_lsp) then
    print("No results from textDocument/codeAction")
    return
  end

  local results = (results_lsp[1] or results_lsp[2]).result;

  for i, x in ipairs(results or {}) do
    x.idx = i
  end

  return results
end

M.range_code_actions = function(opts)
  local opts = opts or {}
  opts.params = vim.lsp.util.make_given_range_params()
  return M.code_actions(opts)
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

M.diagnostics = function(opts)
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

  local filename = vim.fn.expand("%:t")
  local entries = {}
  for i, e in ipairs(items) do
    entries[i] = filename .. ':' .. e["lnum"] .. ':' .. e["col"] .. ':' .. e["type"] .. ': ' .. e["text"]:gsub("%s", " ")
  end

  return entries
end

return M
