local parser = require("vista-nvim.parsers.nvim_lsp")
local config = require("vista-nvim.config")
local highlight = require("vista-nvim.highlight")
local view = require("vista-nvim.view")

local M = {}

M.current_filepath = nil
M.current_width = config.width
M.lsp_bufnr = nil

function M.setup()
    M.current_theme = config.theme
    M.structure_theme = config.theme
end

local function is_buffer_vista(bufnr)
    local isValid = vim.api.nvim_buf_is_valid(bufnr)
    -- local name = vim.api.nvim_buf_get_name(bufnr)
    local name = vim.fn.bufname(bufnr)
    local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
    return string.match(name, ".*VistaNvim_.*") ~= nil
        and ft == "VistaNvim"
        and isValid
end

local function max_title_width()
    if M.current_filepath == nil then
        return config.width
    end
    local max_width = string.len(M.current_filepath) + 6
    if M.current_width > max_width then
        return max_width - 1
    end
    return M.current_width
end

function M.add_highlighs_title(bufnr, theme)
    local hlns = vim.api.nvim_create_namespace("vista-icon-highlight")
    vim.api.nvim_buf_clear_namespace(bufnr, hlns, 0, -1)
    vim.api.nvim_buf_add_highlight(bufnr, hlns, "VistaOutlineTitle", 0, 3, -2)
    if theme == "tree" then
        vim.api.nvim_buf_add_highlight(
            bufnr,
            hlns,
            "@string",
            0,
            max_title_width(),
            -1
        )
    elseif theme == "type" then
        vim.api.nvim_buf_add_highlight(
            bufnr,
            hlns,
            "@type",
            0,
            max_title_width(),
            -1
        )
    end
end

function M.add_highlights(bufnr, hl_info, nodes)
    local ns_id = vim.api.nvim_create_namespace("vista-all-highlight")
    vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
    if config.show_title then
        M.add_highlighs_title(bufnr, M.structure_theme)
    end
    if M.structure_theme == "type" then
        for k, v in pairs(hl_info) do
            if not vim.tbl_isempty(v) then
                for group, scope in pairs(v) do
                    vim.api.nvim_buf_add_highlight(
                        bufnr,
                        ns_id,
                        group,
                        k,
                        scope[1],
                        scope[2]
                    )
                end
            end
        end
        return
    end
    for _, line_hl in ipairs(hl_info) do
        local line, hl_start, hl_end, hl_type = unpack(line_hl)
        vim.api.nvim_buf_add_highlight(
            bufnr,
            ns_id,
            hl_type,
            line - 1 + view.View.title_line,
            hl_start,
            hl_end
        )
    end

    M.add_hover_highlights(bufnr, nodes)
end

M.add_hover_highlights = function(bufnr, nodes)
    if not config.highlight_hovered_item then
        return
    end

    -- clear old highlight
    highlight.clear_hover_highlight(bufnr)
    for _, node in ipairs(nodes) do
        if not node.hovered then
            goto continue
        end

        local marker_fac = (config.fold_markers and 1) or 0
        if node.prefix_length then
            highlight.add_hover_highlight(
                bufnr,
                node.line_in_outline - 1 + view.View.title_line,
                node.prefix_length
            )
        end
        ::continue::
    end
end

-- TODO: more readable
function M.clean_path(filepath, width)
    if filepath == nil then
        return "VistaNvim"
    end
    local internal_width = width or config.width
    filepath = filepath
    if filepath:len() > internal_width - 3 then
        filepath = "..." .. filepath:sub(-internal_width + 9, -1)
    end
    return filepath
end

function M.write_middle()
    local ret = {}
    local win_height_half = 10
    if type(view.View.win_height) == "number" then
        win_height_half = math.floor(view.View.win_height / 2) - 3
    end
    for i = 1, win_height_half do
        table.insert(ret, "")
    end
    table.insert(ret, "          No symbols")
    table.insert(ret, "      lsp (not supported) ")
    table.insert(ret, "     [No LSP client found]")
    return ret
