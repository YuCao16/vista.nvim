local M = {}

-- link group1 to group2
local function link(group1, group2)
    vim.api.nvim_set_hl(0, group1, { link = group2, default = true })
end

local function create(group_name, bg, fg, ctermfg, ctermbg)
    -- if create highlight_group with table input
    if type(bg) == "table" then
        vim.api.nvim_set_hl(0, group_name, bg)
        return
    end
    vim.api.nvim_set_hl(0, group_name, {
        fg = fg,
        bg = bg,
        ctermfg = ctermfg,
        ctermbg = ctermbg,
    })
end

-- for highlight group with gui=bold
function M.get_highlight_bg_fg(highlight_group)
    highlight_content = vim.api.nvim_get_hl_by_name(highlight_group, true)
    return {
        bg = highlight_content.background,
        fg = highlight_content.foreground,
    }
end

M.hovered_hl_ns = vim.api.nvim_create_namespace("hovered_item")

function M.clear_hover_highlight(bufnr)
    vim.api.nvim_buf_clear_namespace(bufnr, M.hovered_hl_ns, 0, -1)
end

function M.add_hover_highlight(bufnr, line, col_start)
    vim.api.nvim_buf_add_highlight(
        bufnr,
        M.hovered_hl_ns,
        "VistaFocusedSymbol",
        line,
        col_start,
        -1
    )
end

function M.setup()
    -- Setup the FocusedSymbol highlight group if it hasn't been done already by
    -- a theme or manually set
    if vim.fn.hlexists("FocusedSymbol") == 0 then
        local cline_hl = vim.api.nvim_get_hl_by_name("CursorLine", true)
        local string_hl = vim.api.nvim_get_hl_by_name("String", true)

        vim.api.nvim_set_hl(
            0,
            "FocusedSymbol",
            { bg = cline_hl.background, fg = string_hl.foreground }
        )
    end

    -- Create some highlight
    create("VistaConnector", nil, "#a0a8b7", nil, nil)
    create("VistaFocusedSymbol", M.get_highlight_bg_fg("FocusedSymbol"))
    link("VistaFlashLine", "IncSearch")

    -- Some colorschemes do some funky things with the comment highlight, most
    -- notably making them italic, which messes up the outline connector. Fix
    -- this by copying the foreground color from the comment hl into a new
    -- highlight.
    local comment_fg_gui =
        vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Comment")), "fg", "gui")

    if vim.fn.hlexists("VistaConnector") == 0 then
        vim.cmd(string.format("hi VistaConnector guifg=%s", comment_fg_gui))
    end
end

return M
