local parser = require("vista-nvim.parsers.nvim_lsp")
local config = require("vista-nvim.config")
local highlight = require("vista-nvim.highlight")

local M = {}

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
    for _, line_hl in ipairs(hl_info) do
        local line, hl_start, hl_end, hl_type = unpack(line_hl)
        vim.api.nvim_buf_add_highlight(
            bufnr,
            hlns,
            hl_type,
            line - 1,
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
                node.line_in_outline - 1,
                node.prefix_length
            )
        end
        ::continue::
    end
end

function M.write_vista(bufnr, lines)
    if not is_buffer_vista(bufnr) then
        return
    end
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- runs the whole writing routine where the text is cleared, new data is parsed
-- and then written
function M.parse_and_write(bufnr, flattened_outline_items)
    -- vim.api.nvim_echo({ { "vista parse and write", "None" } }, false, {})
    local lines, hl_info = parser.get_lines(flattened_outline_items)
    M.write_vista(bufnr, lines)

    -- clear_virt_text(bufnr)
    -- local details = parser.get_details(flattened_outline_items)
    M.add_highlights(bufnr, hl_info, flattened_outline_items)
    -- M.write_details(bufnr, details)
end

return M
