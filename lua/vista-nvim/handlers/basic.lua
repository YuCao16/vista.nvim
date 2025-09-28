local writer = require("vista-nvim.writer")
local config = require("vista-nvim.config")
local folding = require("vista-nvim.folding")
local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
local utils_lsp = require("vista-nvim.utils.lsp_utils")
local utils_basic = require("vista-nvim.utils.basic")
local view = require("vista-nvim.view")
local providers = require("vista-nvim.providers.init")
local kind = require("vista-nvim.render").kinds_number
local fold_memory = require("vista-nvim.fold_memory")

local a = vim.api

local M = {}

M.state = require("vista-nvim").data
M.current_theme = writer.structure_theme
M.lsp_filepath = nil

M.handler_bindings = {
  ["<CR>"] = function()
    require("vista-nvim.handlers.basic").goto_location(true)
  end,
  ["<2-LeftMouse>"] = function()
    require("vista-nvim.handlers.basic").goto_location(true)
  end,
  ["p"] = function()
    require("vista-nvim.handlers.basic").goto_location(false)
  end,
  ["o"] = function()
    require("vista-nvim.handlers.basic").toggle_fold()
  end,
  ["zr"] = function()
    require("vista-nvim.handlers.basic").set_all_folded(true)
  end,
  ["zR"] = function()
    require("vista-nvim.handlers.basic").set_all_folded(false)
  end,
  ["s"] = function()
    require("vista-nvim.handlers.basic")._switch_theme()
  end,
}

-- convert a function to callback string
function M.execute_binding(key)
  key = utils_basic.unescape_keycode(key)
  M.handler_bindings[key]()
end

function M.setup_handler_binding()
  for key, _ in pairs(M.handler_bindings) do
    a.nvim_buf_set_keymap(
      view.View.bufnr,
      "n",
      key,
      string.format(
        ":lua require('vista-nvim.handlers.basic').execute_binding('%s')<CR>",
        utils_basic.escape_keycode(key)
      ),
      { noremap = true, silent = true, nowait = true }
    )
  end
  vim.api.nvim_create_autocmd({
    "TextChanged",
    "BufWritePost",
  }, {
    pattern = "*",
    callback = function()
      if vim.fn.bufnr() == view.View.bufnr then
        return
      end
      M._update_lines(true)
    end,
  })
end

local function wipe_state()
  -- Save fold state before wiping
  fold_memory.save_current_state()
  fold_memory.cleanup() -- Clean up old entries

  M.state = {
    outline_items = {},
    flattened_outline_items = {},
    type_items = {},
    classified_outline_items = {},
    code_win = 0,
  }

  -- Clear caches when wiping state
  M._state_cache = {
    outline_items_hash = nil,
    type_items_hash = nil,
    flattened_cache = nil,
    classified_cache = nil,
  }
  M._node_index = {
    by_winline = {},
    by_line = {},
  }
end

-- Cache for computed states to avoid unnecessary recalculations
M._state_cache = {
  outline_items_hash = nil,
  type_items_hash = nil,
  flattened_cache = nil,
  classified_cache = nil,
}

