local api = vim.api

local lib = require("vista-nvim.lib")
local view = require("vista-nvim.view")
local autocmd = require("vista-nvim.autocmd")
local bindings = require("vista-nvim.bindings")
local colors = require("vista-nvim.colors")
local profile = require("vista-nvim.profile")
local render = require("vista-nvim.render")
local writer = require("vista-nvim.writer")
local utils_basic = require("vista-nvim.utils.basic")

local M = { setup_called = false, _internal_setup_called = false }

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

    -- TODO: move to open command to achieve lazy load
    -- check if vim enter has already been called, if so, do initialize
    -- docs for `vim.v.vim_did_enter`: https://neovim.io/doc/user/autocmd.html#VimEnter
    -- if vim.v.vim_did_enter == 1 then
    --     M._internal_setup()
    -- end
end

function M._internal_setup()
    colors.setup()
    view.setup()
    bindings.setup()
    autocmd.setup()

    lib.setup()

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
    vim.api.nvim_echo({ { "vista open", "None" } }, false, {})
end

function M.close()
    view.close()
    vim.api.nvim_echo({ { "vista close", "None" } }, false, {})
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

return M
