local M = {}

M.highlight_hovered_item = false
M.width = 30
M.side = "right"
M.bindings = nil
M.disable_default_keybindings = false
M.show_guide = true
M.border = "rounded"
M.auto_close = false
M.auto_preview = false
M.disable_max_lines = 10000
M.disable_max_sizes = 2000000 -- Default 2MB
M.default_provider = "lsp"
M.filetype_map = {
    python = "lsp",
    rust = "lsp",
    lua = "lsp",
    cpp = "lsp",
    c = "lsp",
    ruby = "lsp",
    markdown = "markdown",
}
M.show_symbol_details = true
M.auto_unfold_hover = false
M.autofold_depth = nil
M.fold_markers = { "", "" }
M.symbol_blacklist = {}
M.lsp_blacklist = { "pyright" }
-- A list of all symbols to display. Set to false to display all symbols.
-- This can be a filetype map (see :help aerial-filetype-map)
-- To see all available values, see :help SymbolKind
M.filter_kind = {}
M.symbols = {
    File = { icon = "", hl = "TSURI" },
    Module = { icon = "", hl = "TSNamespace" },
    Namespace = { icon = "", hl = "TSNamespace" },
    Package = { icon = "", hl = "TSNamespace" },
    Class = { icon = "𝓒", hl = "TSType" },
    Method = { icon = "ƒ", hl = "TSMethod" },
    Property = { icon = "", hl = "TSMethod" },
    Field = { icon = "", hl = "TSField" },
    Constructor = { icon = "", hl = "TSConstructor" },
    Enum = { icon = "ℰ", hl = "TSType" },
    Interface = { icon = "ﰮ", hl = "TSType" },
    Function = { icon = "", hl = "TSFunction" },
    Variable = { icon = "", hl = "TSConstant" },
    Constant = { icon = "", hl = "TSConstant" },
    String = { icon = "𝓐", hl = "TSString" },
    Number = { icon = "#", hl = "TSNumber" },
    Boolean = { icon = "⊨", hl = "TSBoolean" },
    Array = { icon = "", hl = "TSConstant" },
    Object = { icon = "⦿", hl = "TSType" },
    Key = { icon = "🔐", hl = "TSType" },
    Null = { icon = "NULL", hl = "TSType" },
    EnumMember = { icon = "", hl = "TSField" },
    Struct = { icon = "𝓢", hl = "TSType" },
    Event = { icon = "🗲", hl = "TSType" },
    Operator = { icon = "+", hl = "TSOperator" },
    TypeParameter = { icon = "𝙏", hl = "TSParameter" },
    Component = { icon = "", hl = "TSFunction" },
    Fragment = { icon = "", hl = "TSConstant" },
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

function M.is_symbol_blacklisted(kind)
    if kind == nil then
        return false
    end
    return has_value(M.symbol_blacklist, kind)
end

function M.is_client_blacklisted(client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return false
    end
    return has_value(M.lsp_blacklist, client.name)
end
return M
