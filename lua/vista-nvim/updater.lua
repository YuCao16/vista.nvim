local utils_basic = require("vista-nvim.utils.basic")
local utils_provider = require("vista-nvim.utils.provider")
local providers = require("vista-nvim.providers.init")
local handlers = require("vista-nvim.handlers.init")
local view = require("vista-nvim.view")
local config = require("vista-nvim.config")
local writer = require("vista-nvim.writer")

local a = vim.api

local M = {
    first_call = {
        lsp = true,
        markdown = true,
    },
}

function M.__refresh()
    if not view.is_win_open({ any_tabpage = false }) then
        return
    end

    view.View.current_ft = vim.bo.filetype
    view.View.current_filepath = vim.fn.expand("%:p")
    if utils_provider.current_support[view.View.current_ft] == nil then
        return
    end

    if config.filetype_map[view.View.current_ft] == nil then
        view.View.provider = config.default_provider -- string
    elseif config.filetype_map[view.View.current_ft].provider == nil then
        view.View.provider = config.default_provider -- string
    else
        view.View.provider = config.filetype_map[view.View.current_ft].provider --string
        handler = handlers.get_handler(
            view.View.provider,
            { refresh = not M.first_call[view.View.provider] }
        )
        M.first_call[view.View.provider] = false
        if handler ~= nil then
            providers.request_symbols(handler, view.View.provider)
        end
        return
    end

    -- While setup map is not visible
    handler = handlers.get_handler(
        view.View.provider,
        { refresh = not M.first_call[view.View.provider] }
    )
    M.first_call[view.View.provider] = false
    if handler ~= nil then
        providers.request_symbols(handler, view.View.provider)
    end
    -- vim.notify("updating default_provider")
end

function M.__refresh_title()
    if view.get_width(vim.api.nvim_get_current_tabpage()) == config.width then
        return
    else
        writer.write_title_width(view.View.bufnr)
    end
end

--TODO: check out why dealy < 300 cause nil response while first calling
M._refresh = utils_basic.debounce(M.__refresh, 300)
M._refresh_title = utils_basic.debounce(M.__refresh_title, 300)

return M
