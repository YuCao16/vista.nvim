local M = {}

M.State = {
    -- bindings defined by the sections
    -- map(index -> key string)
    section_bindings = {},
    -- fallback bindings if none of the sections have overrided them
    view_bindings = {
        ["q"] = function()
            require("vista-nvim").close()
        end,
    },
}

function M.setup() end

return M
