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
        "TabEnter",
        "BufWritePost",
        "LspAttach",
        "TextChanged",
        "BufWritePost",
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

    vim.api.nvim_create_autocmd("WinEnter", {
        pattern = "*",
        command = "",
        -- TODO: add preview close function
        -- callback = require("vista-nvim.preview").close,
    })
    -- local GoyoGroup = vim.api.nvim_create_augroup('GoyoGroup', { clear = true })
    --
    -- vim.api.nvim_create_autocmd('User', {
    --     pattern = 'GoyoEnter',
    --     callback = function()
    --         pass
    --     end,
    --     group = GoyoGroup
    -- })
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
