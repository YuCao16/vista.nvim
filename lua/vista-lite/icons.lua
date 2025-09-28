-- icons.lua: Mini.icons integration for vista-lite
-- Provides icon support with fallback to builtin icons

local M = {}

-- Cache for mini.icons availability
local has_mini_icons = nil
local mini_icons = nil

-- LSP SymbolKind to name mapping
local kind_names = {
  [1] = 'File',
  [2] = 'Module',
  [3] = 'Namespace',
  [4] = 'Package',
  [5] = 'Class',
  [6] = 'Method',
  [7] = 'Property',
  [8] = 'Field',
  [9] = 'Constructor',
  [10] = 'Enum',
  [11] = 'Interface',
  [12] = 'Function',
  [13] = 'Variable',
  [14] = 'Constant',
  [15] = 'String',
  [16] = 'Number',
  [17] = 'Boolean',
  [18] = 'Array',
  [19] = 'Object',
  [20] = 'Key',
  [21] = 'Null',
  [22] = 'EnumMember',
  [23] = 'Struct',
  [24] = 'Event',
  [25] = 'Operator',
  [26] = 'TypeParameter',
}

-- Initialize mini.icons if available
local function init_mini_icons()
  if has_mini_icons ~= nil then
    return has_mini_icons
  end

  has_mini_icons = false
  local ok, icons = pcall(require, 'mini.icons')
  if ok then
    mini_icons = icons
    has_mini_icons = true
  end

  return has_mini_icons
end

-- Get icon from mini.icons
local function get_mini_icon(kind)
  if not init_mini_icons() then
    return nil
  end

  local kind_name = kind_names[kind]
  if not kind_name then
    return nil
  end

  -- Try to get LSP symbol icon from mini.icons
  local ok, icon = pcall(mini_icons.get, 'lsp', kind_name:lower())
  if ok and icon then
    return icon
  end

  return nil
end

-- Builtin fallback icons
local builtin_icons = {
  File = '󰈔',
  Module = '󰆧',
  Namespace = '󰅪',
  Package = '󰏗',
  Class = '󰠱',
  Method = '󰊕',
  Property = '󰀫',
  Field = '󰄶',
  Constructor = '󰒬',
  Enum = '󰒻',
  Interface = '󰜰',
  Function = '󰊕',
  Variable = '󰀫',
  Constant = '󰏿',
  String = '󰀬',
  Number = '󰎠',
  Boolean = '󰨙',
  Array = '󰅨',
  Object = '󰀚',
  Key = '󰌋',
  Null = '󰟢',
  EnumMember = '󰒻',
  Struct = '󰠲',
  Event = '󱐋',
  Operator = '󰆕',
  TypeParameter = '󰠱',
}

-- Get icon for a symbol kind
function M.get(kind)
  -- Try mini.icons first
  local icon = get_mini_icon(kind)
  if icon and icon ~= '' then
    return icon
  end

  -- Fallback to builtin
  local kind_name = kind_names[kind]
  if kind_name then
    local builtin = builtin_icons[kind_name]
    if builtin and builtin ~= '' then
      return builtin
    end
  end

  -- For unknown kinds, return appropriate default based on common patterns
  return ' '  -- Return space for better alignment when no icon available
end

-- Check if mini.icons is available
function M.has_mini_icons()
  return init_mini_icons()
end

return M