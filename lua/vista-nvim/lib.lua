local luv = vim.loop
local api = vim.api

local view = require("vista-nvim.view")
local config = require("vista-nvim.config")
local bindings = require("vista-nvim.bindings")
local utils = require("vista-nvim.utils")
local updater = require("vista-nvim.updater")
local renderer = require("vista-nvim.renderer")
-- local uctags = require("vista-nvim.types.uctags")

local first_init_done = false

local M = {}

M.State = { section_line_indexes = {} }
M.seted_update_autocmd = false

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
    -- if ctags.language_opt[vim.bo.filetype] == nil then
    --     return
    -- end
    if view.is_win_open({ any_tabpage = true }) then
        updater.update()
    end

    updater.draw()
    _redraw()
end

function M.setup_update_autocmd()
    local vista_update_autocmd =
        vim.api.nvim_create_augroup("vista_update_autocmd", { clear = true })
    vim.api.nvim_create_autocmd({
        "BufEnter",
        "TabEnter",
        "BufWritePost",
        "InsertLeave",
        "VimResume",
        "FocusGained",
    }, {
        pattern = "*",
        callback = require("vista-nvim.lib").update,
        group = vista_update_autocmd,
    })
end

function M.open(opts)
    if not M.seted_update_autocmd then
        M.setup_update_autocmd()
        M.seted_update_autocmd = true
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

local function get_start_line(content_only, indexes)
    if content_only then
        return indexes.content_start
    end

    return indexes.section_start
end

local function get_end_line(content_only, indexes)
    if content_only then
        return indexes.content_start + indexes.content_length
    end

    return indexes.section_start + indexes.section_length - 1
end

-- @param opts: table
-- @param opts.content_only: boolean = whether the it should only check if the cursor is hovering the contents of the section
-- @return table{section_index = number, section_content_current_line = number, cursor_col = number, cursor_line = number)
function M.find_section_at_cursor(opts, provider)
    opts = opts or { content_only = true }

    local cursor = opts.cursor or api.nvim_win_get_cursor(0)
    local cursor_line = cursor[1]
    local cursor_col = cursor[2]
    local section_line_index = M.State.section_line_indexes[1]

    local start_line = get_start_line(opts.content_only, section_line_index)
    local end_line = get_end_line(opts.content_only, section_line_index)

    if provider ~= nil then
        return {
            section_index = 1,
            section_content_current_line = cursor_line
                - section_line_index.content_start,
            cursor_line = cursor_line,
            cursor_col = cursor_col,
            line_index = section_line_index,
        }
    end

    return nil
end

function M.on_keypress(key)
    local section_match = M.find_section_at_cursor({}, config.section)
    bindings.on_keypress(utils.unescape_keycode(key), section_match)
    M.update()
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
