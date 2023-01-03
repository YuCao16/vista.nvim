local config = require("vista-nvim.config")
local updater = require("vista-nvim.updater")
-- local view = require("vista-nvim.view")
--TODO: find out if config is updated in this buffer

local M = {}

local function setup_global_autocmd()
    if config.highlight_hovered_item or config.auto_unfold_hover then
        vim.api.nvim_create_autocmd("CursorHold", {
            pattern = "*",
            command = "",
            -- TODO: add highlight current cursor
            -- callback = function()
            --     M._highlight_current_item(nil)
            -- end,
        })
    end

    vim.api.nvim_create_autocmd({
        "InsertLeave",
        -- "WinEnter",
        -- "BufEnter",
        "BufWinEnter",
        "TabEnter",
        "BufWritePost",
    }, {
        pattern = "*",
        callback = updater._refresh,
    })

    vim.api.nvim_create_autocmd("WinEnter", {
        pattern = "*",
        command = "",
        -- TODO: add preview close function
        -- callback = require("vista-nvim.preview").close,
    })
    vim.api.nvim_create_autocmd("CursorHold", {
        pattern = "*",
        callback = function()
            require("vista-nvim.handlers.basic")._highlight_current_item(nil)
        end,
    })
end

local function setup_buffer_autocmd()
    if config.auto_preview then
        vim.api.nvim_create_autocmd("CursorHold", {
            buffer = 0,
            command = "",
            --TODO: add auto preview show function
            -- callback = require("vista-nvim.preview").show,
        })
    else
        vim.api.nvim_create_autocmd("CursorMoved", {
            buffer = 0,
            command = "",
            --TODO: add auto preview close function
            -- callback = require("vista-nvim.preview").close,
        })
    end
end

function M.setup()
    setup_global_autocmd()
    setup_buffer_autocmd()
end

return M
