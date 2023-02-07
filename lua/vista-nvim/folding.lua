local config = require("vista-nvim.config")

local M = {}

M.is_foldable = function(node, theme)
    if node == nil then
        return false
    end
    if theme == "type" then
        if node.expand then
            return true
        else
            return false
        end
    end
    return node.children and #node.children > 0
end

local get_default_folded = function(depth)
    local fold_past = config.autofold_depth
    if not fold_past then
        return false
    else
        return depth >= fold_past
    end
end

local rules = { python = { "Function", "Variable" } }

local default_folded_type = function(filetype, kind)
    if rules[filetype] == nil then
        return true
    end
    for _, i in ipairs(rules) do
        if kind == i then
            return true
        end
    end
    return false
end

M.is_folded = function(node)
    if node.folded ~= nil then
        return node.folded
    elseif node.hovered and config.auto_unfold_hover then
        return false
    else
        return get_default_folded(node.depth)
    end
end

return M