-- Simple hash function for cache validation
local function hash_items(items)
  if not items or #items == 0 then return "empty" end
  -- Create a simple hash based on item count and first/last item properties
  local first = items[1]
  local last = items[#items]
  return string.format("%d_%s_%d_%s_%d",
    #items,
    first and first.name or "nil",
    first and first.line or 0,
    last and last.name or "nil",
    last and last.line or 0
  )
end

function M._update_lines(ext)
  ext = ext or false
  if #vim.lsp.get_active_clients({ bufnr = 0 }) ~= 0 then
    if M.lsp_filepath ~= vim.api.nvim_buf_get_name(0) then
      M.lsp_filepath = vim.api.nvim_buf_get_name(0)
    else
      if not ext then
        return
      end
    end
  end

  -- If ext is true, force clear all caches to ensure full update
  if ext then
    M._state_cache.outline_items_hash = nil
    M._state_cache.type_items_hash = nil
    M._state_cache.flattened_cache = nil
    M._state_cache.classified_cache = nil
    M._node_index.by_winline = {}
    M._node_index.by_line = {}
  end

  -- Check cache for flattened_outline_items (if caching enabled)
  if config.cache_enabled and not ext then
    local outline_hash = hash_items(M.state.outline_items)
    if M._state_cache.outline_items_hash ~= outline_hash or not M._state_cache.flattened_cache then
      M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
      M._state_cache.flattened_cache = M.state.flattened_outline_items
      M._state_cache.outline_items_hash = outline_hash
      -- Clear tree node index when data changes
      M._node_index.by_winline = {}
      M._node_index.by_line = {}
    else
      M.state.flattened_outline_items = M._state_cache.flattened_cache
    end

    -- Check cache for classified_outline_items (but preserve manual fold states)
    local type_hash = hash_items(M.state.type_items)
    if M._state_cache.type_items_hash ~= type_hash or not M._state_cache.classified_cache then
      -- Save current expand states before reclassifying
      local current_expand_states = {}
      if M.state.classified_outline_items then
        for k, v in pairs(M.state.classified_outline_items) do
          current_expand_states[k] = v.expand
        end
      end

      M.state.classified_outline_items = lsp_parser.classify(M.state.type_items)

      -- Restore expand states
      for k, expand_state in pairs(current_expand_states) do
        if M.state.classified_outline_items[k] then
          M.state.classified_outline_items[k].expand = expand_state
        end
      end

      M._state_cache.classified_cache = M.state.classified_outline_items
      M._state_cache.type_items_hash = type_hash
    else
      M.state.classified_outline_items = M._state_cache.classified_cache
    end
  else
    -- No caching, always recompute but preserve expand states
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
    -- Clear tree node index when data changes
    M._node_index.by_winline = {}
    M._node_index.by_line = {}

    -- Save current expand states before reclassifying
    local current_expand_states = {}
    if M.state.classified_outline_items then
      for k, v in pairs(M.state.classified_outline_items) do
        current_expand_states[k] = v.expand
      end
    end

    M.state.classified_outline_items = lsp_parser.classify(M.state.type_items)

    -- Restore expand states
    for k, expand_state in pairs(current_expand_states) do
      if M.state.classified_outline_items[k] then
        M.state.classified_outline_items[k].expand = expand_state
      end
    end
  end

  if writer.structure_theme == "type" then
    writer.parse_and_write(view.View.bufnr, M.state.classified_outline_items)
    return
  end
  writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)
end

function M._merge_items(items)
  utils_lsp.merge_items_rec({ children = items }, { children = M.state.outline_items })
end

function M.handler(response)
  vim.api.nvim_echo({ { "handler called firstly", "None" } }, false, {})
  M.setup_handler_binding()
  if response == nil or type(response) ~= "table" then
    return
  end

  M.state.code_win = vim.api.nvim_get_current_win()
  M.state.current_bufnr = vim.fn.bufnr()
  view.View.lsp_bufnr = vim.fn.bufnr()
  M.lsp_filepath = vim.api.nvim_buf_get_name(0)

  -- clear state when buffer is closed
  vim.api.nvim_buf_attach(view.View.bufnr, false, {
    on_detach = function(_, _)
      wipe_state()
    end,
  })

  local items = lsp_parser.parse(response)
  local items_type = lsp_parser.parse_type(response)

  M.state.outline_items = items
  M.state.type_items = items_type
  M.state.flattened_outline_items = lsp_parser.flatten(items)
  M.state.classified_outline_items = lsp_parser.classify(items_type)

  -- Clear caches when new data arrives
  M._state_cache.outline_items_hash = nil
  M._state_cache.type_items_hash = nil
  M._state_cache.flattened_cache = nil
  M._state_cache.classified_cache = nil
  M._node_index.by_winline = {}
  M._node_index.by_line = {}

  -- Initialize fold memory and restore saved state
  fold_memory.init()
  fold_memory.restore_current_state()

  if M.current_theme == "type" then
    writer.parse_and_write(view.View.bufnr, M.state.classified_outline_items)
    return
  end
  writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)

  M._highlight_current_item(M.state.code_win)
end

function M.refresh_handler(response)
  if response == nil or type(response) ~= "table" then
    return
  end

  local items = lsp_parser.parse(response)
  local items_type = lsp_parser.parse_type(response)
  M._merge_items(items)
  -- TODO: Merge items_type as well

  M.state.type_items = items_type
  M.state.code_win = vim.api.nvim_get_current_win()
  M.state.current_bufnr = vim.fn.bufnr()
  view.View.lsp_bufnr = vim.fn.bufnr()

  -- Restore fold state after refresh
  fold_memory.restore_current_state()

  M._update_lines()
end

