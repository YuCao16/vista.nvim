local providers = require("vista-nvim.provider.init")

local M = {}

M.state = {
    outline_items = {},
    flattened_outline_items = {},
    code_win = 0,
}

local function _update_lines()
    M.state.flattened_outline_items = parser.flatten(M.state.outline_items)
    writer.parse_and_write(M.view.bufnr, M.state.flattened_outline_items)
end

local function _merge_items(items)
    utils.merge_items_rec(
        { children = items },
        { children = M.state.outline_items }
    )
end

local function refresh_handler(response)
    if response == nil or type(response) ~= "table" then
        return
    end

    local items = parser.parse(response)
    _merge_items(items)

    -- M.state.code_win = vim.api.nvim_get_current_win()

    -- _update_lines()
end

function M.refresh()
    providers.request_symbols(refresh_handler)
end
