-- Debug type mode winline mapping
local M = {}

function M.debug()
  local basic = require("vista-nvim.handlers.basic")
  local view = require("vista-nvim.view")

  print("=== Type Mode Winline Debug ===")
  print("Current theme: " .. tostring(basic.current_theme))

  if basic.current_theme ~= "type" then
    print("Not in type mode! Switch to type mode first.")
    return
  end

  -- Get current cursor line
  local curline = vim.api.nvim_win_get_cursor(0)[1]
  local line_content = vim.api.nvim_get_current_line()
  print("\nCursor at line " .. curline .. ": " .. line_content)

  -- Check all category nodes
  print("\nCategory mappings:")
  for k, v in pairs(basic.state.classified_outline_items or {}) do
    local kind_name = vim.lsp.protocol.SymbolKind[k] or "Unknown"
    print(string.format("  Kind %s (%s): winline=%d, expand=%s",
      k, kind_name, v.winline or -1, tostring(v.expand)))

    -- Check if this is the line we're on
    if v.winline == curline then
      print("    ^^ This is the category at cursor position!")
    elseif v.winline == curline + 1 then
      print("    ^^ This category is one line below cursor!")
    elseif v.winline == curline - 1 then
      print("    ^^ This category is one line above cursor!")
    end
  end

  -- Also check buffer content
  print("\nBuffer lines around cursor:")
  local bufnr = view.View.bufnr
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local start_line = math.max(0, curline - 3)
    local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), curline + 2)
    local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)

    for i, line in ipairs(lines) do
      local line_num = start_line + i
      local marker = line_num == curline and " <-- cursor" or ""
      print(string.format("  %d: %s%s", line_num, line, marker))
    end
  end
end

return M