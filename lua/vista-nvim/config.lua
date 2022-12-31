local M = {}

M.width = 30
M.side = "right"
M.show_guide = true
M.border = "rounded"
M.auto_close = false
M.auto_preview = false
M.fold_markers = { "", "" }
M.disable_max_lines = 10000
M.disable_max_sizes = 2000000 -- Default 2MB
M.filetype_map = {}
-- A list of all symbols to display. Set to false to display all symbols.
-- This can be a filetype map (see :help aerial-filetype-map)
-- To see all available values, see :help SymbolKind
M.filter_kind = {}

M.enable_profile = false
