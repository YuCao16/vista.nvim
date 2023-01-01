local M = {}

local function is_buffer_vista(bufnr)
    local isValid = vim.api.nvim_buf_is_valid(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    return string.match(name, "^VistaNvim_.*") ~= nil
        and ft == "VistaNvim"
        and isValid
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
    vim.api.nvim_echo({ { "vista parse and write", "None" } }, false, {})
    -- local lines, hl_info = parser.get_lines(flattened_outline_items)
    -- M.write_outline(bufnr, lines)

    -- clear_virt_text(bufnr)
    -- local details = parser.get_details(flattened_outline_items)
    -- M.add_highlights(bufnr, hl_info, flattened_outline_items)
    -- M.write_details(bufnr, details)
end

return M
