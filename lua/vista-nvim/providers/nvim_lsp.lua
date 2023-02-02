local config = require("vista-nvim.config")

local M = {}

local function getParams(bufnr)
    bufnr = bufnr or 0
    return { textDocument = vim.lsp.util.make_text_document_params() }
end

function M.hover_info(bufnr, params, on_info)
    local clients = vim.lsp.buf_get_clients(bufnr)
    local used_client

    for id, client in pairs(clients) do
        if config.is_client_blacklisted_id(id) then
            goto continue
        else
            if client.server_capabilities.hoverProvider then
                used_client = client
                break
            end
        end
        ::continue::
    end

    if not used_client then
        on_info(nil, {
            contents = {
                kind = "markdown",
                content = { "No extra information availaible!" },
            },
        })
    end

    used_client.request("textDocument/hover", params, on_info, bufnr)
end

-- probably change this
function M.should_use_provider(bufnr)
    local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    local ret = false

    for id, client in pairs(clients) do
        if config.is_client_blacklisted_name(client.name) then
            goto continue
        else
            if client.server_capabilities.documentSymbolProvider then
                ret = true
                break
            end
        end
        ::continue::
    end

    return ret
end

---@param on_symbols function
function M.request_symbols(on_symbols, bufnr)
    bufnr = bufnr or 0
    vim.lsp.buf_request_all(
        bufnr,
        "textDocument/documentSymbol",
        getParams(bufnr),
        on_symbols
    )
end

return M
