local config = require("vista-nvim.config")
local M = {}

local providers = {
    lsp = "vista-nvim/providers/nvim-lsp",
    markdown = "vista-nvim/providers/markdown",
}

_G._vista_nvim_current_provider = nil

function M.has_provider()
    local ret = false
    if providers[config.section] ~= nil then
        local provider = require(providers[config.section])
        if provider.should_use_provider(0) then
            ret = true
        end
    else
        for _, value in ipairs(providers) do
            local provider = require(value)
            if provider.should_use_provider(0) then
                ret = true
                break
            end
        end
    end
    return ret
end

---@param on_symbols function
function M.request_symbols(on_symbols)
    if providers[config.section] ~= nil then
        local provider = require(providers[config.section])
        if provider.should_use_provider(0) then
            _G._vista_nvim_current_provider = provider
            provider.request_symbols(on_symbols)
        end
    else
        for _, value in ipairs(providers) do
            local provider = require(value)
            if provider.should_use_provider(0) then
                _G._vista_nvim_current_provider = provider
                provider.request_symbols(on_symbols)
                break
            end
        end
    end
end

return M
