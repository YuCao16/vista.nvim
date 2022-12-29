local config = require("vista-nvim.config")

return {
    title = "Symbols",
    icon = config["symbols"].icon,
    highlights = {},
    bindings = {},
    draw = function()
        local lines = {}
        local hl = {}
        if lines == nil or #lines == 0 then
            return { lines = { "ctags" }, hl = {} }
        else
            return { lines = lines, hl = hl }
        end
    end,
}
