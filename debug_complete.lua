-- Complete debug script for Vista.nvim issues
local M = {}

function M.debug_all()
  local basic = require("vista-nvim.handlers.basic")
  local writer = require("vista-nvim.writer")
  local config = require("vista-nvim.config")

  print("=== COMPLETE DEBUG ===")
  print("Current theme: " .. tostring(basic.current_theme or writer.structure_theme))
  print("Config fold markers: " .. vim.inspect(config.fold_markers))
  print("Config remember_fold_state: " .. tostring(config.remember_fold_state))

  if basic.current_theme == "type" or writer.structure_theme == "type" then
    print("\n=== TYPE MODE DEBUG ===")
    if basic.state.classified_outline_items then
      local count = 0
      for k, v in pairs(basic.state.classified_outline_items) do
        count = count + 1
        print(string.format("  Kind %d: expand=%s, winline=%s, data_count=%d",
          k, tostring(v.expand), tostring(v.winline), v.data and #v.data or 0))

        -- Check first item's structure
        if v.data and v.data[1] then
          local item = v.data[1]
          print("    First item:")
          print("      name: " .. tostring(item.name))
          print("      original_name: " .. tostring(item.original_name))
          print("      winline: " .. tostring(item.winline))
        end
      end
      print("  Total categories: " .. count)
    else
      print("  classified_outline_items is nil!")
    end
  end

  if basic.current_theme == "tree" or writer.structure_theme == "tree" then
    print("\n=== TREE MODE DEBUG ===")
    if basic.state.outline_items then
      print("  outline_items count: " .. #basic.state.outline_items)
      if basic.state.outline_items[1] then
        local item = basic.state.outline_items[1]
        print("  First item:")
        print("    name: " .. tostring(item.name))
        print("    folded: " .. tostring(item.folded))
        print("    children: " .. tostring(item.children and #item.children or "nil"))
      end
    end

    if basic.state.flattened_outline_items then
      print("  flattened_outline_items count: " .. #basic.state.flattened_outline_items)
    else
      print("  flattened_outline_items is nil!")
    end
  end

  print("\n=== CACHE STATE ===")
  if basic._state_cache then
    print("  outline_items_hash: " .. tostring(basic._state_cache.outline_items_hash))
    print("  flattened_cache exists: " .. tostring(basic._state_cache.flattened_cache ~= nil))
  end

  print("\n=== END DEBUG ===")
end

function M.test_type_toggle()
  local basic = require("vista-nvim.handlers.basic")
  print("\n=== TESTING TYPE TOGGLE ===")

  -- Get current line and find node
  local curline = vim.api.nvim_win_get_cursor(0)[1] - 1
  print("Current line: " .. curline)

  -- Check all nodes for this line
  for k, v in pairs(basic.state.classified_outline_items or {}) do
    if v.winline == curline then
      print("Found category node at line " .. curline)
      print("  Kind: " .. k)
      print("  Current expand: " .. tostring(v.expand))
      print("  Data count: " .. (v.data and #v.data or 0))
      break
    end
  end
end

return M