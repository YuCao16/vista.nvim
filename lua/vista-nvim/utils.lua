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

local function get_provider_section(name)
    local ret, section = pcall(require, "vista-nvim.provider." .. name)
    if not ret then
        M.echo_warning("error trying to load provider: " .. name)
        return nil
    end

    return section
end

function M.resolve_section(index, section)
    if type(section) == "string" then
        return get_provider_section(section)
    elseif type(section) == "table" then
        return section
    end

    M.echo_warning(
        "invalid VistaNvim section at: index="
            .. index
            .. " section="
            .. section
    )
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

---Merges a symbol tree recursively, only replacing nodes
---which have changed. This will maintain the folding
---status of any unchanged nodes.
---@param new_node table New node
---@param old_node table Old node
---@param index? number Index of old_item in parent
---@param parent? table Parent of old_item
M.merge_items_rec = function(new_node, old_node, index, parent)
    local failed = false

    if not new_node or not old_node then
        failed = true
    else
        for key, _ in pairs(new_node) do
            if
                vim.tbl_contains({
                    "parent",
                    "children",
                    "folded",
                    "hovered",
                    "line_in_outline",
                    "hierarchy",
                }, key)
            then
                goto continue
            end

            if key == "name" then
                -- in the case of a rename, just rename the existing node
                old_node["name"] = new_node["name"]
            else
                if not vim.deep_equal(new_node[key], old_node[key]) then
                    failed = true
                    break
                end
            end

            ::continue::
        end
    end

    if failed then
        if parent and index then
            parent[index] = new_node
        end
    else
        local next_new_item = new_node.children or {}

        -- in case new children are created on a node which
        -- previously had no children
        if #next_new_item > 0 and not old_node.children then
            old_node.children = {}
        end

        local next_old_item = old_node.children or {}

        for i = 1, math.max(#next_new_item, #next_old_item) do
            M.merge_items_rec(
                next_new_item[i],
                next_old_item[i],
                i,
                next_old_item
            )
        end
    end
end

return M
