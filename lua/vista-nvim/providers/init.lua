local writer = require("vista-nvim.writer")
local view = require("vista-nvim.view")
local M = {}

local providers = {
    jsx = "vista-nvim/providers/jsx",
    lsp = "vista-nvim/providers/nvim_lsp",
    coc = "vista-nvim/providers/coc",
    markdown = "vista-nvim/providers/markdown",
}

_G._symbols_outline_current_provider = nil

function M.has_provider(_provider)
    local ret = false
    if _provider ~= nil then
        local provider = require(providers[_provider])
        if provider.should_use_provider(0) then
            return true
        end
    end
    for _, value in ipairs(providers) do
        local provider = require(value)
        if provider.should_use_provider(0) then
            ret = true
            break
        end
    end
    return ret
end

---@param on_symbols function
function M.request_symbols(on_symbols, _provider, bufnr)
    bufnr = bufnr or 0
    if _provider ~= nil then
        local provider = require(providers[_provider])
        if provider.should_use_provider(bufnr) then
            _G._symbols_outline_current_provider = provider
            provider.request_symbols(on_symbols, bufnr)
            return
        else
            writer.write_title_loading(view.View.bufnr)
        end
    end
    for _, value in ipairs(providers) do
        local provider = require(value)
        if provider.should_use_provider(bufnr) then
            _G._symbols_outline_current_provider = provider
            provider.request_symbols(on_symbols)
            return
            -- break
        end
    end
end

return M
