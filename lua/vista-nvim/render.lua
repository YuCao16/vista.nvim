local config = require("vista-nvim.config")

local M = {}

-----------
-- symbols
------------

M.kinds = {
    "File",
    "Module",
    "Namespace",
    "Package",
    "Class",
    "Method",
    "Property",
    "Field",
    "Constructor",
    "Enum",
    "Interface",
    "Function",
    "Variable",
    "Constant",
    "String",
    "Number",
    "Boolean",
    "Array",
    "Object",
    "Key",
    "Null",
    "EnumMember",
    "Struct",
    "Event",
    "Operator",
    "TypeParameter",
    "Component",
    "Fragment",
}

M.kinds_number = {
    [1] = { "File", " ", "@URI" },
    [2] = { "Module", " ", "@Namespace" },
    [3] = { "Namespace", " ", "@Namespace" },
    [4] = { "Package", " ", "@Namespace" },
    [5] = { "Class", " ", "@Class" },
    [6] = { "Method", " ", "@Method" },
    [7] = { "Property", " ", "@Method" },
    [8] = { "Field", " ", "@Field" },
    [9] = { "Constructor", " ", "@Constructor" },
    [10] = { "Enum", "了", "@Type" },
    [11] = { "Interface", " ", "@Type" },
    [12] = { "Function", " ", "@Function" },
    [13] = { "Variable", " ", "@Constant" },
    [14] = { "Constant", " ", "@Constant" },
    [15] = { "String", " ", "@String" },
    [16] = { "Number", " ", "@Number" },
    [17] = { "Boolean", " ", "@Boolean" },
    [18] = { "Array", " ", "@Constant" },
    [19] = { "Object", " ", "@Type" },
    [20] = { "Key", " ", "@Type" },
    [21] = { "Null", " ", "@Type" },
    [22] = { "EnumMember", " ", "@Field" },
    [23] = { "Struct", " ", "@Type" },
    [24] = { "Event", " ", "@Type" },
    [25] = { "Operator", " ", "@Operator" },
    [26] = { "TypeParameter", " ", "@Parameter" },
    -- ccls
    [252] = { "TypeAlias", " ", "@String" },
    [253] = { "Parameter", " ", "@Parameter" },
    [254] = { "StaticMethod", "ﴂ ", "@Namespace" },
    [255] = { "Macro", " ", "@Macro" },
}

function M.icon_from_kind(kind)
    local symbols = config.symbols

    if type(kind) == "string" then
        return symbols[kind].icon
    end

    -- If the kind is higher than the available ones then default to 'Object'
    if kind > #M.kinds then
        kind = 19
    end
    return symbols[M.kinds[kind]].icon
end

-----------
-- UI
------------
M.markers = {
    bottom = "└",
    middle = "│",
    vertical = "│",
    horizontal = " ",
}

return M
