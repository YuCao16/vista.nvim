local M = {}

M.disable_default_keybindings = 0
M.bindings = nil
M.side = "right"
M.initial_width = 30
M.hide_statusline = false
M.update_interval = 1000
M.enable_profile = false
M.section_title_separator = { "" }
M.lsp_blacklist = {}
M.symbol_blacklist = {}
M.autofold_depth = nil
M.auto_unfold_hover = true
M.fold_markers = { "", "" }
M.show_guides = true
M.sections = { "symbols" }
M.section = "lsp"
M.symbols = { icon = "ƒ" }
M.lsp = { icon = "ƒ" }
M.datetime = {
    icon = "",
    format = "%a %b %d, %H:%M",
    clocks = { { name = "local" } },
}

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
    return has_value(M.options.symbol_blacklist, kind)
end

function M.is_client_blacklisted(client_id)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
        return false
    end
    return has_value(M.lsp_blacklist, client.name)
end

return M
