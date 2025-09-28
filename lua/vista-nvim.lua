local api = vim.api

local view = require("vista-nvim.view")
local autocmd = require("vista-nvim.autocmd")
local bindings = require("vista-nvim.bindings")
local profile = require("vista-nvim.profile")
local render = require("vista-nvim.render")
local writer = require("vista-nvim.writer")
local utils_basic = require("vista-nvim.utils.basic")
local highlight = require("vista-nvim.highlight")
local config = require("vista-nvim.config")
local fold_memory = require("vista-nvim.fold_memory")

local M = { setup_called = false, _internal_setup_called = false }
-- data storage with proper cleanup
M.data = {
  outline_items = {},
  flattened_outline_items = {},
  type_items = {},
  classified_outline_items = {},
  code_win = 0,
  current_bufnr = nil,
}

-- Track autocmd IDs for cleanup
M._autocmd_ids = {}
-- Track buffers we're monitoring
M._tracked_buffers = {}

local deprecated_config_map = {}
local function check_deprecated_field(key)
  if not vim.tbl_contains(vim.tbl_keys(deprecated_config_map), key) then
    return
  end

  local new_key = deprecated_config_map[key]
  utils_basic.echo_warning(
    "config '" .. key .. "' is deprecated. Please use '" .. new_key .. "' instead"
  )
end

function M.setup(opts)
  opts = opts or {}

  -- this keys should not be merged by tbl_deep_merge, they should be overriden completely
  local full_override_keys = {}

  for key, value in pairs(opts) do
    check_deprecated_field(key)

    if type(value) ~= "table" or vim.tbl_contains(full_override_keys, key) then
      config[key] = value
    else
      if type(config[key]) == "table" then
        config[key] = vim.tbl_deep_extend("force", config[key], value)
      else
        config[key] = value
      end
    end
  end

  M.setup_called = true
end

function M._internal_setup()
  -- Setup icon provider first if enabled
  if config.use_icons_provider then
    local ok, icons = pcall(require, "vista-nvim.icons")
    if ok then
      icons.setup()
      -- Don't override config.symbols - just let the icon system handle it dynamically
      -- This preserves the user's configuration while still allowing icon provider fallback
    end
  end

  highlight.setup()
  view.setup()
  bindings.setup()
  autocmd.setup()
  writer.setup()

  -- Initialize fold memory
  fold_memory.init()

  if M.open_on_start then
    M._internal_open()
  end
  -- vim.notify("lazy setup done")
end

function M.open()
  if not M._internal_setup_called and vim.v.vim_did_enter == 1 then
    M._internal_setup()
    M._internal_setup_called = true
  end
  view.open()
  -- vim.api.nvim_echo({ { "vista open", "None" } }, false, {})
end

function M.close()
  view.close()
end

function M.destroy()
  view.destroy()
end

-- Focus with proper async handling
function M.focus()
  if not M._internal_setup_called then
    M.open()
    -- Use a more reliable approach than defer_fn
    local function try_focus()
      if view.View.bufnr and vim.api.nvim_buf_is_valid(view.View.bufnr) then
        local winnr = view.get_winnr()
        if winnr and winnr > 0 then
          vim.fn.win_gotoid(winnr)
          return true
        end
      end
      return false
    end

    -- Try immediately first
    if not try_focus() then
      -- If immediate focus fails, use autocmd to wait for window creation
      local focus_group = vim.api.nvim_create_augroup("VistaNvimFocus", { clear = true })
      vim.api.nvim_create_autocmd("WinNew", {
        group = focus_group,
        callback = function()
          vim.schedule(function()
            if try_focus() then
              vim.api.nvim_del_augroup_by_id(focus_group)
            end
          end)
        end,
        once = true,
      })
    end
    return
  end

  if not view.is_win_open() then
    M.open()
    local winnr = view.get_winnr()
    if winnr and winnr > 0 then
      vim.fn.win_gotoid(winnr)
    end
  else
    local winnr = view.get_winnr()
    if winnr and winnr > 0 then
      vim.fn.win_gotoid(winnr)
    end
  end
end

function M.toggle(opt)
  if not M._internal_setup_called and vim.v.vim_did_enter == 1 then
    M._internal_setup()
    M._internal_setup_called = true
  end
  if view.is_win_open({ any_tabpage = false }) then
    view.close()
  else
    view.open(opt)
  end
  -- vim.api.nvim_echo({ { "vista toggle", "None" } }, false, {})
end

function M.on_win_leave()
  -- Use vim.schedule instead of defer_fn for better reliability
  vim.schedule(function()
    if not view.is_win_open() then
      return
    end

    local windows = api.nvim_list_wins()
    if not windows or #windows == 0 then
      return
    end

    local curtab = api.nvim_get_current_tabpage()
    local wins_in_tabpage = vim.tbl_filter(function(w)
      return pcall(api.nvim_win_get_tabpage, w) and api.nvim_win_get_tabpage(w) == curtab
    end, windows)

    if #windows == 1 then
      M.close()
    elseif #wins_in_tabpage == 1 then
      pcall(api.nvim_command, ":tabclose")
    end
  end)
end

function M.cleanup_buffer_data(bufnr)
  -- Clean up data for a specific buffer
  if not bufnr then
    return
  end

  M.data.outline_items[bufnr] = nil
  M.data.flattened_outline_items[bufnr] = nil
  M.data.type_items[bufnr] = nil
  M.data.classified_outline_items[bufnr] = nil

  -- Remove from tracked buffers
  M._tracked_buffers[bufnr] = nil
end

function M.cleanup_all_data()
  -- Clean up all stored data
  M.data.outline_items = {}
  M.data.flattened_outline_items = {}
  M.data.type_items = {}
  M.data.classified_outline_items = {}
  M.data.code_win = 0
  M.data.current_bufnr = nil
  M._tracked_buffers = {}
end

function M.on_vim_leave()
  -- Clean up everything on exit
  M.cleanup_all_data()

  -- Clean up autocmds
  for _, id in ipairs(M._autocmd_ids) do
    pcall(vim.api.nvim_del_autocmd, id)
  end
  M._autocmd_ids = {}

  view.destroy()
end

-- Setup buffer cleanup autocmd
function M._setup_buffer_cleanup(bufnr)
  if M._tracked_buffers[bufnr] then
    return -- Already tracking this buffer
  end

  M._tracked_buffers[bufnr] = true

  -- Clean up when buffer is deleted or wiped out
  local id = vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
    buffer = bufnr,
    callback = function()
      M.cleanup_buffer_data(bufnr)
    end,
    once = true,
  })
  table.insert(M._autocmd_ids, id)
end

-- Get status information about vista.nvim
function M.get_status()
  local icons = require("vista-nvim.icons")
  return {
    icon_provider = icons.get_provider_name(),
    has_icon_provider = icons.has_icon_provider(),
    use_icons_provider = config.use_icons_provider,
    current_theme = writer.structure_theme,
    is_open = view.is_win_open(),
  }
end

-- Print status information
function M.status()
  require("vista-nvim.commands").load_command("status")
end

return M
