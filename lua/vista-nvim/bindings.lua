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
    -- TODO: change this by defining by handler
    -- by move this to handler, setup while handler first called and switching provider
    view_bindings = {
        ["q"] = function()
            require("vista-nvim").close()
        end,
        ["<CR>"] = function()
            require("vista-nvim.handlers.basic").goto_location(true)
        end,
        ["p"] = function()
            require("vista-nvim.handlers.basic").goto_location(false)
        end,
        ["o"] = function()
            require("vista-nvim.handlers.basic").toggle_fold()
        end,
        ["zr"] = function()
            require("vista-nvim.handlers.basic").set_all_folded(true)
        end,
        ["zR"] = function()
            require("vista-nvim.handlers.basic").set_all_folded(false)
        end,
    },
}

-- this function is working with M.unescape_keycode to avoid lua bad argument error
-- function M.escape_keycode(key)
--     return key:gsub("<", "["):gsub(">", "]")
-- end
--
-- function M.unescape_keycode(key)
--     return key:gsub("%[", "<"):gsub("%]", ">")
-- end

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
