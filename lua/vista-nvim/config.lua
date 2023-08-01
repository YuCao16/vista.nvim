local M = {}

M.highlight_hovered_item = true
M.width = 30
M.side = "right"
M.bindings = nil
M.disable_default_keybindings = false
M.show_guides = true
M.show_title = true
M.border = "rounded"
M.auto_close = false
M.auto_preview = false
M.disable_max_lines = 10000
M.disable_max_sizes = 2000000 -- Default 2MB
M.default_provider = "lsp"
M.theme = "type" -- tree or type
M.filetype_map = {
    python = {
        provider = "lsp",
        symbol_blacklist = { "Module" },
        type_symbol_blacklist = { "Module" },
    },
    rust = {
        provider = "lsp",
        symbol_blacklist = {},
        type_symbol_blacklist = {},
    },
    lua = {
        provider = "lsp",
        symbol_blacklist = {
            "Variable",
            "Constant",
            "String",
            "Number",
            "Boolean",
            "Array",
            "Package",
        },
        type_symbol_blacklist = {
            "Variable",
            "Constant",
            "String",
            "Number",
            "Boolean",
            "Array",
            "Package",
        },
    },
    cpp = {
        provider = "lsp",
        symbol_blacklist = {},
        type_symbol_blacklist = {},
    },
    c = { provider = "lsp", symbol_blacklist = {}, type_symbol_blacklist = {} },
    markdown = {
        provider = "lsp",
        symbol_blacklist = {},
        type_symbol_blacklist = {},
    },
}
M.show_symbol_details = true
M.auto_unfold_hover = false
M.autofold_depth = 2
M.fold_markers = { "", "" }
M.theme_markers = { "🆃 ", "🅲 " }
-- TODO: symbol_blacklist currently not supported, as the bottom marker will not be shown properly.
M.symbol_blacklist = {}
M.type_symbol_blacklist = {
    "Variable",
    "Constant",
    "String",
    "Number",
    "Boolean",
    "Array",
    "Package",
}
-- M.lsp_blacklist = { "jedi_language_server", "null-ls" }
M.lsp_blacklist = { "pyright", "null-ls" }
M.skip_filetype = { "neo-tree", "NvimTree" }

-- A list of all symbols to display. Set to false to display all symbols.
-- This can be a filetype map (see :help aerial-filetype-map)
-- To see all available values, see :help SymbolKind
M.filter_kind = {}
M.symbols = {
    -- kind
    Text = { icon = "󰉿", hl = "@Method" },
    Method = { icon = "󰆧", hl = "@Method" },
    Function = { icon = "󰊕", hl = "@Function" },
    Constructor = { icon = "", hl = "@Constructor" },
    Field = { icon = "󰜢", hl = "@Field" },
    Variable = { icon = "󰀫", hl = "@Constant" },
    Class = { icon = "󰠱", hl = "@Type" },
    Interface = { icon = "", hl = "@Type" },
    Module = { icon = "", hl = "@namespace" },
    Property = { icon = "󰜢", hl = "@Method" },
    Unit = { icon = "󰑭", hl = "@Method" },
    Value = { icon = "󰎠", hl = "@Method" },
    Enum = { icon = "", hl = "@Type" },
    Keyword = { icon = "󰌋", hl = "@Type" },
    Snippet = { icon = "", hl = "@Type" },
    Color = { icon = "󰏘", hl = "@Type" },
    File = { icon = "󰈙", hl = "@text.uri" },
    Reference = { icon = "󰈇", hl = "@URI" },
    Folder = { icon = "󰉋", hl = "@URI" },
    EnumMember = { icon = "", hl = "@Field" },
    Constant = { icon = "󰏿", hl = "@Constant" },
    Struct = { icon = "󰙅", hl = "@Type" },
    Event = { icon = "", hl = "@Type" },
    Operator = { icon = "󰆕", hl = "@Operator" },
    TypeParameter = { icon = "󰊄", hl = "@Parameter" },
    -- non-kind
    Namespace = { icon = "󰌗", hl = "@namespace" },
    Package = { icon = "󰏖", hl = "@namespace" },
    String = { icon = "󰀬", hl = "@String" },
    Number = { icon = "󰎠", hl = "@Number" },
    Boolean = { icon = "", hl = "@Boolean" },
    Array = { icon = "󰅪", hl = "@Constant" },
    Object = { icon = "󰅩", hl = "@Type" },
    Key = { icon = "󰌋", hl = "@Type" },
    Null = { icon = "", hl = "@Type" },
    Component = { icon = "󰅴", hl = "@Function" },
    Fragment = { icon = "󰅴", hl = "@Constant" },
    -- ccls
    TypeAlias = { icon = "", hl = "@String" },
    Parameter = { icon = "", hl = "@Parameter" },
    StaticMethod = { icon = "󰠄", hl = "@Namespace" },
    Macro = { icon = "", hl = "@Macro" },
}

M.enable_profile = false

local function has_value(tab, val)
    for _, value in ipairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

function M.get_window_width()
    if M.width == nil or M.width < 0 then
        return 30
    end
    if M.width < 0.5 then
        return math.ceil(vim.o.columns * M.width)
    elseif M.width < 1 and M.width > 0.5 then
        vim.api.nvim_echo({
            {
                "M.width relative width can't be greater than 0.5, set to half screen",
                "None",
            },
        }, false, {})
        return 30
    end
    if M.width < vim.o.columns then
        return M.width
    end
    vim.api.nvim_echo(
        { { "invaild M.width, set to default 30", "None" } },
        false,
        {}
    )
    return 30
end

-- function M.is_symbol_blacklisted(kind)
--     if kind == nil then
--         return false
--     end
--     return has_value(M.symbol_blacklist, kind)
-- end
--
-- function M.is_type_symbol_blacklisted(kind)
--     if kind == nil then
--         return false
--     end
--     return has_value(M.type_symbol_blacklist, kind)
-- end

function M.is_symbol_blacklisted(kind, ft)
    if kind == nil then
        return false
    end
    if M.filetype_map[ft] == nil then
        return false
    end
    return has_value(M.filetype_map[ft].symbol_blacklist, kind)
end

function M.is_type_symbol_blacklisted(kind, ft)
    if kind == nil then
        return false
    end
    return has_value(M.filetype_map[ft].type_symbol_blacklist, kind)
end

function M.is_client_blacklisted_id(client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return false
    end
    return has_value(M.lsp_blacklist, client.name)
end

function M.is_client_blacklisted_name(client_name)
    return has_value(M.lsp_blacklist, client_name)
end

function M.get_theme_icon(theme)
    if theme == "type" then
        return M.theme_markers[2]
    else
        return M.theme_markers[1]
    end
end

return M
