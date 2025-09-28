-- Test font rendering for Vista fold markers
local M = {}

function M.test()
  local config = require("vista-nvim.config")

  print("=== Font Test for Vista Fold Markers ===\n")

  print("Config fold_markers:")
  print("  [1] (collapsed): '" .. config.fold_markers[1] .. "' (should be chevron-right)")
  print("  [2] (expanded):  '" .. config.fold_markers[2] .. "' (should be chevron-down)")

  print("\nUnicode codepoints:")
  for i, marker in ipairs(config.fold_markers) do
    local bytes = {string.byte(marker, 1, -1)}
    local hex = {}
    for _, b in ipairs(bytes) do
      table.insert(hex, string.format("%02X", b))
    end
    print(string.format("  [%d]: %s", i, table.concat(hex, " ")))
  end

  print("\nDirect test:")
  print("  Chevron right: \uF0DA6")
  print("  Chevron down:  \uF0DA7")

  print("\nAlternative characters you could use:")
  print("  ▶ and ▼ (U+25B6, U+25BC)")
  print("  ⯈ and ⯆ (U+2BC8, U+2BC6)")
  print("  › and ˅ (U+203A, U+02C5)")
  print("   and  (U+F054, U+F078 - Font Awesome)")

  print("\nTo fix display issues, you can either:")
  print("  1. Install a Nerd Font (like 'Hack Nerd Font', 'JetBrainsMono Nerd Font')")
  print("  2. Change fold_markers in config to simpler characters")
end

function M.change_markers(style)
  local config = require("vista-nvim.config")

  if style == "simple" then
    config.fold_markers = { "▶", "▼" }
    print("Changed to simple triangles: ▶ ▼")
  elseif style == "ascii" then
    config.fold_markers = { ">", "v" }
    print("Changed to ASCII: > v")
  elseif style == "plus" then
    config.fold_markers = { "+", "-" }
    print("Changed to plus/minus: + -")
  else
    print("Available styles: simple, ascii, plus")
    return
  end

  -- Refresh Vista if it's open
  local view = require("vista-nvim.view")
  if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
    local basic = require("vista-nvim.handlers.basic")
    basic._update_lines(true)
    print("Vista refreshed with new markers")
  end
end

return M