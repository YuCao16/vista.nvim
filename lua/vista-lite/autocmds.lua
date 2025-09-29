local M = {}
local api = vim.api

-- Track if autocmds are installed
local installed = false

-- Function callbacks (will be set by setup)
local callbacks = {
  on_buf_enter = nil,
  on_lsp_attach = nil,
}

-- Install autocmds
function M.setup(opts)
  if installed then
    return
  end

  -- Store callbacks
  callbacks = opts or {}

  local group = api.nvim_create_augroup("VistaLiteFollow", { clear = true })

  -- Follow on buffer enter
  if callbacks.on_buf_enter then
    api.nvim_create_autocmd({ "BufEnter" }, {
      group = group,
      callback = callbacks.on_buf_enter,
    })
  end

  -- Refresh when LSP attaches
  if callbacks.on_lsp_attach then
    api.nvim_create_autocmd({ "LspAttach" }, {
      group = group,
      callback = callbacks.on_lsp_attach,
    })
  end

  -- Re-setup highlights when colorscheme changes
  api.nvim_create_autocmd({ "ColorScheme" }, {
    group = group,
    callback = function()
      local highlights = require("vista-lite.highlights")
      highlights.setup()
    end,
  })

  installed = true
end

-- Check if autocmds are installed
function M.is_installed()
  return installed
end

-- Cleanup autocmds
function M.cleanup()
  if not installed then
    return
  end

  -- Delete the autocommand group
  pcall(api.nvim_del_augroup_by_name, "VistaLiteFollow")

  installed = false
  callbacks = {
    on_buf_enter = nil,
    on_lsp_attach = nil,
  }
end

return M