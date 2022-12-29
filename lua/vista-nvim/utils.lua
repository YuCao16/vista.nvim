local M = {}
local api = vim.api
local luv = vim.loop

function M.echo_warning(msg)
    api.nvim_command("echohl WarningMsg")
    api.nvim_command("echom '[VistaNvim] " .. msg:gsub("'", "''") .. "'")
    api.nvim_command("echohl None")
end

function M.escape_keycode(key)
    return key:gsub("<", "["):gsub(">", "]")
end

function M.unescape_keycode(key)
    return key:gsub("%[", "<"):gsub("%]", ">")
end

function M.vista_nvim_callback(key)
    return string.format(
        ":lua require('vista-nvim.lib').on_keypress('%s')<CR>",
        M.escape_keycode(key)
    )
end

function M.vista_nvim_cursor_move_callback(direction)
    return string.format(
        ":lua require('vista-nvim')._on_cursor_move('%s')<CR>",
        direction
    )
end

local function get_builtin_section(name)
    local ret, section = pcall(require, "vista-nvim.builtin." .. name)
    if not ret then
        M.echo_warning("error trying to load section: " .. name)
        return nil
    end

    return section
end

function M.resolve_section(index, section)
    if type(section) == "string" then
        return get_builtin_section(section)
    elseif type(section) == "table" then
        return section
    end

    M.echo_warning("invalid VistaNvim section at: index=" .. index .. " section=" .. section)
    return nil
end


-- @param opts table
-- @param opts.modified boolean filter buffers by modified or not
function M.get_existing_buffers(opts)
    return vim.tbl_filter(function(buf)
        local modified_filter = true
        if opts and opts.modified ~= nil then
            local is_ok, is_modified =
                pcall(api.nvim_buf_get_option, buf, "modified")

            if is_ok then
                modified_filter = is_modified == opts.modified
            end
        end

        return api.nvim_buf_is_valid(buf)
            and vim.fn.buflisted(buf) == 1
            and modified_filter
    end, api.nvim_list_bufs())
end

return M
