-- Test script to verify fold fixes for Vista.nvim
local M = {}

function M.test_all()
  local basic = require("vista-nvim.handlers.basic")
  local view = require("vista-nvim.view")
  local fold_memory = require("vista-nvim.fold_memory")

  print("=== Testing Vista.nvim Fold Fixes ===\n")

  -- Test 1: Tree mode fold toggle
  print("Test 1: Tree mode fold toggle")
  if basic.current_theme == "tree" then
    local before_state = {}
    if basic.state.flattened_outline_items and basic.state.flattened_outline_items[1] then
      local node = basic.state.flattened_outline_items[1]
      before_state.folded = node.folded
      print("  Before: node.folded = " .. tostring(node.folded))

      -- Try to toggle
      basic.toggle_fold()

      -- Check if changed
      local after_folded = node.folded
      print("  After: node.folded = " .. tostring(after_folded))

      if before_state.folded ~= after_folded then
        print("  ✓ Tree fold toggle working!")
      else
        print("  ✗ Tree fold toggle NOT working")
      end
    else
      print("  - No items to test")
    end
  else
    print("  - Not in tree mode, switch to tree mode first")
  end

  print("")

  -- Test 2: Type mode fold toggle
  print("Test 2: Type mode fold toggle")
  if basic.current_theme == "type" then
    local test_passed = false
    for k, v in pairs(basic.state.classified_outline_items or {}) do
      if v.winline and v.winline > 0 then
        local before_expand = v.expand
        print("  Before: category " .. k .. " expand = " .. tostring(before_expand))

        -- Move cursor to that line
        vim.api.nvim_win_set_cursor(view.get_winnr(), {v.winline, 0})

        -- Toggle
        basic.toggle_fold()

        -- Check if changed
        print("  After: category " .. k .. " expand = " .. tostring(v.expand))

        if before_expand ~= v.expand then
          print("  ✓ Type fold toggle working!")
          test_passed = true
        else
          print("  ✗ Type fold toggle NOT working")
        end
        break
      end
    end

    if not test_passed then
      print("  - No testable categories found")
    end
  else
    print("  - Not in type mode, switch to type mode first")
  end

  print("")

  -- Test 3: Fold memory
  print("Test 3: Fold memory")

  -- Save current state
  fold_memory.save_current_state()
  print("  - Saved current fold state")

  -- Check if cache has data
  local cache_size = 0
  for k, v in pairs(fold_memory._fold_cache or {}) do
    cache_size = cache_size + 1
  end
  print("  - Cache contains " .. cache_size .. " entries")

  -- Try to restore
  fold_memory.restore_current_state()
  print("  - Attempted to restore fold state")

  if cache_size > 0 then
    print("  ✓ Fold memory appears to be working")
  else
    print("  ✗ Fold memory NOT working (no cache data)")
  end

  print("")

  -- Test 4: Display integrity
  print("Test 4: Display integrity")
  local lines = vim.api.nvim_buf_get_lines(view.View.bufnr, 0, -1, false)
  local has_icons = false
  local has_names = false

  for _, line in ipairs(lines) do
    -- Check for icon presence (unicode characters)
    if line:match("[\128-\255]") then
      has_icons = true
    end
    -- Check for actual symbol names
    if line:match("%w+") and not line:match("^%s*$") then
      has_names = true
    end
  end

  print("  - Buffer has " .. #lines .. " lines")
  print("  - Has icons: " .. tostring(has_icons))
  print("  - Has names: " .. tostring(has_names))

  if has_icons and has_names then
    print("  ✓ Display integrity looks good")
  else
    print("  ✗ Display issues detected")
  end

  print("\n=== Test Complete ===")
end

function M.test_fold_all()
  local basic = require("vista-nvim.handlers.basic")

  print("=== Testing Fold All Operations ===\n")

  -- Test fold all (zM)
  print("Folding all...")
  basic.set_all_folded(true)

  -- Count visible items
  local visible_count = 0
  if basic.current_theme == "tree" then
    for _, item in ipairs(basic.state.flattened_outline_items or {}) do
      if not item.parent or not item.parent.folded then
        visible_count = visible_count + 1
      end
    end
  else
    for _, cat in pairs(basic.state.classified_outline_items or {}) do
      if cat.expand == false then
        visible_count = visible_count + 1
      end
    end
  end

  print("After fold all: " .. visible_count .. " visible items")

  -- Test unfold all (zR)
  print("\nUnfolding all...")
  basic.set_all_folded(false)

  -- Count visible items again
  local visible_after = 0
  if basic.current_theme == "tree" then
    visible_after = #(basic.state.flattened_outline_items or {})
  else
    for _, cat in pairs(basic.state.classified_outline_items or {}) do
      if cat.expand ~= false then
        visible_after = visible_after + #cat.data
      end
    end
  end

  print("After unfold all: " .. visible_after .. " visible items")

  if visible_after > visible_count then
    print("\n✓ Fold all/unfold all working!")
  else
    print("\n✗ Fold all/unfold all NOT working properly")
  end

  print("\n=== Test Complete ===")
end

return M