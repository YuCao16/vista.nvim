local writer = require("vista-nvim.writer")
local config = require("vista-nvim.config")
local folding = require("vista-nvim.folding")
local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
local utils_lsp = require("vista-nvim.utils.lsp_utils")
local utils_basic = require("vista-nvim.utils.basic")
local view = require("vista-nvim.view")
local providers = require("vista-nvim.providers.init")

local M = {}

M.state = require("vista-nvim").data

local function wipe_state()
    M.state = { outline_items = {}, flattened_outline_items = {}, code_win = 0 }
end

function M._update_lines()
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
    if M.state.flattened_outline_items == nil then
        vim.notify("flatten nil")
    end
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
    M.state.current_bufnr = vim.fn.bufnr()

    M._update_lines()
end

function M.handler(response)
    if response == nil or type(response) ~= "table" then
        return
    end

    M.state.code_win = vim.api.nvim_get_current_win()
    M.state.current_bufnr = vim.fn.bufnr()

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

---------------
--goto_location
---------------

function M._current_node()
    local current_line = vim.api.nvim_win_get_cursor(view.get_winnr())[1]
    return M.state.flattened_outline_items[current_line]
end

function M.goto_location(change_focus)
    local node = M._current_node()
    vim.api.nvim_win_set_cursor(
        M.state.code_win,
        { node.line + 1, node.character }
    )
    if change_focus then
        vim.fn.win_gotoid(M.state.code_win)
        vim.cmd("normal! zz")
        -- utils_basic.flash_highlight(vim.fn.bufnr(), node.line + 1)
    end
    if config.auto_close then
        M.close_outline()
    end
    utils_basic.flash_highlight(M.state.current_bufnr, node.line + 1)
end

---------------
-- fold
---------------
function M._set_folded(folded, move_cursor, node_index)
    local node = M.state.flattened_outline_items[node_index]
        or M._current_node()
    local changed = (folded ~= folding.is_folded(node))

    if folding.is_foldable(node) and changed then
        node.folded = folded

        if move_cursor then
            vim.api.nvim_win_set_cursor(view.get_winnr(), { node_index, 0 })
        end

        M._update_lines()
    elseif node.parent then
        local parent_node =
            M.state.flattened_outline_items[node.parent.line_in_outline]

        if parent_node then
            M._set_folded(
                folded,
                not parent_node.folded and folded,
                parent_node.line_in_outline
            )
        end
    end
end

function M.toggle_fold()
    local node = M.state.flattened_outline_items[node_index]
        or M._current_node()
    if folding.is_foldable(node) then
        if folding.is_folded(node) then
            M._set_folded(false)
        else
            M._set_folded(true)
        end
    end
end

function M._set_all_folded(folded, nodes)
    nodes = nodes or M.state.outline_items

    for _, node in ipairs(nodes) do
        node.folded = folded
        if node.children then
            M._set_all_folded(folded, node.children)
        end
    end
end

function M.set_all_folded(folded, nodes)
    M._set_all_folded(folded, nodes)
    M._update_lines()
end

---------------
-- highlight
---------------
--TODO: while auto fold, folded items still be toggled
function M._highlight_current_item(winnr)
    local has_provider = providers.has_provider(view.View.provider)

    local is_current_buffer_the_outline = view.View.bufnr
        == vim.api.nvim_get_current_buf()

    local doesnt_have_outline_buf = not view.View.bufnr

    local should_exit = not has_provider
        or doesnt_have_outline_buf
        or is_current_buffer_the_outline
    -- local should_exit = is_current_buffer_the_outline

    -- Make a special case if we have a window number
    -- Because we might use this to manually focus so we dont want to quit this
    -- function
    if winnr then
        should_exit = false
    end

    if should_exit then
        return
    end

    local win = winnr or vim.api.nvim_get_current_win()

    local hovered_line = vim.api.nvim_win_get_cursor(win)[1] - 1

    local leaf_node = nil

    local cb = function(value)
        value.hovered = nil

        if
            value.line == hovered_line
            or (
                hovered_line > value.range_start
                and hovered_line < value.range_end
            )
        then
            value.hovered = true
            leaf_node = value
        end
    end

    utils_basic.items_dfs(cb, M.state.outline_items)

    M._update_lines()

    if leaf_node then
        for index, node in ipairs(M.state.flattened_outline_items) do
            if node == leaf_node then
                vim.api.nvim_win_set_cursor(view.get_winnr(), { index, 1 })
                break
            end
        end
    end
end

return M
