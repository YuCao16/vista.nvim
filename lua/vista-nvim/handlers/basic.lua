local writer = require("vista-nvim.writer")
local config = require("vista-nvim.config")
local folding = require("vista-nvim.folding")
local lsp_parser = require("vista-nvim.parsers.nvim_lsp")
local utils_lsp = require("vista-nvim.utils.lsp_utils")
local utils_basic = require("vista-nvim.utils.basic")
local view = require("vista-nvim.view")
local providers = require("vista-nvim.providers.init")
local kind = require("vista-nvim.render").kinds_number

local a = vim.api

local M = {}

M.state = require("vista-nvim").data
M.current_theme = writer.structure_theme
M.lsp_filepath = nil

M.handler_bindings = {
    ["<CR>"] = function()
        require("vista-nvim.handlers.basic").goto_location(true)
    end,
    ["<2-LeftMouse>"] = function()
        require("vista-nvim.handlers.basic").goto_location(true)
    end,
    ["p"] = function()
        require("vista-nvim.handlers.basic").goto_location(false)
    end,
    ["o"] = function()
        require("vista-nvim.handlers.basic").toggle_fold()
    end,
    ["zr"] = function()
        require("vista-nvim.handlers.basic").set_all_folded(true)
    end,
    ["zR"] = function()
        require("vista-nvim.handlers.basic").set_all_folded(false)
    end,
    ["s"] = function()
        require("vista-nvim.handlers.basic")._switch_theme()
    end,
}

-- convert a function to callback string
function M.execute_binding(key)
    key = utils_basic.unescape_keycode(key)
    M.handler_bindings[key]()
end

function M.setup_handler_binding()
    for key, _ in pairs(M.handler_bindings) do
        a.nvim_buf_set_keymap(
            view.View.bufnr,
            "n",
            key,
            string.format(
                ":lua require('vista-nvim.handlers.basic').execute_binding('%s')<CR>",
                utils_basic.escape_keycode(key)
            ),
            { noremap = true, silent = true, nowait = true }
        )
    end
end

local function wipe_state()
    M.state = {
        outline_items = {},
        flattened_outline_items = {},
        type_items = {},
        classified_outline_items = {},
        code_win = 0,
    }
end

function M._update_lines()
    if #vim.lsp.get_active_clients({bufnr = 0}) ~= 0 then
        if M.lsp_filepath ~= vim.api.nvim_buf_get_name(0) then
            M.lsp_filepath = vim.api.nvim_buf_get_name(0)
        else
            return
        end
    end
    M.state.flattened_outline_items = lsp_parser.flatten(M.state.outline_items)
    M.state.classified_outline_items = lsp_parser.classify(M.state.type_items)
    if writer.structure_theme == "type" then
        writer.parse_and_write(
            view.View.bufnr,
            M.state.classified_outline_items
        )
        return
    end
    writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)
end

function M._merge_items(items)
    utils_lsp.merge_items_rec(
        { children = items },
        { children = M.state.outline_items }
    )
end

function M.handler(response)
    vim.api.nvim_echo({ { "handler called firstly", "None" } }, false, {})
    M.setup_handler_binding()
    if response == nil or type(response) ~= "table" then
        return
    end

    M.state.code_win = vim.api.nvim_get_current_win()
    M.state.current_bufnr = vim.fn.bufnr()
    M.lsp_filepath = vim.api.nvim_buf_get_name(0)

    -- clear state when buffer is closed
    vim.api.nvim_buf_attach(view.View.bufnr, false, {
        on_detach = function(_, _)
            wipe_state()
        end,
    })

    local items = lsp_parser.parse(response)
    local items_type = lsp_parser.parse_type(response)

    M.state.outline_items = items
    M.state.type_items = items_type
    M.state.flattened_outline_items = lsp_parser.flatten(items)
    M.state.classified_outline_items = lsp_parser.classify(items_type)

    if M.current_theme == "type" then
        writer.parse_and_write(
            view.View.bufnr,
            M.state.classified_outline_items
        )
        return
    end
    writer.parse_and_write(view.View.bufnr, M.state.flattened_outline_items)

    M._highlight_current_item(M.state.code_win)
end

function M.refresh_handler(response)
    if response == nil or type(response) ~= "table" then
        return
    end

    local items = lsp_parser.parse(response)
    local items_type = lsp_parser.parse_type(response)
    M._merge_items(items)

    M.state.type_items = items_type
    M.state.code_win = vim.api.nvim_get_current_win()
    M.state.current_bufnr = vim.fn.bufnr()

    M._update_lines()
end

---------------
--goto_location
---------------
local function find_node(data, line)
    for _, node in pairs(data or {}) do
        if node.winline == line then
            return node
        end
    end
end

function M._current_node()
    local current_line = vim.api.nvim_win_get_cursor(view.get_winnr())[1]
        - view.View.title_line
    -- if M.current_theme == "type" then
    --     return M.state.flattened_outline_items[current_line]
    -- end
    return M.state.flattened_outline_items[current_line]
end

function M.goto_location(change_focus)
    if M.current_theme == "tree" then
        M.goto_location_tree()
    elseif M.current_theme == "type" then
        res = M.goto_location_type()
        -- M.goto_location_type()
    end
    if config.auto_close then
        M.close_outline()
    end
    if res then
        return
    end
    if change_focus then
        vim.fn.win_gotoid(M.state.code_win)
        vim.cmd("normal! zz")
    end
