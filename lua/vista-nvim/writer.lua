local parser = require("vista-nvim.parsers.nvim_lsp")
local config = require("vista-nvim.config")
local highlight = require("vista-nvim.highlight")
local view = require("vista-nvim.view")

local M = {}

M.current_filepath = nil

local function is_buffer_vista(bufnr)
    local isValid = vim.api.nvim_buf_is_valid(bufnr)
    -- local name = vim.api.nvim_buf_get_name(bufnr)
    local name = vim.fn.bufname(bufnr)
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    return string.match(name, ".*VistaNvim_.*") ~= nil
        and ft == "VistaNvim"
        and isValid
end

local hlns = vim.api.nvim_create_namespace("vista-icon-highlight")
function M.add_highlights(bufnr, hl_info, nodes)
    if config.show_title then
        vim.api.nvim_buf_add_highlight(
            bufnr,
            hlns,
            "VistaOutlineTitle",
            0,
            3,
            -1
        )
    end
    for _, line_hl in ipairs(hl_info) do
        local line, hl_start, hl_end, hl_type = unpack(line_hl)
        vim.api.nvim_buf_add_highlight(
            bufnr,
            hlns,
            hl_type,
            line - 1 + view.View.title_line,
            hl_start,
            hl_end
        )
    end

    -- TODO: add hover highlight
    M.add_hover_highlights(bufnr, nodes)
end

M.add_hover_highlights = function(bufnr, nodes)
    if not config.highlight_hovered_item then
        return
    end

    -- clear old highlight
    highlight.clear_hover_highlight(bufnr)
    for _, node in ipairs(nodes) do
        if not node.hovered then
            goto continue
        end

        local marker_fac = (config.fold_markers and 1) or 0
        if node.prefix_length then
            highlight.add_hover_highlight(
                bufnr,
                node.line_in_outline - 1 + view.View.title_line,
                node.prefix_length
            )
        end
        ::continue::
    end
end

-- TODO: more readable
function M.clean_path(filepath)
    local width = config.width
    filepath = filepath
    if filepath:len() > width - 3 then
        filepath = "..." .. filepath:sub(-width + 7, -1)
    end
    return filepath
end

function M.write_middle()
    local ret = {}
    local win_height_half = 10
    if type(view.View.win_height) == "number" then
        win_height_half = math.floor(view.View.win_height / 2) - 3
    end
    for i=1,win_height_half do
        table.insert(ret, "")
    end
    table.insert(ret, "          No symbols")
    table.insert(ret, "      lsp (not supported) ")
    table.insert(ret, "     [No LSP client found]")
    return ret
end

local hlld = vim.api.nvim_create_namespace("vista-nvim-loading")
function M.write_title_loading(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
        config.fold_markers[2] .. " " .. M.clean_path(
            view.View.current_filepath
        ),
    })
    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, M.write_middle())
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_add_highlight(bufnr, hlld, "@method", 0, 3, -1)
end

function M.write_title(bufnr)
    -- TODO: arrange to one statement
    if not is_buffer_vista(bufnr) then
        return
    end
    if not config.show_title then
        return
    end
    -- if current window is VistaNvim window
    if view.View.bufnr == vim.api.nvim_get_current_buf() then
        return
    end
    -- if current filepath change
    if M.current_filepath == view.View.current_filepath then
        return
    end
    if string.match(view.View.current_filepath, ".*VistaNvim_.*") then
        return
    end
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
        config.fold_markers[2] .. " " .. M.clean_path(
            view.View.current_filepath
        ),
    })
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    M.current_filepath = view.View.current_filepath
end

function M.write_vista(bufnr, lines)
    if not is_buffer_vista(bufnr) then
        return
    end

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    if config.show_title then
        vim.api.nvim_buf_set_lines(
            bufnr,
            view.View.title_line,
            -1,
            false,
            lines
        )
    else
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- runs the whole writing routine where the text is cleared, new data is parsed
-- and then written
function M.parse_and_write(bufnr, flattened_outline_items)
    -- vim.api.nvim_echo({ { "vista parse and write", "None" } }, false, {})
    local lines, hl_info = parser.get_lines(flattened_outline_items)
    M.write_title(bufnr)
    M.write_vista(bufnr, lines)

    -- clear_virt_text(bufnr)
    -- local details = parser.get_details(flattened_outline_items)
    M.add_highlights(bufnr, hl_info, flattened_outline_items)
    -- M.write_details(bufnr, details)
end

return M
