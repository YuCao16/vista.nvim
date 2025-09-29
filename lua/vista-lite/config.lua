local M = {}

-- Default configuration
M.defaults = {
  -- Window configuration
  width = 32, -- Width of the vista window
  max_expanded_width = 80, -- Maximum width when expanded with 'e' key
  position = "right", -- Position: 'left' or 'right'
  auto_close = false, -- Auto close vista when jumping to symbol
  show_title = true, -- Show title bar

  -- Display settings
  display = {
    mode = "tree", -- Display mode: 'tree' or 'type'
    title_format = " Vista: %s ", -- Title format (%s = filename)
    title_hl = "VistaTitle", -- Title highlight group
    max_width = 40, -- Maximum window width
    min_width = 30, -- Minimum window width
    mode_icons = {
      tree = "󱏒 ", -- Icon for tree mode
      type = " ", -- Icon for type mode
    },
    truncate_path = true, -- Enable smart path truncation
  },

  -- LSP configuration
  lsp = {
    -- Filetype-specific server preferences
    filetype_servers = {
      python = { "ruff" },
      rust = { "rust_analyzer" },
      c = { "clangd" },
      cpp = { "clangd" },
      javascript = { "ts_ls", "tsserver" },
      typescript = { "ts_ls", "tsserver" },
      go = { "gopls" },
      lua = { "lua_ls" },
    },
    -- Default servers to try if no filetype match
    default_servers = { "basedpyright", "pyright", "rust_analyzer", "ts_ls", "tsserver", "gopls", "clangd", "lua_ls" },
  },

  -- Tree indentation guides
  indent_guides = {
    enable = true, -- Enable indent guides
    style = "tree", -- Style: 'tree' or 'simple'
    markers = {
      vertical = "│", -- Vertical line for continuing items
      corner = "└", -- Corner for last item
      edge = "├", -- Edge connector (not currently used)
    },
  },

  -- Icons configuration
  icons = {
    provider = "mini", -- Icon provider: 'mini', 'builtin', or 'none'
    -- Fold icons - you can customize these
    fold_open = "", -- Icon for expanded items
    fold_closed = "", -- Icon for collapsed items
  },

  -- Fold state management
  fold = {
    enable_memory = true, -- Remember fold states
    save_on_close = true, -- Save fold states when closing
  },

  -- Key mappings
  keymaps = {
    jump = "<CR>", -- Jump to symbol
    preview = "p", -- Preview symbol location
    toggle_fold = "o", -- Toggle fold
    close = "q", -- Close vista window
    refresh = "R", -- Refresh symbols
    switch_mode = "s", -- Switch between tree/type mode
    toggle_kind = "t", -- Toggle kind visibility
    jump_split = "s", -- Jump to symbol in split
    jump_vsplit = "v", -- Jump to symbol in vsplit
    jump_tab = "t", -- Jump to symbol in new tab
    expand_all = "zR", -- Expand all folds
    collapse_all = "zr", -- Collapse all folds
  },

  -- Symbol blacklist configuration
  symbol_blacklist = {
    -- Global blacklist (applies to all file types)
    global = {
      type = {}, -- Symbol kinds to hide in type mode
      tree = {}, -- Symbol kinds to hide in tree mode
    },
    -- Per-filetype blacklist
    filetypes = {
      python = {
        type = { "Variable" }, -- Hide Variable in type mode for Python files
        tree = {}, -- Show all symbols in tree mode
      },
      javascript = {
        type = { "Variable", "Constant" }, -- Hide Variable and Constant in type mode
        tree = {},
      },
      typescript = {
        type = { "Variable", "Constant" },
        tree = {},
      },
    },
  },

  -- Internal - populated during setup
  symbol_icons = {}, -- Symbol icons cache
}

-- Icons are managed by icons.lua module

-- Alternative icon sets
M.icon_sets = {
  minimal = {
    File = "◯",
    Module = "◉",
    Namespace = "◎",
    Package = "◈",
    Class = "○",
    Method = "●",
    Property = "◆",
    Field = "◇",
    Constructor = "◐",
    Enum = "◑",
    Interface = "◒",
    Function = "●",
    Variable = "◓",
    Constant = "◔",
    String = "◕",
    Number = "◖",
    Boolean = "◗",
    Array = "◘",
    Object = "◙",
    Key = "◚",
    Null = "◛",
    EnumMember = "◜",
    Struct = "◝",
    Event = "◞",
    Operator = "◟",
    TypeParameter = "◠",
  },
  ascii = {
    File = "F",
    Module = "M",
    Namespace = "N",
    Package = "P",
    Class = "C",
    Method = "m",
    Property = "p",
    Field = "f",
    Constructor = "c",
    Enum = "E",
    Interface = "I",
    Function = "ƒ",
    Variable = "v",
    Constant = "const",
    String = "s",
    Number = "n",
    Boolean = "b",
    Array = "a",
    Object = "o",
    Key = "k",
    Null = "null",
    EnumMember = "e",
    Struct = "S",
    Event = "ev",
    Operator = "op",
    TypeParameter = "T",
  },
}

-- Mini.icons provider (will be loaded dynamically if available)
M.mini_icons = nil

-- Get icon for a symbol kind
function M.get_icon(kind, provider)
  provider = provider or M.config.icons.provider
  local icons_module = require("vista-lite.icons")

  if provider == "mini" then
    -- icons module will handle mini.icons internally
    return icons_module.get(kind)
  elseif provider == "minimal" then
    return M.icon_sets.minimal[kind] or "●"
  elseif provider == "ascii" then
    return M.icon_sets.ascii[kind] or "*"
  elseif provider == "none" then
    return "" -- No icon
  else
    -- Default to icons module which handles builtin icons
    return icons_module.get(kind)
  end
end

-- Setup configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})

  -- Try to load mini.icons if configured
  if M.config.icons.provider == "mini" then
    local ok, mini_icons = pcall(require, "mini.icons")
    if ok then
      M.mini_icons = mini_icons
    else
      -- Fallback to builtin if mini.icons not available
      M.config.icons.provider = "builtin"
    end
  end

  -- Populate symbol_icons cache based on provider
  -- Using numeric kinds 1-26 as defined in LSP spec
  for i = 1, 26 do
    M.config.symbol_icons[i] = M.get_icon(i)
  end

  return M.config
end

-- Get current config
function M.get()
  if not M.config then
    M.setup({}) -- Initialize with defaults if not setup yet
  end
  return M.config
end

-- Update a specific config value
function M.set(key, value)
  if not M.config then
    M.setup({})
  end

  -- Handle nested keys like 'icons.provider'
  local keys = vim.split(key, ".", { plain = true })
  local config = M.config

  for i = 1, #keys - 1 do
    config = config[keys[i]]
    if not config then
      error("Invalid config key: " .. key)
    end
  end

  config[keys[#keys]] = value
end

return M
