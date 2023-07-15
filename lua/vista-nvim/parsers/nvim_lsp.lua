local render = require("vista-nvim.render")
local config = require("vista-nvim.config")
local utils_table = require("vista-nvim.utils.table")
local utils_basic = require("vista-nvim.utils.basic")
local folding = require("vista-nvim.folding")
local kind = require("vista-nvim.render").kinds_number
local view = require("vista-nvim.view")

local M = {}

M.type_fold_info = {}

M.get_default_fold_type = function(classified_outline_items)
    if view.View.last_filename == nil then
        return
    end
    -- local rules_ft = {}
    -- for key, _ in pairs(config.filetype_map) do
    --     if config.filetype_map[key].type_symbol_blacklist ~= {} then
    --         table.insert(rules_ft, key)
    --     end
    -- end
    for k, v in pairs(classified_outline_items) do
        local kind_name = vim.lsp.protocol.SymbolKind[k]
        if not v.data.expand then
            M.type_fold_info[view.View.last_filename][kind_name] = true
        end
    end
end

-- TODO: implement multiple Lsp coorperate
-- Now this is disalbe in M.parse()

---Parses result from LSP into a table of symbols
---@param result table The result from a language server.
---@param depth number? The current depth of the symbol in the hierarchy.
---@param hierarchy table? A table of booleans which tells if a symbols parent was the last in its group.
---@param parent table? A reference to the current symbol's parent in the function's recursion
---@return table
local function parse_result(result, depth, hierarchy, parent)
    local ret = {}

    for index, value in pairs(result) do
        if not config.is_symbol_blacklisted(render.kinds[value.kind], view.View.last_ft) then
            -- the hierarchy is basically a table of booleans which tells whether
            -- the parent was the last in its group or not
            local hir = hierarchy or {}
            -- how many parents this node has, 1 is the lowest value because its
            -- easier to work it
            local level = depth or 1
            -- whether this node is the last in its group
            local isLast = index == #result

            -- support SymbolInformation[]
            -- https://microsoft.github.io/language-server-protocol/specification#textDocument_documentSymbol
            local selectionRange = value.selectionRange
            if value.selectionRange == nil then
                selectionRange = value.location.range
            end

            local range = value.range
            if value.range == nil then
                range = value.location.range
            end

            local node = {
                deprecated = value.deprecated,
                kind = value.kind,
                icon = render.icon_from_kind(value.kind),
                name = value.name or value.text,
                detail = value.detail,
                line = selectionRange.start.line,
                character = selectionRange.start.character,
                range_start = range.start.line,
                range_end = range["end"].line,
                depth = level,
                isLast = isLast,
                hierarchy = hir,
                parent = parent,
            }

            table.insert(ret, node)

            local children = nil
            if value.children ~= nil then
                -- copy by value because we dont want it messing with the hir table
                local child_hir = utils_table.array_copy(hir)
                table.insert(child_hir, isLast)
                children =
                    parse_result(value.children, level + 1, child_hir, node)
            end

            node.children = children
        end
    end
    return ret
end

---Sorts the result from LSP by where the symbols start.
---@param result table Result containing symbols returned from textDocument/documentSymbol
---@return table
local function sort_result(result)
    ---Returns the start location for a symbol, or nil if not found.
    ---@param item table The symbol.
    ---@return table|nil
    local function get_range_start(item)
        if item.location ~= nil then
            return item.location.range.start
        elseif item.range ~= nil then
            return item.range.start
        else
            return nil
        end
    end

    table.sort(result, function(a, b)
        local a_start = get_range_start(a)
        local b_start = get_range_start(b)

        -- if they both are equal, a should be before b
        if a_start == nil and b_start == nil then
            return false
        end

        -- those with no start go first
        if a_start == nil then
            return true
        end
        if b_start == nil then
            return false
        end

        -- first try to sort by line. If lines are equal, sort by character instead
        if a_start.line ~= b_start.line then
            return a_start.line < b_start.line
        else
            return a_start.character < b_start.character
        end
    end)

    return result
