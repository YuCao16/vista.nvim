local api = vim.api
local utils = require("vista-nvim.utils")
local config = require("vista-nvim.config")

local M = {}

M.State = {
    -- bindings defined by the sections
    -- map(index -> key string)
    section_bindings = {},
    -- fallback bindings if none of the sections have overrided them
    view_bindings = {
        ["q"] = function()
            require("vista-nvim").close()
        end,
        ["t"] = function()
            require("vista-nvim").switch_provider("ctags")
        end,
        ["s"] = function()
            require("vista-nvim").switch_provider("lsp")
        end,
    },
}

function M.setup()
    local user_mappings = config.bindings or {}
    if config.disable_default_keybindings == 1 then
        M.State.view_bindings = user_mappings
    else
        local result =
            vim.tbl_extend("force", M.State.view_bindings, user_mappings)
        M.State.view_bindings = result
    end

    local section = utils.resolve_section(1, config.section)
    if section and section.bindings ~= nil then
        M.update_section_bindings(1, section.bindings)
    end
end

function M.update_section_bindings(index, bindings)
    for key, binding in pairs(bindings) do
        M.State.section_bindings[key] = M.State.section_bindings[key] or {}
        M.State.section_bindings[key][index] = binding
    end
end

function M.inject(bufnr)
    for key, _ in pairs(M.State.view_bindings) do
        api.nvim_buf_set_keymap(
            bufnr,
            "n",
            key,
            utils.vista_nvim_callback(key),
            { noremap = true, silent = true, nowait = true }
        )
    end

    for key, _ in pairs(M.State.section_bindings) do
        api.nvim_buf_set_keymap(
            bufnr,
            "n",
            key,
            utils.vista_nvim_callback(key),
            { noremap = true, silent = true, nowait = true }
        )
    end
end

local function execute_binding(key, binding, ...)
    if type(binding) ~= "function" then
        utils.echo_warning(
            "binding for '" .. key .. "' expected to be a function"
        )
        return
    end
    binding(...)
end

-- @return boolean
-- @return whether the binding was defined or not
local function on_keypress_section(key, section_match, bindings)
    -- no section in the cursor
    if section_match == nil then
        return false
    end

    -- local binding = bindings[section_match.section_index]
    local binding = bindings[1]

    if binding == nil then
        return false
    end

    execute_binding(
        key,
        binding,
        section_match.section_content_current_line,
        section_match.cursor_col
    )
    return true
end

local function on_keypress_view(key, binding)
    execute_binding(key, binding)
end

function M.on_keypress(key, section_index)
    local section_bindings = M.State.section_bindings[key]

    if section_bindings ~= nil then
        if on_keypress_section(key, section_index, section_bindings) then
            return
        end
    end

    local view_bindings = M.State.view_bindings[key]

    if view_bindings ~= nil then
        on_keypress_view(key, view_bindings)
    end
end

-- function M.on_keypress(key)
--     local view_bindings = M.State.view_bindings[key]
--
--     if view_bindings ~= nil then
--         on_keypress_view(key, view_bindings)
--     end
-- end

return M
