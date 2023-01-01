local M = {}

M.highlight_hovered_item = false
M.width = 30
M.side = "right"
M.bindings = nil
M.disable_default_keybindings = false
M.show_guide = true
M.border = "rounded"
M.auto_close = false
M.auto_preview = false
M.fold_markers = { "", "" }
M.auto_unfold_hover = false
M.disable_max_lines = 10000
M.disable_max_sizes = 2000000 -- Default 2MB
M.default_provider = "lsp"
M.filetype_map = {
    python = "lsp",
    rust = "lsp",
    lua = "lsp",
    cpp = "lsp",
    c = "lsp",
    ruby = "lsp",
}
-- A list of all symbols to display. Set to false to display all symbols.
-- This can be a filetype map (see :help aerial-filetype-map)
-- To see all available values, see :help SymbolKind
M.filter_kind = {}

M.enable_profile = false

return M
