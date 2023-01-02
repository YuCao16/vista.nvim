local utils_basic = require("vista-nvim.utils.basic")
local utils_provider = require("vista-nvim.utils.provider")
local providers = require("vista-nvim.providers.init")
local handlers = require("vista-nvim.handlers.init")
local view = require("vista-nvim.view")
local config = require("vista-nvim.config")

local a = vim.api

local M = {
    first_call = true,
}

function M.__refresh()
    if not view.is_win_open({ any_tabpage = false }) then
        return
    end

    view.View.current_ft = vim.bo.filetype
    if utils_provider.current_support[view.View.current_ft] == nil then
        -- vim.notify("nothing to update, vista remain unchange")
        return
    end

    if config.filetype_map[view.View.current_ft] == nil then
        view.View.provider = config.default_provider -- string
    else
        view.View.provider = config.filetype_map[view.View.current_ft] --string
        -- vim.notify("updating filetype_map")
        handler =
            handlers.get_handler(view.View.provider, { refresh = M.first_call })
        M.first_call = true
        if handler ~= nil then
            providers.request_symbols(handler, view.View.provider)
        end
        return
    end

    -- While setup map is not visible
    handler =
        handlers.get_handler(view.View.provider, { refresh = M.first_call })
    M.first_call = true
    if handler ~= nil then
        providers.request_symbols(handler, view.View.provider)
    end
    -- vim.notify("updating default_provider")
end

--TODO: check out why dealy < 300 cause nil response while first calling
M._refresh = utils_basic.debounce(M.__refresh, 300)

return M