---------------
--goto_location
---------------
-- Node index mapping for O(1) lookups
M._node_index = {
  by_winline = {},
  by_line = {},
}

-- Build index for fast node lookups - for flattened tree items
local function build_tree_node_index()
  M._node_index.by_winline = {}
  M._node_index.by_line = {}

  for i, node in ipairs(M.state.flattened_outline_items or {}) do
    M._node_index.by_winline[i] = node
    if node.line then
      M._node_index.by_line[node.line] = node
    end
  end
end

-- Find node for type mode (different from tree mode)
local function find_node(data, line)
  for _, node in pairs(data or {}) do
    if node.winline == line then
      return node
    end
  end
  return nil
end

function M._current_node()
  local current_line = vim.api.nvim_win_get_cursor(view.get_winnr())[1] - view.View.title_line

  -- Ensure we have the current flattened items
  if not M.state.flattened_outline_items or #M.state.flattened_outline_items == 0 then
    return nil
  end

  -- Build index if needed
  if not M._node_index.by_winline or not next(M._node_index.by_winline) then
    build_tree_node_index()
  end

  return M.state.flattened_outline_items[current_line]
end

function M.goto_location(change_focus)
  local res = true
  if M.current_theme == "tree" then
    res = M.goto_location_tree(change_focus)
  elseif M.current_theme == "type" then
    res = M.goto_location_type(change_focus)
  end
  if config.auto_close then
    M.close_outline()
  end
  if res then
    return
  end
end

function M.goto_location_tree(change_focus)
  local node = M._current_node()
  vim.api.nvim_win_set_cursor(M.state.code_win, { node.line + 1, node.character })
  utils_basic.flash_highlight(M.state.current_bufnr, node.line + 1)
  if change_focus then
    vim.fn.win_gotoid(M.state.code_win)
    vim.cmd("normal! zz")
  end
  return false
end

function M.goto_location_type(change_focus)
  local has_splitkeep, splitkeep = pcall(vim.api.nvim_get_option_value, "splitkeep", {})
  local curline = vim.api.nvim_win_get_cursor(0)[1] - 1
  local node
  for _, nodes in pairs(M.state.classified_outline_items) do
    node = find_node(nodes.data, curline)
    if node then
      break
    end
  end

  if not node then
    return true
  end
  local range = node.range and node.range or node.location.range

  local winid = M.state.code_win
  if node.pos then
    vim.api.nvim_win_set_cursor(winid, { node.pos[1] + 1, node.pos[2] })
    utils_basic.flash_highlight(M.state.current_bufnr, node.pos[1] + 1)
  else
    vim.api.nvim_win_set_cursor(winid, { range.start.line + 1, range.start.character })
    utils_basic.flash_highlight(range.start.line, range.start.character)
  end
  if change_focus then
    vim.fn.win_gotoid(M.state.code_win)
    vim.cmd("normal! zz")
  end
  if has_splitkeep and splitkeep ~= "cursor" then
    if node.pos then
      vim.api.nvim_win_set_cursor(winid, { node.pos[1] + 1, node.pos[2] })
    else
      vim.api.nvim_win_set_cursor(winid, { range.start.line + 1, range.start.character })
    end
  end
  return false
end

---------------
-- switch theme
---------------
function M._switch_theme()
  -- Save current theme's fold state before switching
  fold_memory.save_current_state()

  local current_theme = writer.structure_theme
  if current_theme == "tree" then
    writer.structure_theme = "type"
  elseif current_theme == "type" then
    writer.structure_theme = "tree"
  end
  M.current_theme = writer.structure_theme

  -- Force update when switching themes
  M._update_lines(true)

  -- Restore fold state for new theme
  fold_memory.restore_current_state()
end

