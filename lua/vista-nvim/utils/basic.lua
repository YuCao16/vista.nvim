local M = {}

local api = vim.api

function M.echo_warning(msg)
    api.nvim_command("echohl WarningMsg")
    api.nvim_command("echom '[VistaNvim] " .. msg:gsub("'", "''") .. "'")
    api.nvim_command("echohl None")
end

function M.has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end
    return false
end

--- @param  f function
--- @param  delay number
--- @return function
function M.debounce(f, delay)
    local timer = vim.loop.new_timer()

    return function(...)
        local args = { ... }

        timer:start(
            delay,
            0,
            vim.schedule_wrap(function()
                timer:stop()
                f(unpack(args))
            end)
        )
    end
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

M.flash_highlight = function(bufnr, lnum)
    hl_group = "VistaFlashLine"
    durationMs = 450
    local ns =
        vim.api.nvim_buf_add_highlight(bufnr, 0, hl_group, lnum - 1, 0, -1)
    local remove_highlight = function()
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
    end
    vim.defer_fn(remove_highlight, durationMs)
end

function M.items_dfs(callback, children)
    for _, val in ipairs(children) do
        callback(val)

        if val.children then
            M.items_dfs(callback, val.children)
        end
    end
end

-- this function is working with M.unescape_keycode to avoid lua bad argument error
function M.escape_keycode(key)
    return key:gsub("<", "["):gsub(">", "]")
end

function M.unescape_keycode(key)
    return key:gsub("%[", "<"):gsub("%]", ">")
end

return M
