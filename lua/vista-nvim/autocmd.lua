local config = require("vista-nvim.config")
--TODO: find out if config is updated in this buffer

local M = {}

local function setup_global_autocmd()
    if config.highlight_hovered_item or config.auto_unfold_hover then
        vim.api.nvim_create_autocmd("CursorHold", {
            pattern = "*",
            command = "",
            -- callback = function()
            --     M._highlight_current_item(nil)
            -- end,
        })
    end

    vim.api.nvim_create_autocmd({
        "InsertLeave",
        "WinEnter",
        "BufEnter",
        "BufWinEnter",
        "TabEnter",
        "BufWritePost",
    }, {
        pattern = "*",
        command = "",
        -- callback = M._refresh,
    })

    vim.api.nvim_create_autocmd("WinEnter", {
        pattern = "*",
        command = "",
        -- callback = require("vista-nvim.preview").close,
    })
end

local function setup_buffer_autocmd()
    if config.auto_preview then
        vim.api.nvim_create_autocmd("CursorHold", {
            buffer = 0,
            command = "",
            -- callback = require("vista-nvim.preview").show,
        })
    else
        vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = 0,
            command = "",
            -- callback = require("vista-nvim.preview").close,
        })
    end
end

function M.setup()
    setup_global_autocmd()
    setup_buffer_autocmd()
end

return M