---------------
-- fold
---------------
function M._set_folded(folded, move_cursor, node_index)
  local node = M.state.flattened_outline_items[node_index] or M._current_node()

  if not node then
    return
  end

  local changed = (folded ~= folding.is_folded(node))

  if folding.is_foldable(node) and changed then
    -- Find the corresponding node in outline_items and set folded state there
    -- This ensures the state persists when flattened_outline_items is regenerated
    local function set_folded_in_outline_items(items, target_node)
      for _, item in ipairs(items) do
        if item.name == target_node.name and
           item.line == target_node.line and
           item.kind == target_node.kind then
          item.folded = folded
          return true
        end
        if item.children and set_folded_in_outline_items(item.children, target_node) then
          return true
        end
      end
      return false
    end

    -- Set folded state in the original outline_items
    if M.state.outline_items then
      set_folded_in_outline_items(M.state.outline_items, node)
    end

    -- Also set it in the current flattened node for immediate effect
    node.folded = folded

    if move_cursor then
      vim.api.nvim_win_set_cursor(view.get_winnr(), { node_index, 0 })
    end

    -- Force regenerate flattened items and update display
    local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)

    -- Clear caches to force complete refresh
    if M._state_cache then
      M._state_cache.outline_items_hash = nil
      M._state_cache.flattened_cache = nil
    end
    if M._node_index then
      M._node_index.by_winline = {}
      M._node_index.by_line = {}
    end

    -- Force update the display
    M._update_lines(true)
  elseif node.parent then
    local parent_node = M.state.flattened_outline_items[node.parent.line_in_outline]

    if parent_node then
      M._set_folded(folded, not parent_node.folded and folded, parent_node.line_in_outline)
    end
  end
end

function M.toggle_fold()
  if M.current_theme == "tree" then
    M.toggle_fold_tree()
  elseif M.current_theme == "type" then
    M.toggle_fold_type()
  end
end

function M.toggle_fold_tree()
  local node = M._current_node()
  if not node then
    return
  end

  if folding.is_foldable(node, M.current_theme) then
    -- Toggle the folded state
    local new_folded = not folding.is_folded(node)

    -- Find and update the node in the original outline_items
    local function set_folded_in_outline(items, target_node)
      for _, item in ipairs(items) do
        if item.name == target_node.name and
           item.line == target_node.line and
           item.kind == target_node.kind then
          item.folded = new_folded
          return true
        end
        if item.children and set_folded_in_outline(item.children, target_node) then
          return true
        end
      end
      return false
    end

    if M.state.outline_items then
      set_folded_in_outline(M.state.outline_items, node)
    end

    -- Regenerate flattened items
    local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)

    -- Force re-render
    if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
      writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)
    end

    -- Save fold state after toggle
    fold_memory.save_current_state()
  end
end

function M.toggle_fold_type()
  local curline = vim.api.nvim_win_get_cursor(0)[1]  -- This is 1-based
  local node = nil

  -- Find node in classified_outline_items structure
  for _, nodes in pairs(M.state.classified_outline_items) do
    if nodes.winline == curline then
      node = nodes
      break
    end
    -- Check if we're on an individual item (not a category header)
    for _, item in pairs(nodes.data or {}) do
      if item.winline == curline then
        return -- Don't toggle individual items, only category headers
      end
    end
  end

  if not node then
    return
  end

  -- Toggle the expand state
  node.expand = not node.expand

  -- Force immediate re-render
  if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
    writer.parse_and_write(view.View.bufnr, M.state.classified_outline_items)
  end

  -- Save fold state after toggle
  fold_memory.save_current_state()

  -- Keep cursor on the same category line (the winline may have changed after re-render)
  for _, nodes in pairs(M.state.classified_outline_items) do
    if nodes == node and nodes.winline and nodes.winline > 0 then
      vim.api.nvim_win_set_cursor(view.get_winnr(), { nodes.winline, 0 })
      break
    end
  end
end

