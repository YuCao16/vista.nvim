-- local config = require("vista-nvim.config")
--
-- return {
--     title = "Symbols",
--     icon = config["symbols"].icon,
--     highlights = {},
--     bindings = {},
--     draw = function()
--         local lines = {}
--         local hl = {}
--         if lines == nil or #lines == 0 then
--             return { lines = { "symbols" }, hl = {} }
--         else
--             return { lines = lines, hl = hl }
--         end
--     end,
-- }
local Loclist = require("sidebar-nvim.components.loclist")
local config = require("sidebar-nvim.config")
local view = require("sidebar-nvim.view")

local loclist = Loclist:new({ omit_single_group = true })
local open_symbols = {}
local last_buffer
local last_pos

local kinds = {
    { text = " ", hl = "@URI" },
    { text = " ", hl = "@Namespace" },
    { text = " ", hl = "@Namespace" },
    { text = " ", hl = "@Namespace" },
    { text = "𝓒 ", hl = "@Type" },
    { text = "ƒ ", hl = "@Method" },
    { text = " ", hl = "@Method" },
    { text = " ", hl = "@Field" },
    { text = " ", hl = "@Constructor" },
    { text = "ℰ ", hl = "@Type" },
    { text = "ﰮ ", hl = "@Type" },
    { text = " ", hl = "@Function" },
    { text = " ", hl = "@Constant" },
    { text = " ", hl = "@Constant" },
    { text = "𝓐 ", hl = "@String" },
    { text = "# ", hl = "@Number" },
    { text = "⊨ ", hl = "@Boolean" },
    { text = " ", hl = "@Constant" },
    { text = "⦿ ", hl = "@Type" },
    { text = " ", hl = "@Type" },
    { text = "NULL ", hl = "@Type" },
    { text = " ", hl = "@Field" },
    { text = "𝓢 ", hl = "@Type" },
    { text = "🗲 ", hl = "@Type" },
    { text = "+ ", hl = "@Operator" },
    { text = "𝙏 ", hl = "@Parameter" },
}

local function get_range(s)
    return s.range or s.location.range
end

local function build_loclist(filepath, loclist_items, symbols, level)
    table.sort(symbols, function(a, _)
        return get_range(a).start.line < get_range(a).start.line
    end)

    for _, symbol in ipairs(symbols) do
        local kind = kinds[symbol.kind]
        loclist_items[#loclist_items + 1] = {
            group = "symbols",
            left = {
                { text = string.rep(" ", level) .. kind.text, hl = kind.hl },
                { text = symbol.name .. " ", hl = "SidebarNvimSymbolsName" },
                { text = symbol.detail, hl = "SidebarNvimSymbolsDetail" },
            },
            right = {},
            data = { symbol = symbol, filepath = filepath },
        }

        -- uses a unique key for each symbol appending the name and position
        if
            symbol.children
            and open_symbols[symbol.name .. symbol.range.start.line .. symbol.range.start.character]
        then
            build_loclist(filepath, loclist_items, symbol.children, level + 1)
        end
    end
end

local function get_symbols(_)
    local current_buf = vim.api.nvim_get_current_buf()
    local current_pos = vim.lsp.util.make_position_params()

    -- if current buffer is sidebar's own buffer, use previous buffer
    if current_buf ~= view.View.bufnr then
        last_buffer = current_buf
        last_pos = current_pos
    else
        current_buf = last_buffer
        current_pos = last_pos
    end

    if
        current_buf == view.View.bufnr
        or not current_buf
        or not vim.api.nvim_buf_is_loaded(current_buf)
        or vim.api.nvim_buf_get_option(current_buf, "buftype") ~= ""
    then
        loclist:clear()
        return
    end

    local clients = vim.lsp.buf_get_clients(current_buf)
    local clients_filtered = vim.tbl_filter(function(client)
        return client.supports_method("textDocument/documentSymbol")
    end, clients)

    if #clients_filtered == 0 then
        loclist:clear()
        return
    end

    vim.lsp.buf_request(
        current_buf,
        "textDocument/documentSymbol",
        current_pos,
        function(err, method, symbols)
            if vim.fn.has("nvim-0.5.1") == 1 or vim.fn.has("nvim-0.8") == 1 then
                symbols = method
            end

            local loclist_items = {}
            local filepath = vim.api.nvim_buf_get_name(current_buf)
            if err ~= nil then
                return
            end

            if symbols ~= nil then
                build_loclist(filepath, loclist_items, symbols, 1)
                loclist:set_items(loclist_items, { remove_groups = false })
            end
        end
    )
end

return {
    title = "Symbols",
    icon = config["symbols"].icon,
    draw = function(ctx)
        local lines = {}
        local hl = {}

        get_symbols(ctx)

        loclist:draw(ctx, lines, hl)

        if lines == nil or #lines == 0 then
            return "<no symbols>"
        else
            return { lines = lines, hl = hl }
        end
    end,
    highlights = {
        groups = {},
        links = {
            SidebarNvimSymbolsName = "SidebarNvimNormal",
            SidebarNvimSymbolsDetail = "SidebarNvimLineNr",
        },
    },
    bindings = {
        -- ["t"] = function(line)
        --     local location = loclist:get_location_at(line)
        --     if location == nil then
        --         return
        --     end
        --     local symbol = location.data.symbol
        --     local key = symbol.name
        --         .. symbol.range.start.line
        --         .. symbol.range.start.character
        --
        --     if open_symbols[key] == nil then
        --         open_symbols[key] = true
        --     else
        --         open_symbols[key] = nil
        --     end
        -- end,
        -- ["e"] = function(line)
        --     local location = loclist:get_location_at(line)
        --     if location == nil then
        --         return
        --     end
        --
        --     local symbol = location.data.symbol
        --
        --     vim.cmd("wincmd p")
        --     vim.cmd("e " .. location.data.filepath)
        --     vim.fn.cursor(
        --         symbol.range.start.line + 1,
        --         symbol.range.start.character + 1
        --     )
        -- end,
    },
}
