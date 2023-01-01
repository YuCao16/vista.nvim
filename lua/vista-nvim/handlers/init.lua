-- local view = require("vista-nvim.view")

local M = {}

local handlers = {
    lsp = "vista-nvim/handlers/basic",
    markdown = "vista-nvim/handlers/basic",
}

function M.get_handler(provider, opt) 
    if handlers[provider] ~= nil then
        local handler = require(handlers["lsp"])
        if opt.refresh then
            return handler.refresh_handler
        else
            return handler.handler
        end
    end
end

return M
