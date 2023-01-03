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
M.autofold_depth = 2
M.fold_markers = { "", "" }
M.symbol_blacklist = {}
-- M.lsp_blacklist = { "pyright" }
M.lsp_blacklist = { "jedi_language_server" }

-- A list of all symbols to display. Set to false to display all symbols.
-- This can be a filetype map (see :help aerial-filetype-map)
-- To see all available values, see :help SymbolKind
M.filter_kind = {}
M.symbols = {
    File = { icon = "", hl = "@URI" },
    Module = { icon = "", hl = "@Namespace" },
    Namespace = { icon = "", hl = "@Namespace" },
    Package = { icon = "", hl = "@Namespace" },
    Class = { icon = "𝓒", hl = "@Type" },
    Method = { icon = "ƒ", hl = "@Method" },
    Property = { icon = "", hl = "@Method" },
    Field = { icon = "", hl = "@Field" },
    Constructor = { icon = "", hl = "@Constructor" },
    Enum = { icon = "ℰ", hl = "@Type" },
    Interface = { icon = "ﰮ", hl = "@Type" },
    Function = { icon = "", hl = "@Function" },
    Variable = { icon = "", hl = "@Constant" },
    Constant = { icon = "", hl = "@Constant" },
    String = { icon = "𝓐", hl = "@String" },
    Number = { icon = "#", hl = "@Number" },
    Boolean = { icon = "⊨", hl = "@Boolean" },
    Array = { icon = "", hl = "@Constant" },
    Object = { icon = "⦿", hl = "@Type" },
    Key = { icon = "🔐", hl = "@Type" },
    Null = { icon = "NULL", hl = "@Type" },
    EnumMember = { icon = "", hl = "@Field" },
    Struct = { icon = "𝓢", hl = "@Type" },
    Event = { icon = "🗲", hl = "@Type" },
    Operator = { icon = "+", hl = "@Operator" },
    TypeParameter = { icon = "𝙏", hl = "@Parameter" },
    Component = { icon = "", hl = "@Function" },
    Fragment = { icon = "", hl = "@Constant" },
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