end
M.response = {}
M.response_result = {}
M.all_result = {}
---Parses the response from lsp request 'textDocument/documentSymbol' using buf_request_all
---@param response table The result from buf_request_all
---@return table outline items
function M.parse(response)
    local all_results = {}

    -- this ensure that if multiple lsp are using, only got symbol from one of them
    -- avoid duplicate symbols
    local got_result = false

    -- flatten results to one giant table of symbols
    for client_id, client_response in pairs(response) do
        if got_result then
            goto continue
        end
        if config.is_client_blacklisted_id(client_id) then
            print("skipping client " .. client_id)
            goto continue
        end

        local result = client_response["result"]
        if result == nil or type(result) ~= "table" then
            goto continue
        end
        M.response = client_response
        M.response_result = result

        for _, value in pairs(result) do
            table.insert(all_results, value)
        end
        got_result = true

        ::continue::
    end

    local sorted = sort_result(all_results)

    return parse_result(sorted, nil, nil)
end

function M.filter_type_result(result)

end

function M.parse_type(response)
    local all_results = {}

    local got_result = false
    for client_id, client_response in pairs(response) do
        if got_result then
            goto continue
        end
        if config.is_client_blacklisted_id(client_id) then
            print("skipping client " .. client_id)
            goto continue
        end

        local result = client_response["result"]
        if result == nil or type(result) ~= "table" then
            goto continue
        end
        M.response = client_response
        M.response_result = result

        for _, value in pairs(result) do
            table.insert(all_results, value)
        end
        got_result = true

        ::continue::
    end

    M.all_result = all_results
    return all_results
end

function M.node_is_keyword(buf, node)
    if not node.selectionRange then
        return false
    end
    local captures =
        vim.treesitter.get_captures_at_pos(buf, node.selectionRange.start.line, node.selectionRange.start.character)
    for _, v in pairs(captures) do
        if v.capture == "keyword" or v.capture == "conditional" or v.capture == "repeat" then
            return true
        end
    end
    return false
end

-- TODO: Default fold if items too many
function M.classify(result)
    local res = {}

    local tmp_node = function(node)
        local tmp = {}
        tmp.winline = -1
        for k, v in pairs(node) do
            if k ~= "children" then
                tmp[k] = v
            end
        end
        return tmp
    end

    local function recursive_parse(tbl)
        for _, v in pairs(tbl) do
            if not res[v.kind] then
                res[v.kind] = {
                    expand = true,
                    data = {},
                }
            end
            local lsp_bufnr = 0
            if view.View.lsp_bufnr ~= nil then
                lsp_bufnr = view.View.lsp_bufnr
            end
            if not M.node_is_keyword(lsp_bufnr, v) then
                -- if not config.is_type_symbol_blacklisted(render.kinds[v.kind], view.View.last_ft) then
                local tmp = tmp_node(v)
                table.insert(res[v.kind].data, tmp)
                -- end
            end

            if v.children then
                recursive_parse(v.children)
            end
        end
    end
    recursive_parse(result)
    local keys = vim.tbl_keys(res)
    table.sort(keys, nil)
    local new = {}
    for _, v in pairs(keys) do
        new[v] = res[v]
        if view.View.last_ft ~= nil then
            if utils_basic.has_value(config.filetype_map[view.View.last_ft].type_symbol_blacklist, vim.lsp.protocol.SymbolKind[v]) then
                new[v].should_folded = true
            end
        end
    end

    -- remove unnecessary data reduce memory usage
    for k, v in pairs(new) do
        if #v.data == 0 then
            new[k] = nil
        else
            for _, item in pairs(v.data) do
                if item.selectionRange then
                    item.pos = {
                        item.selectionRange.start.line,
                        item.selectionRange.start.character,
                    }
                    item.selectionRange = nil
                end
            end
        end
    end

    return new
end

function M.flatten(outline_items, ret, depth)
    depth = depth or 1
    ret = ret or {}
    for _, value in ipairs(outline_items) do
        table.insert(ret, value)
        value.line_in_outline = #ret
        if value.children ~= nil and not folding.is_folded(value) then
            M.flatten(value.children, ret, depth + 1)
        end
    end
    return ret
end

function M.get_lines(outline_items, theme)
    if theme == "type" then
        return M.get_lines_type(outline_items)
    else
        return M.get_lines_tree(outline_items)
    end
end

