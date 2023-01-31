local api = vim.api

local view = require("vista-nvim.view")
local autocmd = require("vista-nvim.autocmd")
local bindings = require("vista-nvim.bindings")
local profile = require("vista-nvim.profile")
local render = require("vista-nvim.render")
local writer = require("vista-nvim.writer")
local utils_basic = require("vista-nvim.utils.basic")
local highlight = require("vista-nvim.highlight")
-- local lib = require("vista-nvim.lib")
-- local colors = require("vista-nvim.colors")

local M = { setup_called = false, _internal_setup_called = false }
-- TODO: clear cache and memory mechanic
-- data
M.data = {
    outline_items = {},
    flattened_outline_items = {},
    code_win = 0,
    current_bufnr = nil,
}

local deprecated_config_map = {}
local function check_deprecated_field(key)
    if not vim.tbl_contains(vim.tbl_keys(deprecated_config_map), key) then
        return
    end

    local new_key = deprecated_config_map[key]
    utils.echo_warning(
        "config '"
            .. key
            .. "' is deprecated. Please use '"
            .. new_key
            .. "' instead"
    )
end

function M.setup(opts)
    opts = opts or {}

    -- this keys should not be merged by tbl_deep_merge, they should be overriden completely
    local full_override_keys = {}

    for key, value in pairs(opts) do
        check_deprecated_field(key)

        if
            type(value) ~= "table"
            or vim.tbl_contains(full_override_keys, key)
        then
            config[key] = value
        else
            if type(config[key]) == "table" then
                config[key] = vim.tbl_deep_extend("force", config[key], value)
            else
                config[key] = value
            end
        end
    end

    M.setup_called = true
end

function M._internal_setup()
    highlight.setup()
    view.setup()
    bindings.setup()
    autocmd.setup()

    -- lib.setup()
    -- colors.setup()

    if M.open_on_start then
        M._internal_open()
    end
    -- vim.notify("lazy setup done")
end

function M.open()
    if not M._internal_setup_called and vim.v.vim_did_enter == 1 then
        M._internal_setup()
        M._internal_setup_called = true
    end
    view.open()
    -- vim.api.nvim_echo({ { "vista open", "None" } }, false, {})
end

function M.close()
    view.close()
end

function M.destroy()
    view.destroy()
end

function M.toggle()
    if not M._internal_setup_called and vim.v.vim_did_enter == 1 then
        M._internal_setup()
        M._internal_setup_called = true
    end
    if view.is_win_open({ any_tabpage = false }) then
        view.close()
    else
        view.open()
    end
    vim.api.nvim_echo({ { "vista toggle", "None" } }, false, {})
end

function M.on_win_leave()
    vim.defer_fn(function()
        if not view.is_win_open() then
            return
        end

        local windows = api.nvim_list_wins()
        local curtab = api.nvim_get_current_tabpage()
        local wins_in_tabpage = vim.tbl_filter(function(w)
            return api.nvim_win_get_tabpage(w) == curtab
        end, windows)
        if #windows == 1 then
            M.close()
        elseif #wins_in_tabpage == 1 then
            api.nvim_command(":tabclose")
        end
    end, 50)
end

function M.on_vim_leave()
    view.destroy()
end

return M
