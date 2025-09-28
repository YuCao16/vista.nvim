local config = require("vista-nvim.config")

local M = {}

local function getParams(bufnr)
    bufnr = bufnr or 0
    return { textDocument = vim.lsp.util.make_text_document_params() }
end

function M.hover_info(bufnr, params, on_info)
    -- Validate input parameters
    if not bufnr or not params or not on_info then
        if on_info then
            on_info(nil, {
                contents = {
                    kind = "markdown",
                    content = { "Invalid parameters provided!" },
                },
            })
        end
        return
    end

    local clients = vim.lsp.buf_get_clients(bufnr)
    if not clients or vim.tbl_isempty(clients) then
        on_info(nil, {
            contents = {
                kind = "markdown",
                content = { "No LSP clients available!" },
            },
        })
        return
    end

    local used_client

    for id, client in pairs(clients) do
        if config.is_client_blacklisted_id(id) then
            goto continue
        else
            if client and client.server_capabilities and client.server_capabilities.hoverProvider then
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
                content = { "No extra information available!" },
            },
        })
        return
    end

    -- Wrap the request in pcall for error handling
    local success, err = pcall(function()
        used_client.request("textDocument/hover", params, function(err, result)
            if err then
                on_info(err, {
                    contents = {
                        kind = "markdown",
                        content = { "Error retrieving hover information: " .. tostring(err) },
                    },
                })
            else
                on_info(err, result)
            end
        end, bufnr)
    end)

    if not success then
        on_info(err, {
            contents = {
                kind = "markdown",
                content = { "Failed to request hover information: " .. tostring(err) },
            },
        })
    end
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
