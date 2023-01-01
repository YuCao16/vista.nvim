local M = {}

local providers = {
    -- "vista-nvim/providers/jsx",
    lsp = "vista-nvim/providers/nvim_lsp",
    -- "vista-nvim/providers/coc",
    -- "vista-nvim/providers/markdown",
}

_G._symbols_outline_current_provider = nil

function M.has_provider(bufnr)
    local ret = false
    for _, value in ipairs(providers) do
        local provider = require(value)
        if provider.should_use_provider(bufnr) then
            ret = true
            break
        end
    end
    return ret
end

---@param on_symbols function
function M.request_symbols(on_symbols, _provider)
    if _provider ~= nil then
        provider = require(providers[_provider])
        if provider.should_use_provider(0) then
            _G._symbols_outline_current_provider = provider
            provider.request_symbols(on_symbols)
            return
        end
    end
    for _, value in ipairs(providers) do
        local provider = require(value)
        if provider.should_use_provider(0) then
            _G._symbols_outline_current_provider = provider
            provider.request_symbols(on_symbols)
            break
        end
    end
end

return M
