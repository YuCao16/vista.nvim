local M = {}

-- Error handling and notification system inspired by trouble.nvim
function M.try(fn, context)
  local ok, result = pcall(fn)
  if not ok then
    M.notify_error("Error in " .. (context or "unknown context") .. ": " .. result)
    return nil
  end
  return result
end

function M.notify_error(msg, opts)
  opts = opts or {}
  vim.notify(msg, vim.log.levels.ERROR, {
    title = "Vista.nvim",
    timeout = opts.timeout or 5000,
  })
end

function M.notify_warn(msg, opts)
  opts = opts or {}
  vim.notify(msg, vim.log.levels.WARN, {
    title = "Vista.nvim",
    timeout = opts.timeout or 3000,
  })
end

function M.notify_info(msg, opts)
  opts = opts or {}
  vim.notify(msg, vim.log.levels.INFO, {
    title = "Vista.nvim",
    timeout = opts.timeout or 2000,
  })
end

function M.validate_input(value, expected_type, name)
  if value == nil then
    M.notify_error(name .. " cannot be nil")
    return false
  end

  if expected_type and type(value) ~= expected_type then
    M.notify_error(name .. " must be " .. expected_type .. ", got " .. type(value))
    return false
  end

  return true
end

-- Safe wrapper for potentially failing operations
function M.safe_call(fn, fallback, context)
  local result = M.try(fn, context)
  if result == nil and fallback ~= nil then
    if type(fallback) == "function" then
      return fallback()
    else
      return fallback
    end
  end
  return result
end

return M