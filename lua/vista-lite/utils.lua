local M = {}

local api = vim.api

--- Debounce a function call
--- @param f function Function to debounce
--- @param delay number Delay in milliseconds
--- @return function Debounced function
function M.debounce(f, delay)
  local timer = vim.loop.new_timer()

  return function(...)
    local args = { ... }

    timer:start(
      delay,
      0,
      vim.schedule_wrap(function()
        timer:stop()
        f(unpack(args))
      end)
    )
  end
end

--- Flash highlight a line briefly
--- @param bufnr number Buffer number
--- @param lnum number Line number (1-indexed)
--- @param duration number? Duration in milliseconds (default: 300)
function M.flash_highlight(bufnr, lnum, duration)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    return
  end

  local hl_group = "VistaFlashLine"
  local durationMs = duration or 300
  local ns = api.nvim_create_namespace("vista_lite_flash")

  -- Add highlight
  api.nvim_buf_add_highlight(bufnr, ns, hl_group, lnum - 1, 0, -1)

  -- Remove highlight after duration
  vim.defer_fn(function()
    if api.nvim_buf_is_valid(bufnr) then
      api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
  end, durationMs)
end

return M