end

function M.goto_location_tree()
    local node = M._current_node()
    vim.api.nvim_win_set_cursor(
        M.state.code_win,
        { node.line + 1, node.character }
    )
    utils_basic.flash_highlight(M.state.current_bufnr, node.line + 1)
end

function M.goto_location_type()
    local curline = vim.api.nvim_win_get_cursor(0)[1] - 1
    local node
    for _, nodes in pairs(M.state.classified_outline_items) do
        node = find_node(nodes.data, curline)
        if node then
            break
        end
    end

    if not node then
        return true
    end
    local range = node.range and node.range or node.location.range

    local winid = M.state.code_win
    if node.pos then
        vim.api.nvim_win_set_cursor(winid, { node.pos[1] + 1, node.pos[2] })
    else
        vim.api.nvim_win_set_cursor(
            winid,
            { range.start.line + 1, range.start.character }
        )
    end
    utils_basic.flash_highlight(M.state.current_bufnr, node.pos[1] + 1)
end

---------------
-- switch theme
---------------
function M._switch_theme()
    local current_theme = writer.structure_theme
    if current_theme == "tree" then
        writer.structure_theme = "type"
    elseif current_theme == "type" then
        writer.structure_theme = "tree"
    end
    M.current_theme = writer.structure_theme

    M._update_lines()
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
    if M.current_theme == "tree" then
        M.toggle_fold_tree()
    elseif M.current_theme == "type" then
        M.toggle_fold_type()
    end
end

function M.toggle_fold_tree()
    local node = M._current_node()
    if folding.is_foldable(node, M.current_theme) then
        if folding.is_folded(node) then
            M._set_folded(false)
        else
            M._set_folded(true)
        end
    end
end

function M.toggle_fold_type()
    local curline = vim.api.nvim_win_get_cursor(0)[1] - 1
    local node = find_node(M.state.classified_outline_items, curline)
    if not node then
        return
    end

    local function increase_or_reduce(lnum, num)
        for k, v in pairs(M.state.classified_outline_items) do
            if v.winline > lnum then
                M.state.classified_outline_items[k].winline = M.state.classified_outline_items[k].winline
                    + num
                for _, item in pairs(v.data) do
                    item.winline = item.winline + num
                end
            end
        end
    end

    if node.expand then
        local text = vim.api.nvim_get_current_line()
        text = text:gsub(config.fold_markers[1], config.fold_markers[2])
        for _, v in pairs(node.data) do
            v.winline = -1
        end
        vim.bo[view.View.bufnr].modifiable = true
        vim.api.nvim_buf_set_lines(
            view.View.bufnr,
            curline,
            curline + #node.data + 1,
            false,
            { text }
        )
        vim.bo[view.View.bufnr].modifiable = false
        node.expand = false
        vim.api.nvim_buf_add_highlight(
            view.View.bufnr,
            0,
            "VistaConnector",
            curline,
            0,
            5
        )
        vim.api.nvim_buf_add_highlight(
            view.View.bufnr,
            0,
            "VistaOutline" .. kind[node.data[1].kind][1],
            curline,
            5,
            -1
        )
        increase_or_reduce(node.winline + #node.data, -#node.data)
        return
    end

    local lines = {}
    local text = vim.api.nvim_get_current_line()
    text = text:gsub(config.fold_markers[2], config.fold_markers[1])
    table.insert(lines, text)
    for i, v in pairs(node.data) do
        table.insert(lines, v.name)
        v.winline = curline + i
    end
    vim.bo[view.View.bufnr].modifiable = true
    vim.api.nvim_buf_set_lines(
        view.View.bufnr,
        curline,
        curline + 1,
        false,
        lines
    )
    vim.bo[view.View.bufnr].modifiable = false
    node.expand = true
    vim.api.nvim_buf_add_highlight(
        view.View.bufnr,
        0,
        "VistaConnector",
        curline,
        0,
        5
    )
    vim.api.nvim_buf_add_highlight(
        view.View.bufnr,
        0,
        "VistaOutline" .. kind[node.data[1].kind][1],
        curline,
        5,
        -1
    )
    for _, v in pairs(node.data) do
        for group, scope in pairs(v.hi_scope) do
            vim.api.nvim_buf_add_highlight(
                view.View.bufnr,
                0,
                group,
                v.winline,
                scope[1],
                scope[2]
            )
        end
    end

    increase_or_reduce(node.winline, #node.data)
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

function M.is_empty_line()
    if a.nvim_get_current_line() == "" then
        return true
    else
        return false
    end
end

---------------
-- highlight
---------------
-- TODO: toggle logic need improvement
-- eg. if current line is return, then highlight return to class name not remain
-- around current/previous function
-- By change the end of item be the start of next item.
function M._highlight_current_item(winnr)
    if M.current_theme == "type" then
        return
    end

    local has_provider = providers.has_provider(view.View.provider)

    local is_current_buffer_the_outline = view.View.bufnr
        == vim.api.nvim_get_current_buf()

    local doesnt_have_outline_buf =
        not view.is_win_open({ any_tabpage = false })

    local is_empty_line = M.is_empty_line()

    local should_exit = not has_provider
        or doesnt_have_outline_buf
        or is_current_buffer_the_outline
        or is_empty_line
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
                vim.api.nvim_win_set_cursor(
                    view.get_winnr(),
                    { index + view.View.title_line, 1 }
                )
                break
            end
        end
    end
end

return M
