local luv = vim.loop
local api = vim.api

local view = require("vista-nvim.view")
local config = require("vista-nvim.config")
local bindings = require("vista-nvim.bindings")
local utils = require("vista-nvim.utils")
local updater = require("vista-nvim.updater")
local renderer = require("vista-nvim.renderer")

local first_init_done = false

local M = {}

M.State = { section_line_indexes = {} }
M.setup_update_autocmd = false

local function _redraw()
    if vim.v.exiting ~= vim.NIL then
        return
    end

    M.State.section_line_indexes = renderer.draw(updater.sections_data)
end

function M.setup()
    _redraw()
end

function M.update()
    -- this function will update the vista content
    if view.is_win_open({ any_tabpage = true }) then
        updater.update()
    end

    updater.draw()
    _redraw()
    -- vim.notify("updated")
end

function M.open(opts)
    if not M.setup_update_autocmd then
        vim.api.nvim_exec(
            [[
            echo 1
augroup SidebarNvimUpdate
    au!
    au BufWritePost * lua require'vista-nvim.lib'.update()
    au BufEnter * lua require'vista-nvim.lib'.update()
    au TabEnter * lua require'vista-nvim.lib'.update()
    au VimResume * lua require'vista-nvim.lib'.update()
    au FocusGained * lua require'vista-nvim.lib'.update()
    augroup END
    ]],
            false
        )
        M.setup_update_autocmd = true
    end
    view.open(opts or { focus = false })
    M.update()
end

function M.close()
    if view.is_win_open() then
        view.close()
    end
end

function M.toggle(opts)
    if view.is_win_open() then
        M.close()
        return
    end

    M.open(opts)
end

-- Resize the vista to the requested size
-- @param size number
function M.resize(size)
    view.View.width = size
    view.resize()
end

-- @param opts table
-- @param |- opts.any_tabpage boolean if true check if is open in any tabpage, if false check in current tab
function M.is_open(opts)
    return view.is_win_open(opts)
end
--
-- Focus or open the vista
-- @param opts table
-- @param opts.section_index number
-- @param opts.cursor_at_content boolean
function M.focus(opts)
    if view.is_win_open() then
        local winnr = view.get_winnr()
        view.focus(winnr)
    else
        M.open({ focus = true })
    end

    if opts and opts.section_index then
        local content_only = true

        if opts.cursor_at_content == false then
            content_only = false
        end

        local cursor = M.find_cursor_at_section_index(
            opts.section_index,
            { content_only = content_only }
        )

        if cursor then
            api.nvim_win_set_cursor(0, cursor)
        end
    end
end

--- Returns the window width for vista-nvim within the tabpage specified
---@param tabpage number: (optional) the number of the chosen tabpage. Defaults to current tabpage.
---@return number
function M.get_width(tabpage)
    return view.get_width(tabpage)
end

function M.destroy()
    view.close()
    view._wipe_rogue_buffer()
end

function M.on_keypress(key)
    bindings.on_keypress(utils.unescape_keycode(key))
    M.update()
end

function M.on_cursor_move(direction)
    -- this function will update something
end

function M.on_tab_change()
    vim.schedule(function()
        if
            not view.is_win_open() and view.is_win_open({ any_tabpage = true })
        then
            view.open({ focus = false })
        end
    end)
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
    M.destroy()
end

return M
