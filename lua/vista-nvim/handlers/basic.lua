local writer = require("vista-nvim.writer")
local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
local utils_lsp = require("vista-nvim.utils.lsp_utils")
local view = require("vista-nvim.view")

local M = {}

M.state = {
    outline_items = {},
    flattened_outline_items = {},
    code_win = 0,
}

local function wipe_state()
    M.state = { outline_items = {}, flattened_outline_items = {}, code_win = 0 }
end

function M._update_lines()
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
    writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)
end

function M._merge_items(items)
    utils_lsp.merge_items_rec(
        { children = items },
        { children = M.state.outline_items }
    )
end

function M.refresh_handler(response)
    if response == nil or type(response) ~= "table" then
        return
    end

    local items = lsp_parser.parse(response)
    M._merge_items(items)

    M.state.code_win = vim.api.nvim_get_current_win()

    M._update_lines()
end

function M.handler(response)
    if response == nil or type(response) ~= "table" then
        return
    end

    M.state.code_win = vim.api.nvim_get_current_win()

    -- clear state when buffer is closed
    vim.api.nvim_buf_attach(view.View.bufnr, false, {
        on_detach = function(_, _)
            wipe_state()
        end,
    })

    local items = lsp_parser.parse(response)

    M.state.outline_items = items
    M.state.flattened_outline_items = lsp_parser.flatten(items)

    writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)

    -- M._highlight_current_item(M.state.code_win)
end

return M
