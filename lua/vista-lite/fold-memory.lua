-- fold-memory.lua: Persistent fold state for vista-lite
-- Saves and loads fold state per file

local M = {}

-- Cache directory for fold states
local cache_dir = vim.fn.stdpath('cache') .. '/vista-lite'

-- Ensure cache directory exists
local function ensure_cache_dir()
  if vim.fn.isdirectory(cache_dir) == 0 then
    vim.fn.mkdir(cache_dir, 'p')
  end
end

-- Get cache file path for a given file
local function get_cache_path(file_path)
  if not file_path or file_path == '' then
    return nil
  end

  -- Create a safe filename from the file path
  local safe_name = file_path:gsub('[/\\:]', '_'):gsub('%.', '_')
  return cache_dir .. '/' .. safe_name .. '.json'
end

-- Save fold state for a file
function M.save(file_path, folded_state)
  if not file_path or not folded_state then
    return
  end

  ensure_cache_dir()
  local cache_path = get_cache_path(file_path)

  if not cache_path then
    return
  end

  -- Convert fold state to JSON
  local data = {
    version = 1,
    file = file_path,
    timestamp = os.time(),
    folds = folded_state,
  }

  local json = vim.fn.json_encode(data)
  local file = io.open(cache_path, 'w')

  if file then
    file:write(json)
    file:close()
  end
end

-- Load fold state for a file
function M.load(file_path)
  if not file_path then
    return {}
  end

  local cache_path = get_cache_path(file_path)
  if not cache_path or vim.fn.filereadable(cache_path) == 0 then
    return {}
  end

  local file = io.open(cache_path, 'r')
  if not file then
    return {}
  end

  local content = file:read('*all')
  file:close()

  local ok, data = pcall(vim.fn.json_decode, content)
  if not ok or not data or not data.folds then
    return {}
  end

  -- Check if the cache is too old (7 days)
  if data.timestamp and (os.time() - data.timestamp) > (7 * 24 * 60 * 60) then
    -- Delete old cache file
    vim.fn.delete(cache_path)
    return {}
  end

  return data.folds
end

-- Clear all cached fold states
function M.clear_all()
  if vim.fn.isdirectory(cache_dir) == 1 then
    vim.fn.delete(cache_dir, 'rf')
  end
end

-- Clear cache for a specific file
function M.clear(file_path)
  if not file_path then
    return
  end

  local cache_path = get_cache_path(file_path)
  if cache_path and vim.fn.filereadable(cache_path) == 1 then
    vim.fn.delete(cache_path)
  end
end

return M