end

local hlld = vim.api.nvim_create_namespace("vista-nvim-loading")
function M.write_title_loading(bufnr)
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
        config.fold_markers[2] .. " " .. M.clean_path(
            view.View.current_filepath
        ),
    })
    vim.api.nvim_buf_set_lines(bufnr, 1, -1, false, M.write_middle())
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    vim.api.nvim_buf_add_highlight(bufnr, hlld, "@method", 0, 3, -1)
end

function M._should_update_title(bufnr)
    if not is_buffer_vista(bufnr) then
        return false
    end
    if not config.show_title then
        return false
    end
    -- if current window is VistaNvim window
    if view.View.bufnr == vim.api.nvim_get_current_buf() then
        return false
    end
    -- if current filepath change
    if M.current_filepath == view.View.current_filepath then
        return false
    end
    if string.match(view.View.current_filepath, ".*VistaNvim_.*") then
        return false
    end
    if string.match(view.View.current_filepath, " ") then -- for example: NeoTree
        if vim.fn.expand("%:e") == "" then
            return false
        end
    end
	if #vim.lsp.get_active_clients({ bufnr = vim.api.nvim_get_current_buf() }) == 0 then
        return false
    end
    return true
end

function M.write_title(bufnr, switch, width)
    -- TODO: arrange to one statement
    if not switch and not width then
        if not M._should_update_title(bufnr) then
            return
        end
    elseif switch then
        local theme_marker = config.get_theme_icon(M.structure_theme)
        vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
        local current_title = vim.api
            .nvim_buf_get_lines(view.View.bufnr, 0, 1, false)[1]
            :sub(1, -6) .. theme_marker

        vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
            current_title,
        })
        vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
        vim.cmd("normal! k")
        return
    end
    local theme_marker = config.get_theme_icon(M.structure_theme)
    local current_filepath = vim.api.nvim_buf_get_name(0)
    if current_filepath == "" then
        return
    end
    M.current_width = view.get_width(vim.api.nvim_get_current_tabpage())
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, {
        config.fold_markers[2]
            .. " "
            .. M.clean_path(
                -- view.View.current_filepath,
                current_filepath,
                M.current_width
            )
            .. " "
            .. theme_marker,
    })
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    -- M.current_filepath = view.View.current_filepath
    M.current_filepath = current_filepath
end

function M.write_title_width(bufnr)
    local theme_marker = config.get_theme_icon(M.structure_theme)
    M.current_width = view.get_width(vim.api.nvim_get_current_tabpage())
    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    vim.api.nvim_buf_set_lines(bufnr, 0, 1, false, {
        config.fold_markers[2] .. " " .. M.clean_path(
            M.current_filepath,
            M.current_width
        ) .. " " .. theme_marker,
    })
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
    M.add_highlighs_title(bufnr, M.current_theme)
end

function M.write_vista(bufnr, lines)
    if not is_buffer_vista(bufnr) then
        return
    end

    vim.api.nvim_buf_set_option(bufnr, "modifiable", true)
    if config.show_title then
        vim.api.nvim_buf_set_lines(
            bufnr,
            view.View.title_line,
            -1,
            false,
            lines
        )
    else
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    end
    vim.api.nvim_buf_set_option(bufnr, "modifiable", false)
end

-- runs the whole writing routine where the text is cleared, new data is parsed
-- and then written
M.test_writer = {}
function M.parse_and_write(bufnr, outline_items, theme)
    M.test_writer = outline_items
    local lines, hl_info = parser.get_lines(outline_items, M.structure_theme)
    if lines[1] == nil then
        return
    end
    if M.current_theme ~= M.structure_theme then
        M.write_title(bufnr, true)
        M.current_theme = M.structure_theme
    else
        M.write_title(bufnr, false)
    end
    M.write_vista(bufnr, lines)
    M.add_highlights(bufnr, hl_info, outline_items)
end

return M
