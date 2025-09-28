-- Fold management for Vista.nvim
-- Handles all folding operations for both tree and type modes

local state = require("vista-nvim.state")
local config = require("vista-nvim.config")
local folding = require("vista-nvim.folding")
local fold_memory = require("vista-nvim.fold_memory")

local M = {}

-- Check if a node is foldable in current theme
function M.is_foldable(node)
  return folding.is_foldable(node, state.get_current_theme())
end

-- Check if a node is currently folded
function M.is_folded(node)
  return folding.is_folded(node)
end

-- Set fold state for a specific node in tree mode
function M.set_tree_fold(node, folded)
  if not node or not M.is_foldable(node) then
    return false
  end

  -- Find and update the node in the original outline_items
  local function update_in_outline(items, target_node)
    for _, item in ipairs(items) do
      if item.name == target_node.name and
         item.line == target_node.line and
         item.kind == target_node.kind then
        item.folded = folded
        return true
      end
      if item.children and update_in_outline(item.children, target_node) then
        return true
      end
    end
    return false
  end

  local outline_items = state.get_outline_items()
  local success = update_in_outline(outline_items, node)

  if success then
    -- Update the node in current flattened items too
    node.folded = folded

    -- Regenerate flattened items to reflect the change
    local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
    local new_flattened = lsp_parser.flatten(outline_items)
    state.set_flattened_items(new_flattened)

    return true
  end

  return false
end

-- Set fold state for all nodes in tree mode
function M.set_all_tree_folded(folded, nodes)
  local function set_folded_recursive(items)
    for _, item in ipairs(items or {}) do
      if item.children and #item.children > 0 then
        item.folded = folded
        set_folded_recursive(item.children)
      end
    end
  end

  local outline_items = nodes or state.get_outline_items()
  set_folded_recursive(outline_items)

  -- Regenerate flattened items
  local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
  local new_flattened = lsp_parser.flatten(outline_items)
  state.set_flattened_items(new_flattened)
end

-- Set fold state for a category in type mode
function M.set_type_fold(kind, expand)
  local classified_items = state.get_classified_items()
  if classified_items[kind] then
    classified_items[kind].expand = expand
    return true
  end
  return false
end

-- Set fold state for all categories in type mode
function M.set_all_type_folded(expand)
  local classified_items = state.get_classified_items()
  for _, node in pairs(classified_items) do
    node.expand = expand
  end
end

-- Toggle fold state for current node/category
function M.toggle_fold()
  local current_theme = state.get_current_theme()

  if current_theme == "tree" then
    return M.toggle_tree_fold()
  elseif current_theme == "type" then
    return M.toggle_type_fold()
  end

  return false
end

-- Toggle fold for tree mode
function M.toggle_tree_fold()
  local node = M.get_current_node()
  if not node or not M.is_foldable(node) then
    return false
  end

  local new_folded = not M.is_folded(node)
  local success = M.set_tree_fold(node, new_folded)

  if success then
    -- Save fold state
    fold_memory.save_current_state()
    return true
  end

  return false
end

-- Toggle fold for type mode
function M.toggle_type_fold()
  local winnr = state.get_vista_winnr()
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return false
  end

  local curline = vim.api.nvim_win_get_cursor(winnr)[1]
  local classified_items = state.get_classified_items()

  -- Find the category at current line
  for kind, node in pairs(classified_items) do
    if node.winline == curline then
      -- Toggle expand state
      node.expand = not node.expand

      -- Save fold state
      fold_memory.save_current_state()
      return true
    end

    -- Check if we're on an individual item (don't toggle those)
    for _, item in pairs(node.data or {}) do
      if item.winline == curline then
        return false -- Don't toggle individual items
      end
    end
  end

  return false
end

-- Set all folded/unfolded
function M.set_all_folded(folded)
  local current_theme = state.get_current_theme()

  if current_theme == "type" then
    -- For type mode, folded=true means expand=false (collapsed)
    M.set_all_type_folded(not folded)
  else
    -- For tree mode
    M.set_all_tree_folded(folded)
  end

  -- Save fold state after setting all
  fold_memory.save_current_state()
end

-- Get current node (for tree mode)
function M.get_current_node()
  local winnr = state.get_vista_winnr()
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local view = require("vista-nvim.view")
  local current_line = vim.api.nvim_win_get_cursor(winnr)[1] - view.View.title_line
  local flattened_items = state.get_flattened_items()

  if current_line > 0 and current_line <= #flattened_items then
    return flattened_items[current_line]
  end

  return nil
end

-- Get current category info (for type mode)
function M.get_current_category()
  local winnr = state.get_vista_winnr()
  if not winnr or not vim.api.nvim_win_is_valid(winnr) then
    return nil
  end

  local curline = vim.api.nvim_win_get_cursor(winnr)[1]
  local classified_items = state.get_classified_items()

  for kind, node in pairs(classified_items) do
    if node.winline == curline then
      return {
        kind = kind,
        node = node,
        kind_name = vim.lsp.protocol.SymbolKind[kind] or "Unknown"
      }
    end
  end

  return nil
end

return M