local M = {}
local error_utils = require("vista-nvim.utils.error")
local cache_utils = require("vista-nvim.utils.cache")

-- Cache for icon provider detection
M._has_mini_icons = nil
M._has_devicons = nil

-- Detect available icon providers
local function detect_icon_providers()
  if M._has_mini_icons == nil then
    M._has_mini_icons = pcall(require, "mini.icons")
  end
  if M._has_devicons == nil then
    M._has_devicons = pcall(require, "nvim-web-devicons")
  end
end

-- Get icon using mini.icons
local function get_mini_icon(kind)
  local ok, mini_icons = pcall(require, "mini.icons")
  if not ok then
    return nil, nil
  end

  -- mini.icons uses 'lsp' category for LSP kinds
  local icon, hl, is_default = mini_icons.get("lsp", kind)

  -- Check if icon is valid and not a fallback to problematic characters
  if icon and icon ~= "" and vim.trim(icon) ~= "" then
    local trimmed = vim.trim(icon)
    -- Check if we got a meaningful icon vs empty/invisible characters
    if #trimmed > 0 then
      -- Check if this is a default fallback from mini.icons
      if is_default then
        -- If mini.icons is giving us a default fallback, prefer our own icons
        return nil, nil
      end

      -- Simple heuristic: if the icon is exactly 3 bytes, it's likely invisible
      -- Most proper Unicode icons (like nerd fonts) are 4+ bytes
      if #trimmed == 3 then
        -- Likely an invisible or problematic character from mini.icons
        return nil, nil
      end

      return icon, hl
    end
  end

  return nil, nil
end

-- Get icon using nvim-web-devicons (fallback)
local function get_devicon(kind)
  -- nvim-web-devicons doesn't directly support LSP kinds,
  -- so we'll return nil to use default icons
  return nil, nil
end

-- Default icon mapping (fallback when no icon provider is available)
local default_icons = {
  File = { icon = "󰈙", hl = "@text.uri" },
  Module = { icon = "", hl = "@namespace" },
  Namespace = { icon = "󰌗", hl = "@namespace" },
  Package = { icon = "󰏖", hl = "@namespace" },
  Class = { icon = "󰠱", hl = "@type" },
  Method = { icon = "󰆧", hl = "@method" },
  Property = { icon = "󰜢", hl = "@method" },
  Field = { icon = "󰜢", hl = "@field" },
  Constructor = { icon = "", hl = "@constructor" },
  Enum = { icon = "", hl = "@type" },
  Interface = { icon = "", hl = "@type" },
  Function = { icon = "󰊕", hl = "@function" },
  Variable = { icon = "󰀫", hl = "@constant" },
  Constant = { icon = "󰏿", hl = "@constant" },
  String = { icon = "󰀬", hl = "@string" },
  Number = { icon = "󰎠", hl = "@number" },
  Boolean = { icon = "", hl = "@boolean" },
  Array = { icon = "󰅪", hl = "@constant" },
  Object = { icon = "󰅩", hl = "@type" },
  Key = { icon = "󰌋", hl = "@type" },
  Null = { icon = "", hl = "@type" },
  EnumMember = { icon = "", hl = "@field" },
  Struct = { icon = "󰙅", hl = "@type" },
  Event = { icon = "", hl = "@type" },
  Operator = { icon = "󰆕", hl = "@operator" },
  TypeParameter = { icon = "󰊄", hl = "@parameter" },
  Component = { icon = "󰅴", hl = "@function" },
  Fragment = { icon = "󰅴", hl = "@constant" },
  -- Additional kinds
  TypeAlias = { icon = "", hl = "@string" },
  Parameter = { icon = "", hl = "@parameter" },
  StaticMethod = { icon = "󰠄", hl = "@namespace" },
  Macro = { icon = "", hl = "@macro" },
  Text = { icon = "󰉿", hl = "@method" },
  Unit = { icon = "󰑭", hl = "@method" },
  Value = { icon = "󰎠", hl = "@method" },
  Keyword = { icon = "󰌋", hl = "@type" },
  Snippet = { icon = "", hl = "@type" },
  Color = { icon = "󰏘", hl = "@type" },
  Reference = { icon = "󰈇", hl = "@text.uri" },
  Folder = { icon = "󰉋", hl = "@text.uri" },
}

