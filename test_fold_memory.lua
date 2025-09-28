-- Test fold memory functionality
local M = {}

function M.debug()
  local fold_memory = require("vista-nvim.fold_memory")
  local view = require("vista-nvim.view")
  local basic = require("vista-nvim.handlers.basic")

  print("=== Fold Memory Debug ===")

  -- Get current file key
  local filepath
  if view.View.lsp_bufnr and vim.api.nvim_buf_is_valid(view.View.lsp_bufnr) then
    filepath = vim.api.nvim_buf_get_name(view.View.lsp_bufnr)
  elseif basic.state.current_bufnr and vim.api.nvim_buf_is_valid(basic.state.current_bufnr) then
    filepath = vim.api.nvim_buf_get_name(basic.state.current_bufnr)
  else
    filepath = vim.api.nvim_buf_get_name(0)
  end

  local theme = basic.current_theme or "tree"
  local file_key = filepath .. ":" .. theme

  print("Current file key: " .. file_key)
  print("Current theme: " .. theme)
  print("LSP bufnr: " .. tostring(view.View.lsp_bufnr))
  print("State bufnr: " .. tostring(basic.state.current_bufnr))

  -- Check cache
  local cache_entry = fold_memory._fold_cache[file_key]
  if cache_entry then
    print("\nFold state found in cache!")
    print("  Type: " .. tostring(cache_entry.type))
    local count = 0
    for k, v in pairs(cache_entry.state or {}) do
      count = count + 1
      if count <= 5 then
        print("  " .. k .. " = " .. tostring(v))
      end
    end
    if count > 5 then
      print("  ... and " .. (count - 5) .. " more entries")
    end
  else
    print("\nNo fold state in cache for this file")
  end

  -- Test save
  print("\nTesting save...")
  fold_memory.save_current_state()

  -- Reload and check
  fold_memory.load_fold_state()
  cache_entry = fold_memory._fold_cache[file_key]
  if cache_entry then
    print("Save successful! Entry exists after save.")
  else
    print("Save failed! No entry after save.")
  end
end

function M.test_restore()
  local fold_memory = require("vista-nvim.fold_memory")
  local basic = require("vista-nvim.handlers.basic")

  print("=== Testing Fold Restore ===")
  print("Before restore:")

  if basic.current_theme == "type" then
    for k, v in pairs(basic.state.classified_outline_items or {}) do
      print("  Kind " .. k .. ": expand=" .. tostring(v.expand))
    end
  else
    local count = 0
    for _, item in ipairs(basic.state.outline_items or {}) do
      if item.children then
        count = count + 1
        if count <= 3 then
          print("  " .. item.name .. ": folded=" .. tostring(item.folded))
        end
      end
    end
  end

  print("\nRestoring...")
  fold_memory.restore_current_state()

  print("\nAfter restore:")
  if basic.current_theme == "type" then
    for k, v in pairs(basic.state.classified_outline_items or {}) do
      print("  Kind " .. k .. ": expand=" .. tostring(v.expand))
    end
  else
    local count = 0
    for _, item in ipairs(basic.state.outline_items or {}) do
      if item.children then
        count = count + 1
        if count <= 3 then
          print("  " .. item.name .. ": folded=" .. tostring(item.folded))
        end
      end
    end
  end
end

return M