function M.get_lines_type(classified_outline_items)
    local lines = {}
    local hi = {}
    for k, v in pairs(classified_outline_items) do
        if v.should_folded then
            local scope = {}
            local indent_with_icon = "  " .. config.fold_markers[2]
            table.insert(lines, indent_with_icon .. " " .. kind[k][1])
            scope["VistaConnector"] = { 0, #indent_with_icon }
            scope["VistaOutline" .. kind[k][1]] = { #indent_with_icon, -1 }
            table.insert(hi, scope)
            v.winline = #lines
            for j, node in pairs(v.data) do
                node.hi_scope = {}
                local indent = j == #v.data and "  └" .. " " or "  │" .. " "
                node.name = indent .. kind[node.kind][2] .. node.name
                node.hi_scope["VistaIndent"] = { 0, #indent }
                node.hi_scope["VistaOutline" .. kind[node.kind][1]] =
                { #indent, #indent + #kind[node.kind][2] }
                node.winline = #lines
            end
            table.insert(lines, "")
            table.insert(hi, {})
            v.should_folded = false
            v.expand = false
        else
            local scope = {}
            local indent_with_icon = "  " .. config.fold_markers[1]
            table.insert(lines, indent_with_icon .. " " .. kind[k][1])
            scope["VistaConnector"] = { 0, #indent_with_icon }
            scope["VistaOutline" .. kind[k][1]] = { #indent_with_icon, -1 }
            table.insert(hi, scope)
            v.winline = #lines
            for j, node in pairs(v.data) do
                node.hi_scope = {}
                local indent = j == #v.data and "  └" .. " " or "  │" .. " "
                node.name = indent .. kind[node.kind][2] .. node.name
                table.insert(lines, node.name)
                node.hi_scope["VistaIndent"] = { 0, #indent }
                node.hi_scope["VistaOutline" .. kind[node.kind][1]] =
                { #indent, #indent + #kind[node.kind][2] }
                table.insert(hi, node.hi_scope)
                node.winline = #lines
            end
            table.insert(lines, "")
            table.insert(hi, {})
        end
    end
    table.remove(lines) -- remove the blank line after last line
    table.remove(hi)
    return lines, hi
end

function M.get_lines_tree(flattened_outline_items)
    local lines = {}
    local hl_info = {}

    for node_line, node in ipairs(flattened_outline_items) do
        local depth = node.depth
        local marker_space = (config.fold_markers and 1) or 0

        local line = utils_table.str_to_table(string.rep(" ", depth + marker_space))
        local running_length = 1

        local function add_guide_hl(from, to)
            table.insert(hl_info, {
                node_line,
                from,
                to,
                "VistaConnector",
            })
        end

        for index, _ in ipairs(line) do
            -- all items start with a space (or two)
            if config.show_guides then
                -- makes the guides
                if index == 1 then
                    line[index] = " "
                    -- if index is last, add a bottom marker if current item is last,
                    -- else add a middle marker
                elseif index == #line then
                    -- add fold markers
                    if config.fold_markers
                        and folding.is_foldable(node)
                    then
                        if folding.is_folded(node) then
                            line[index] = config.fold_markers[1]
                        else
                            line[index] = config.fold_markers[2]
                        end

                        add_guide_hl(
                            running_length,
                            running_length + vim.fn.strlen(line[index]) - 1
                        )

                        -- the root level has no vertical markers
                    elseif depth > 1 then
                        if node.isLast then
                            line[index] = render.markers.bottom
                            add_guide_hl(
                                running_length,
                                running_length
                                + vim.fn.strlen(render.markers.bottom)
                                - 1
                            )
                        else
                            line[index] = render.markers.middle
                            add_guide_hl(
                                running_length,
                                running_length
                                + vim.fn.strlen(render.markers.middle)
                                - 1
                            )
                        end
                    end
                    -- else if the parent was not the last in its group, add a
                    -- vertical marker because there are items under us and we need
                    -- to point to those
                elseif not node.hierarchy[index] and depth > 1 then
                    line[index + marker_space] = render.markers.vertical
                    add_guide_hl(
                        running_length - 1 + 2 * marker_space,
                        running_length
                        + vim.fn.strlen(render.markers.vertical)
                        - 1
                        + 2 * marker_space
                    )
                end
            end

            line[index] = line[index] .. " "

            running_length = running_length + vim.fn.strlen(line[index])
        end

        local final_prefix = line

        local string_prefix = utils_table.table_to_str(final_prefix)

        table.insert(lines, string_prefix .. node.icon .. " " .. node.name)

        local hl_start = #string_prefix
        local hl_end = #string_prefix + #node.icon
        local hl_type = config.symbols[render.kinds[node.kind]].hl
        table.insert(hl_info, { node_line, hl_start, hl_end, hl_type })

        node.prefix_length = #string_prefix + #node.icon + 1
    end
    return lines, hl_info
end

function M.get_details(flattened_outline_items)
    local lines = {}
    for _, value in ipairs(flattened_outline_items) do
        table.insert(lines, value.detail or "")
    end
    return lines
end

return M
