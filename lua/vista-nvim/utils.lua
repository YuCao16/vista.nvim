local M = {}
local api = vim.api
local luv = vim.loop

function M.echo_warning(msg)
    api.nvim_command("echohl WarningMsg")
    api.nvim_command("echom '[SidebarNvim] " .. msg:gsub("'", "''") .. "'")
    api.nvim_command("echohl None")
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
