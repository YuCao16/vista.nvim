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

    -- Preview functionality will be implemented in future versions
    -- vim.api.nvim_create_autocmd("WinEnter", {
    --     pattern = "*",
    --     callback = require("vista-nvim.preview").close,
    -- })
end

local function setup_buffer_autocmd()
    -- Auto preview functionality will be implemented in future versions
    -- if config.auto_preview then
    --     vim.api.nvim_create_autocmd("CursorHold", {
    --         buffer = 0,
    --         callback = require("vista-nvim.preview").show,
    --     })
    -- else
    --     vim.api.nvim_create_autocmd("CursorMoved", {
    --         buffer = 0,
    --         callback = require("vista-nvim.preview").close,
    --     })
    -- end
end

function M.setup()
    setup_global_autocmd()
    setup_buffer_autocmd()
end

return M
