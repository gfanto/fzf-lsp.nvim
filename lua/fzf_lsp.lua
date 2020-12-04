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

  local result = results_lsp[1]["result"]  -- XXX: it will be only one result or more?
  if result == nil or vim.tbl_isempty(result) then
    print("Definition not found")
    return nil
  end

  if vim.tbl_islist(result) then
    if #result == 1 then
      vim.lsp.util.jump_to_location(result[1])
    else
      return _make_entries_from_locations(vim.lsp.util.locations_to_items(result))
    end
  else
    vim.lsp.util.jump_to_location(result)
  end

  return nil
end

M.references = function(opts)
  local opts = opts or {}
  local params = vim.lsp.util.make_position_params()
  params.context = { includeDeclaration = true }

  local results_lsp = vim.lsp.buf_request_sync(0, "textDocument/references", params, opts.timeout or 10000)
  local locations = {}
  for _, server_results in pairs(results_lsp) do
    if server_results.result then
      vim.list_extend(locations, vim.lsp.util.locations_to_items(server_results.result) or {})
    end
  end

  if vim.tbl_isempty(locations) then
    return
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

  if vim.tbl_isempty(locations) then
    return
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

  if vim.tbl_isempty(locations) then
    return
  end

  return _make_entries_from_locations(locations)
end

return M