-- Main function to get icon for a LSP kind
-- Cache for original symbol kind names (borrowed from trouble.nvim approach)
-- Some plugins override vim.lsp.protocol.SymbolKind values, so we build a reverse
-- mapping to get the original names instead of using SymbolKind[kind] directly
M._symbol_kinds = nil

-- Get original symbol kind name, avoiding pollution from other plugins
local function get_clean_symbol_kind(kind)
  if not M._symbol_kinds then
    M._symbol_kinds = {}
    -- Build reverse mapping from vim.lsp.protocol.SymbolKind to get original names
    for k, v in pairs(vim.lsp.protocol.SymbolKind) do
      if type(v) == "number" then
        M._symbol_kinds[v] = k
      end
    end
  end
  return M._symbol_kinds[kind]
end

function M.get_icon(kind)
  -- Validate input
  if not error_utils.validate_input(kind, nil, "kind") then
    return "○", "@type"
  end

  -- Check cache first
  local cache_key = tostring(kind)
  local cached = cache_utils.icons:get(cache_key)
  if cached then
    return cached.icon, cached.hl
  end

  local result = error_utils.safe_call(function()
    detect_icon_providers()

    local kind_name = kind
    if type(kind) == "number" then
      -- Use clean symbol kind name to avoid pollution from other plugins
      kind_name = get_clean_symbol_kind(kind) or "Object"
    end

    -- Try mini.icons first
    if M._has_mini_icons then
      local icon, hl = get_mini_icon(kind_name)
      if icon then
        return { icon = icon, hl = hl }
      end
    end

    -- Try nvim-web-devicons as fallback
    if M._has_devicons then
      local icon, hl = get_devicon(kind_name)
      if icon then
        return { icon = icon, hl = hl }
      end
    end

    -- Use default icons as final fallback
    local default = default_icons[kind_name]
    if default then
      return { icon = default.icon, hl = default.hl }
    end

    -- Ultimate fallback
    return { icon = "○", hl = "@type" }
  end, { icon = "○", hl = "@type" }, "icon retrieval for kind " .. tostring(kind))

  -- Cache the result
  if result then
    cache_utils.icons:set(cache_key, result)
    return result.icon, result.hl
  end

  return "○", "@type"
end

-- Get icon configuration for config.symbols
function M.get_symbol_config()
  detect_icon_providers()

  local symbols = {}

  -- Build symbol configuration
  for kind_name, default in pairs(default_icons) do
    local icon, hl = M.get_icon(kind_name)
    symbols[kind_name] = {
      icon = icon or default.icon,
      hl = hl or default.hl,
    }
  end

  return symbols
end

-- Initialize mini.icons if available
function M.setup()
  detect_icon_providers()

  -- If mini.icons is available, ensure it's setup
  if M._has_mini_icons then
    local ok, mini_icons = pcall(require, "mini.icons")
    if ok then
      -- Check if mini.icons is already setup
      local setup_called = false
      pcall(function()
        -- Try to get an icon, if it fails, setup hasn't been called
        mini_icons.get("lsp", "Class")
        setup_called = true
      end)

      if not setup_called then
        -- Setup mini.icons with default configuration
        mini_icons.setup({
          style = "glyph",
        })
      end

      -- Optionally tweak LSP kinds for better integration
      if mini_icons.tweak_lsp_kind then
        pcall(mini_icons.tweak_lsp_kind, "prepend")
      end
    end
  end
end

-- Check if any icon provider is available
function M.has_icon_provider()
  detect_icon_providers()
  return M._has_mini_icons or M._has_devicons
end

-- Get provider name
function M.get_provider_name()
  detect_icon_providers()
  if M._has_mini_icons then
    return "mini.icons"
  elseif M._has_devicons then
    return "nvim-web-devicons"
  else
    return "builtin"
  end
end

-- Debug function to show cache statistics
function M.get_cache_stats()
  return {
    icons = cache_utils.icons:stats_report(),
    symbols = cache_utils.symbols:stats_report(),
    highlights = cache_utils.highlights:stats_report(),
  }
end

-- Clear all caches
function M.clear_caches()
  cache_utils.icons:clear()
  cache_utils.symbols:clear()
  cache_utils.highlights:clear()
  -- Also clear the symbol kinds cache
  M._symbol_kinds = nil
end

return M