-- Old implementation for reference (to be removed)
function M.toggle_fold_type_old()
  local curline = vim.api.nvim_win_get_cursor(0)[1] - 1
  local node = nil

  -- Find node in classified_outline_items structure
  for _, nodes in pairs(M.state.classified_outline_items) do
    if nodes.winline == curline then
      node = nodes
      break
    end
    -- Also check within node data for individual items
    for _, item in pairs(nodes.data or {}) do
      if item.winline == curline then
        return -- Don't toggle individual items, only category headers
      end
    end
  end

  if not node then
    return
  end

  local function increase_or_reduce(lnum, num)
    for k, v in pairs(M.state.classified_outline_items) do
      if v.winline > lnum then
        M.state.classified_outline_items[k].winline = M.state.classified_outline_items[k].winline
          + num
        for _, item in pairs(v.data) do
          item.winline = item.winline + num
        end
      end
    end
  end

  if node.expand then
    local text = vim.api.nvim_get_current_line()
    text = text:gsub(config.fold_markers[1], config.fold_markers[2])
    for _, v in pairs(node.data) do
      v.winline = -1
    end
    vim.bo[view.View.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(view.View.bufnr, curline, curline + #node.data + 1, false, { text })
    vim.bo[view.View.bufnr].modifiable = false
    node.expand = false
    vim.api.nvim_buf_add_highlight(view.View.bufnr, 0, "VistaConnector", curline, 0, 5)
    vim.api.nvim_buf_add_highlight(
      view.View.bufnr,
      0,
      "VistaOutline" .. kind[node.data[1].kind][1],
      curline,
      5,
      -1
    )
    increase_or_reduce(node.winline + #node.data, -#node.data)
    return
  end

  local lines = {}
  local text = vim.api.nvim_get_current_line()
  text = text:gsub(config.fold_markers[2], config.fold_markers[1])
  table.insert(lines, text)
  for i, v in pairs(node.data) do
    table.insert(lines, v.name)
    v.winline = curline + i
  end
  vim.bo[view.View.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(view.View.bufnr, curline, curline + 1, false, lines)
  vim.bo[view.View.bufnr].modifiable = false
  node.expand = true
  vim.api.nvim_buf_add_highlight(view.View.bufnr, 0, "VistaConnector", curline, 0, 5)
  vim.api.nvim_buf_add_highlight(
    view.View.bufnr,
    0,
    "VistaOutline" .. kind[node.data[1].kind][1],
    curline,
    5,
    -1
  )
  for _, v in pairs(node.data) do
    for group, scope in pairs(v.hi_scope) do
      vim.api.nvim_buf_add_highlight(view.View.bufnr, 0, group, v.winline, scope[1], scope[2])
    end
  end

  increase_or_reduce(node.winline, #node.data)

  -- Save fold state after toggle
  fold_memory.save_current_state()
end

function M._set_all_folded(folded, nodes)
  nodes = nodes or M.state.outline_items

  for _, node in ipairs(nodes) do
    node.folded = folded
    if node.children then
      M._set_all_folded(folded, node.children)
    end
  end
end

-- Set all items folded for type mode
function M._set_all_folded_type(expand)
  for _, node in pairs(M.state.classified_outline_items) do
    node.expand = expand
  end
end

function M.set_all_folded(folded, nodes)
  if M.current_theme == "type" then
    -- For type mode, folded=true means expand=false (collapsed)
    M._set_all_folded_type(not folded)
    -- Force regenerate the display
    if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
      writer.parse_and_write(view.View.bufnr, M.state.classified_outline_items)
    end
  else
    -- For tree mode
    M._set_all_folded(folded, nodes or M.state.outline_items)
    -- Regenerate flattened items after fold change
    local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
    -- Force update
    if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
      writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)
    end
  end

  -- Save fold state after setting all
  fold_memory.save_current_state()
end

function M.is_empty_line()
  if a.nvim_get_current_line() == "" then
    return true
  else
    return false
  end
end

---------------
-- highlight
---------------
-- TODO: toggle logic need improvement
-- eg. if current line is return, then highlight return to class name not remain
-- around current/previous function
-- By change the end of item be the start of next item.
function M._highlight_current_item(winnr)
  if not view.is_win_open() then
    return
  end
  if writer.current_theme == "type" then
    return
  end
  if vim.fn.bufnr() == view.View.bufnr then
    return
  end

  local has_provider = providers.has_provider(view.View.provider)

  local is_current_buffer_the_outline = view.View.bufnr == vim.api.nvim_get_current_buf()

  local doesnt_have_outline_buf = not view.is_win_open({ any_tabpage = false })

  local is_empty_line = M.is_empty_line()

  local should_exit = not has_provider
    or doesnt_have_outline_buf
    or is_current_buffer_the_outline
    or is_empty_line
  if winnr then
    should_exit = false
  end

  if should_exit then
    return
  end

  local win = winnr or vim.api.nvim_get_current_win()

  local hovered_line = vim.api.nvim_win_get_cursor(win)[1] - 1

  local leaf_node = nil

  local cb = function(value)
    value.hovered = nil

    if
      value.line == hovered_line
      or (hovered_line > value.range_start and hovered_line < value.range_end)
    then
      value.hovered = true
      leaf_node = value
    end
  end

  utils_basic.items_dfs(cb, M.state.outline_items)

  M._update_lines(true)

  if leaf_node then
    for index, node in ipairs(M.state.flattened_outline_items) do
      if node == leaf_node then
        vim.api.nvim_win_set_cursor(view.get_winnr(), { index + view.View.title_line, 1 })
        break
      end
    end
  end
end

return M
