local M = {}

M.disable_default_keybindings = 0
M.bindings = nil
M.side = "right"
M.initial_width = 30

M.hide_statusline = false

M.update_interval = 1000

M.enable_profile = false

M.section_title_separator = { "" }

M.sections = { "symbols" }

M.section = "symbols"

M.symbols = { icon = "ƒ" }

M.datetime = {
    icon = "",
    format = "%a %b %d, %H:%M",
    clocks = { { name = "local" } },
}

return M
