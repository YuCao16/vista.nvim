local utils_basic = require("vista-nvim.utils.basic")
local config = require("vista-nvim.config")
local view = require("vista-nvim.view")

local a = vim.api

local M = {}

--TODO: Check if key binding works for multiple tabpages

M.State = {
    -- bindings defined by the sections
    -- map(index -> key string)
    -- TODO: complete section bindings.
    section_bindings = {},
    -- fallback bindings if none of the sections have overrided them
    -- TODO: create bindings map table for user: eg. {folding = ["p"]}
    -- this require a general name of for example `goto_location` for all
    -- handlers with this function.
    -- this should be set in handlers.init.lua
    view_bindings = {
        ["q"] = function()
            require("vista-nvim").close()
        end,
    },
}

-- convert a function to callback string
function M.execute_binding(key)
    key = utils_basic.unescape_keycode(key)
    M.State.view_bindings[key]()
end

function M.setup()
    local user_mappings = config.bindings or {}
    if config.disable_default_keybindings == 1 then
        M.State.view_bindings = user_mappings
    else
        local result =
            vim.tbl_extend("force", M.State.view_bindings, user_mappings)
        M.State.view_bindings = result
    end
    for key, _ in pairs(M.State.view_bindings) do
        a.nvim_buf_set_keymap(
            view.View.bufnr,
            "n",
            key,
            string.format(
                ":lua require('vista-nvim.bindings').execute_binding('%s')<CR>",
                utils_basic.escape_keycode(key)
            ),
            { noremap = true, silent = true, nowait = true }
        )
    end
end

return M
