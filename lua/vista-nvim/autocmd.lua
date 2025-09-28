local config = require("vista-nvim.config")
local updater = require("vista-nvim.updater")
local M = {}

local function setup_global_autocmd()
  if config.highlight_hovered_item or config.auto_unfold_hover then
    vim.api.nvim_create_autocmd("CursorHold", {
      pattern = "*",
      callback = function()
        require("vista-nvim.handlers.basic")._highlight_current_item(0)
      end,
    })
  end

  vim.api.nvim_create_autocmd({
    "InsertLeave",
    "BufWinEnter",
    "BufEnter",
    "WinEnter",
    "TabEnter",
    "BufWritePost",
    "LspAttach",
    "TextChanged",
  }, {
    pattern = "*",
    callback = updater._refresh,
  })

  if vim.fn.has("nvim-0.9") ~= 0 then
    vim.api.nvim_create_autocmd({
      "WinResized",
    }, {
      pattern = "*",
      callback = updater._refresh_title,
    })
  end
end

local function setup_buffer_autocmd() end

function M.setup()
  setup_global_autocmd()
  setup_buffer_autocmd()
end

return M
