local M = {}
local config = require("vista-nvim.config")

-- In-memory fold state cache
M._fold_cache = {}

-- Get unique key for current file and theme
local function get_file_key()
  local view = require("vista-nvim.view")
  local basic = require("vista-nvim.handlers.basic")

  -- Use the LSP buffer (source file) not the Vista buffer
  local filepath
  if view.View.lsp_bufnr and vim.api.nvim_buf_is_valid(view.View.lsp_bufnr) then
    filepath = vim.api.nvim_buf_get_name(view.View.lsp_bufnr)
  elseif basic.state.current_bufnr and vim.api.nvim_buf_is_valid(basic.state.current_bufnr) then
    filepath = vim.api.nvim_buf_get_name(basic.state.current_bufnr)
  else
    -- Fallback to current buffer
    filepath = vim.api.nvim_buf_get_name(0)
  end

  local theme = basic.current_theme or "tree"
  return filepath .. ":" .. theme
end

-- Load fold state from file
function M.load_fold_state()
  if not config.remember_fold_state then
    return {}
  end

  local ok, data = pcall(function()
    local file = io.open(config.fold_state_file, "r")
    if not file then return {} end

    local content = file:read("*all")
    file:close()

    if content and content ~= "" then
      return vim.json.decode(content)
    end
    return {}
  end)

  if ok and type(data) == "table" then
    M._fold_cache = data
    return data
  else
    M._fold_cache = {}
    return {}
  end
end

-- Save fold state to file
function M.save_fold_state()
  if not config.remember_fold_state then
    return
  end

  local ok = pcall(function()
    local file = io.open(config.fold_state_file, "w")
    if file then
      file:write(vim.json.encode(M._fold_cache))
      file:close()
    end
  end)

  if not ok then
    -- Silently fail if we can't save (e.g., permission issues)
    return
  end
end

-- Save current fold state for current file
function M.save_current_state()
  if not config.remember_fold_state then
    return
  end

  local basic = require("vista-nvim.handlers.basic")
  local file_key = get_file_key()

  if basic.current_theme == "tree" then
    -- Save tree mode fold state
    local fold_state = {}
    local function collect_fold_state(items, path)
      path = path or ""
      for i, item in ipairs(items or {}) do
        local item_path = path .. ":" .. (item.name or "") .. ":" .. (item.kind or "")
        if item.folded ~= nil then
          fold_state[item_path] = item.folded
        end
        if item.children then
          collect_fold_state(item.children, item_path)
        end
      end
    end

    collect_fold_state(basic.state.outline_items)
    M._fold_cache[file_key] = { type = "tree", state = fold_state }

  elseif basic.current_theme == "type" then
    -- Save type mode fold state
    local fold_state = {}
    for kind, node in pairs(basic.state.classified_outline_items or {}) do
      fold_state[tostring(kind)] = node.expand
    end
    M._fold_cache[file_key] = { type = "type", state = fold_state }
  end

  M.save_fold_state()
end

-- Restore fold state for current file
function M.restore_current_state()
  if not config.remember_fold_state then
    return
  end

  local basic = require("vista-nvim.handlers.basic")
  local file_key = get_file_key()
  local saved_state = M._fold_cache[file_key]

  if not saved_state or not saved_state.state then
    return
  end

  if basic.current_theme == "tree" and saved_state.type == "tree" then
    -- Restore tree mode fold state
    local function restore_fold_state(items, path)
      path = path or ""
      for i, item in ipairs(items or {}) do
        local item_path = path .. ":" .. (item.name or "") .. ":" .. (item.kind or "")
        if saved_state.state[item_path] ~= nil then
          item.folded = saved_state.state[item_path]
        end
        if item.children then
          restore_fold_state(item.children, item_path)
        end
      end
    end

    restore_fold_state(basic.state.outline_items)

  elseif basic.current_theme == "type" and saved_state.type == "type" then
    -- Restore type mode fold state
    for kind, node in pairs(basic.state.classified_outline_items or {}) do
      local saved_expand = saved_state.state[tostring(kind)]
      if saved_expand ~= nil then
        node.expand = saved_expand
      end
    end
  end

  -- Trigger update to reflect restored state
  local writer = require("vista-nvim.writer")
  local view = require("vista-nvim.view")

  if basic.current_theme == "type" then
    if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
      writer.parse_and_write(view.View.bufnr, basic.state.classified_outline_items)
    end
  else
    -- Regenerate flattened items after restoring fold state
    local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
    basic.state.flattened_outline_items = lsp_parser.flatten(basic.state.outline_items)

    if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
      writer.parse_and_write(view.View.bufnr, basic.state.flattened_outline_items)
    end
  end
end

-- Initialize fold memory (load from file)
function M.init()
  M.load_fold_state()
end

-- Clean up old entries (keep only recent N files)
function M.cleanup(max_entries)
  max_entries = max_entries or 50

  if not M._fold_cache then return end

  local keys = {}
  for k, _ in pairs(M._fold_cache) do
    table.insert(keys, k)
  end

  if #keys > max_entries then
    -- Remove oldest entries (simple cleanup, could be improved with timestamps)
    table.sort(keys)
    for i = 1, #keys - max_entries do
      M._fold_cache[keys[i]] = nil
    end
    M.save_fold_state()
  end
end

return M