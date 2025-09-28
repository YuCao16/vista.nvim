-- Unified state management for Vista.nvim
-- This module centralizes all state and provides clean APIs for accessing/modifying it

local M = {}

-- Internal state storage
local _state = {
  -- Core data
  outline_items = {},
  flattened_outline_items = {},
  classified_outline_items = {},
  type_items = {},

  -- UI state
  current_theme = "tree",
  is_open = false,
  current_filepath = nil,

  -- Buffer/Window references
  vista_bufnr = nil,
  vista_winnr = nil,
  source_bufnr = nil,
  lsp_bufnr = nil,
  code_win = nil,

  -- Cache and performance
  cache = {
    outline_items_hash = nil,
    type_items_hash = nil,
    flattened_cache = nil,
    classified_cache = nil,
  },

  -- Node indexing for fast lookups
  node_index = {
    by_winline = {},
    by_line = {},
  },

  -- Fold state
  fold_memory_enabled = true,

  -- Provider info
  current_provider = nil,
  lsp_filepath = nil,
}

-- State getters (read-only access)
function M.get_outline_items()
  return _state.outline_items
end

function M.get_flattened_items()
  return _state.flattened_outline_items
end

function M.get_classified_items()
  return _state.classified_outline_items
end

function M.get_type_items()
  return _state.type_items
end

function M.get_current_theme()
  return _state.current_theme
end

function M.get_vista_bufnr()
  return _state.vista_bufnr
end

function M.get_vista_winnr()
  return _state.vista_winnr
end

function M.get_source_bufnr()
  return _state.source_bufnr
end

function M.get_lsp_bufnr()
  return _state.lsp_bufnr
end

function M.get_code_win()
  return _state.code_win
end

function M.get_current_filepath()
  return _state.current_filepath
end

function M.is_vista_open()
  return _state.is_open
end

function M.get_cache()
  return _state.cache
end

function M.get_node_index()
  return _state.node_index
end

function M.get_lsp_filepath()
  return _state.lsp_filepath
end

function M.get_current_provider()
  return _state.current_provider
end

-- State setters (controlled modifications)
function M.set_outline_items(items)
  _state.outline_items = items or {}
  -- Clear related caches when outline items change
  M.clear_cache("outline")
end

function M.set_flattened_items(items)
  _state.flattened_outline_items = items or {}
end

function M.set_classified_items(items)
  _state.classified_outline_items = items or {}
  -- Clear related caches
  M.clear_cache("classified")
end

function M.set_type_items(items)
  _state.type_items = items or {}
  M.clear_cache("type")
end

function M.set_current_theme(theme)
  if theme == "tree" or theme == "type" then
    _state.current_theme = theme
  end
end

function M.set_vista_bufnr(bufnr)
  _state.vista_bufnr = bufnr
end

function M.set_vista_winnr(winnr)
  _state.vista_winnr = winnr
end

function M.set_source_bufnr(bufnr)
  _state.source_bufnr = bufnr
end

function M.set_lsp_bufnr(bufnr)
  _state.lsp_bufnr = bufnr
end

function M.set_code_win(winnr)
  _state.code_win = winnr
end

function M.set_current_filepath(filepath)
  _state.current_filepath = filepath
end

function M.set_vista_open(is_open)
  _state.is_open = is_open
end

function M.set_lsp_filepath(filepath)
  _state.lsp_filepath = filepath
end

function M.set_current_provider(provider)
  _state.current_provider = provider
end

-- Cache management
function M.clear_cache(cache_type)
  if cache_type == "all" or not cache_type then
    _state.cache.outline_items_hash = nil
    _state.cache.type_items_hash = nil
    _state.cache.flattened_cache = nil
    _state.cache.classified_cache = nil
    _state.node_index.by_winline = {}
    _state.node_index.by_line = {}
  elseif cache_type == "outline" then
    _state.cache.outline_items_hash = nil
    _state.cache.flattened_cache = nil
    _state.node_index.by_winline = {}
    _state.node_index.by_line = {}
  elseif cache_type == "type" then
    _state.cache.type_items_hash = nil
  elseif cache_type == "classified" then
    _state.cache.classified_cache = nil
  end
end

function M.update_cache(cache_type, key, value)
  if cache_type and key then
    _state.cache[cache_type] = _state.cache[cache_type] or {}
    _state.cache[cache_type][key] = value
  end
end

-- Node indexing
function M.update_node_index(index_type, key, value)
  if index_type == "winline" then
    _state.node_index.by_winline[key] = value
  elseif index_type == "line" then
    _state.node_index.by_line[key] = value
  end
end

function M.get_node_by_winline(winline)
  return _state.node_index.by_winline[winline]
end

function M.get_node_by_line(line)
  return _state.node_index.by_line[line]
end

-- Utility functions
function M.is_valid_vista_buffer()
  local bufnr = _state.vista_bufnr
  return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

function M.is_valid_vista_window()
  local winnr = _state.vista_winnr
  return winnr and vim.api.nvim_win_is_valid(winnr)
end

function M.reset()
  -- Reset to initial state (useful for cleanup)
  _state.outline_items = {}
  _state.flattened_outline_items = {}
  _state.classified_outline_items = {}
  _state.type_items = {}
  _state.current_filepath = nil
  _state.vista_bufnr = nil
  _state.vista_winnr = nil
  _state.source_bufnr = nil
  _state.lsp_bufnr = nil
  _state.code_win = nil
  _state.current_provider = nil
  _state.lsp_filepath = nil
  _state.is_open = false
  M.clear_cache("all")
end

-- Debug function to inspect state
function M.debug()
  return {
    outline_items_count = #_state.outline_items,
    flattened_items_count = #_state.flattened_outline_items,
    classified_items_count = vim.tbl_count(_state.classified_outline_items),
    current_theme = _state.current_theme,
    is_open = _state.is_open,
    current_filepath = _state.current_filepath,
    vista_bufnr = _state.vista_bufnr,
    vista_winnr = _state.vista_winnr,
    source_bufnr = _state.source_bufnr,
    cache_status = {
      outline_hash = _state.cache.outline_items_hash ~= nil,
      type_hash = _state.cache.type_items_hash ~= nil,
      flattened_cache = _state.cache.flattened_cache ~= nil,
      classified_cache = _state.cache.classified_cache ~= nil,
    }
  }
end

return M