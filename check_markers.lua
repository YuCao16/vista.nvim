-- Check and fix fold markers for Maple Mono NF CN
local M = {}

function M.check()
  local config = require("vista-nvim.config")

  print("=== Checking Fold Markers ===\n")

  -- Get current markers
  local marker1 = config.fold_markers[1]
  local marker2 = config.fold_markers[2]

  print("Current markers in config:")
  print("  [1]: '" .. marker1 .. "'")
  print("  [2]: '" .. marker2 .. "'")

  -- Check byte sequences
  local function check_bytes(s)
    local bytes = {string.byte(s, 1, -1)}
    local hex = {}
    for _, b in ipairs(bytes) do
      table.insert(hex, string.format("0x%02X", b))
    end
    return table.concat(hex, " ")
  end

  print("\nByte sequences:")
  print("  [1]: " .. check_bytes(marker1))
  print("  [2]: " .. check_bytes(marker2))

  -- Expected values for Nerd Font chevrons
  local expected1 = "\239\131\166"  -- EF 83 A6 for
  local expected2 = "\239\131\167"  -- EF 83 A7 for

  print("\nExpected Nerd Font chevrons:")
  print("  Collapsed (chevron-right): '" .. expected1 .. "' = " .. check_bytes(expected1))
  print("  Expanded (chevron-down):   '" .. expected2 .. "' = " .. check_bytes(expected2))

  -- Test if they match
  if marker1 == expected1 and marker2 == expected2 then
    print("\n✓ Markers are correctly set for Nerd Font!")
  else
    print("\n✗ Markers don't match expected Nerd Font values")
  end

  -- Show some alternatives that work well with Maple Mono NF
  print("\n=== Alternative markers that work well with Maple Mono NF ===")

  local alternatives = {
    { "", "" },  -- Current Nerd Font chevrons
    { "", "" },  -- Nerd Font arrows
    { "", "" },  -- Nerd Font triangles
    { "▶", "▼" },  -- Unicode triangles
    { "⯈", "⯆" },  -- Unicode arrows
    { "", "" },  -- Powerline triangles
  }

  for i, pair in ipairs(alternatives) do
    print(string.format("%d. '%s' '%s'", i, pair[1], pair[2]))
  end
end

function M.fix()
  local config = require("vista-nvim.config")

  -- Set correct Nerd Font chevrons
  config.fold_markers = { "", "" }

  print("Fixed fold markers to Nerd Font chevrons:  ")

  -- Refresh Vista display
  local view = require("vista-nvim.view")
  local basic = require("vista-nvim.handlers.basic")

  if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
    -- Force complete refresh
    if basic.current_theme == "type" then
      local writer = require("vista-nvim.writer")
      writer.parse_and_write(view.View.bufnr, basic.state.classified_outline_items)
    else
      basic._update_lines(true)
    end
    print("Vista display refreshed!")
  else
    print("Please reopen Vista to see the changes")
  end
end

function M.set_alternative(num)
  local config = require("vista-nvim.config")

  local alternatives = {
    { "", "" },  -- Nerd Font chevrons
    { "", "" },  -- Nerd Font arrows
    { "", "" },  -- Nerd Font triangles
    { "▶", "▼" },  -- Unicode triangles
    { "⯈", "⯆" },  -- Unicode arrows
    { "", "" },  -- Powerline triangles
  }

  if num < 1 or num > #alternatives then
    print("Invalid choice. Use 1-" .. #alternatives)
    return
  end

  config.fold_markers = alternatives[num]
  print(string.format("Set markers to: '%s' '%s'", alternatives[num][1], alternatives[num][2]))

  -- Refresh
  local view = require("vista-nvim.view")
  local basic = require("vista-nvim.handlers.basic")

  if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
    if basic.current_theme == "type" then
      local writer = require("vista-nvim.writer")
      writer.parse_and_write(view.View.bufnr, basic.state.classified_outline_items)
    else
      basic._update_lines(true)
    end
    print("Vista refreshed!")
  end
end

return M