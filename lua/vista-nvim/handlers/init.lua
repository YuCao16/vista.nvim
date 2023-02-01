-- local view = require("vista-nvim.view")

-- TODO: make the result of parser of ctags the same as lsp, so that handler
-- and its corresponding functions is shareable.

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

function M.update(provider)
    if handlers[provider] ~= nil then
        local handler = require(handlers[provider])
        handler._update_lines(true)
    end
end

return M
