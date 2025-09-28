-- Debug fold position issue in type mode
local M = {}

function M.debug()
  local basic = require("vista-nvim.handlers.basic")
  local view = require("vista-nvim.view")

  if basic.current_theme ~= "type" then
    print("Not in type mode! Please switch to type mode first.")
    return
  end

  print("=== Type Mode Fold Position Debug ===\n")

  -- Get buffer lines
  local bufnr = view.View.bufnr
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    print("Invalid buffer!")
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  -- Build a reverse map of winline to category
  local winline_map = {}
  for k, v in pairs(basic.state.classified_outline_items or {}) do
    if v.winline and v.winline > 0 then
      winline_map[v.winline] = {
        kind = k,
        kind_name = vim.lsp.protocol.SymbolKind[k] or "Unknown",
        expand = v.expand
      }
    end
  end

  -- Print first 20 lines with annotations
  print("Buffer content with winline mappings:")
  print("Line | Content                          | Fold Target")
  print("-----|----------------------------------|-------------")

  for i = 1, math.min(#lines, 20) do
    local line = lines[i]
    local display = string.sub(line .. string.rep(" ", 34), 1, 34)
    local fold_info = ""

    if winline_map[i] then
      local info = winline_map[i]
      fold_info = string.format("KIND %d (%s) expand=%s",
        info.kind, info.kind_name, tostring(info.expand))
    end

    print(string.format("%4d | %s | %s", i, display, fold_info))
  end

  print("\n=== Current Cursor Test ===")
  local curline = vim.api.nvim_win_get_cursor(0)[1]
  local line_content = vim.api.nvim_get_current_line()
  print("Cursor at line " .. curline .. ": " .. line_content)

  -- Check what fold would trigger here
  local found = false
  for _, nodes in pairs(basic.state.classified_outline_items or {}) do
    if nodes.winline == curline then
      print("  -> This line would toggle: " .. vim.lsp.protocol.SymbolKind[_] .. " (expand=" .. tostring(nodes.expand) .. ")")
      found = true
      break
    end
  end

  if not found then
    print("  -> No fold target at this line")
    -- Check nearby lines
    for _, nodes in pairs(basic.state.classified_outline_items or {}) do
      if nodes.winline == curline - 1 then
        print("  -> One line UP is: " .. vim.lsp.protocol.SymbolKind[_])
      elseif nodes.winline == curline + 1 then
        print("  -> One line DOWN is: " .. vim.lsp.protocol.SymbolKind[_])
      end
    end
  end
end

-- Run this on every cursor move to see the mapping
function M.track()
  vim.api.nvim_create_autocmd("CursorMoved", {
    pattern = "*",
    callback = function()
      local basic = require("vista-nvim.handlers.basic")
      if basic.current_theme ~= "type" then return end

      local curline = vim.api.nvim_win_get_cursor(0)[1]

      for k, nodes in pairs(basic.state.classified_outline_items or {}) do
        if nodes.winline == curline then
          print("Line " .. curline .. " -> " .. vim.lsp.protocol.SymbolKind[k])
          return
        end
      end
      print("Line " .. curline .. " -> (no fold)")
    end
  })
  print("Tracking enabled! Move cursor to see mappings.")
end

function M.stop_track()
  vim.api.nvim_clear_autocmds({ pattern = "*", event = "CursorMoved" })
  print("Tracking disabled.")
end

return M