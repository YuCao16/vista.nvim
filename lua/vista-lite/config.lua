local M = {}

-- Default configuration
M.defaults = {
  lsp = {
    servers = { 'pyright', 'rust_analyzer', 'clangd', 'ts_ls', 'gopls', 'lua_ls' },
  },
  width = 30,
  position = 'right',  -- 'left' or 'right'
  auto_close = false,
  show_title = true,
  display = {
    mode = 'tree',  -- 'flat', 'tree', or 'type'
    show_title = true,
    title_format = ' Vista: %s ',
    title_hl = 'VistaTitle',
    max_width = 40,
    min_width = 30,
  },
  indent_guides = {
    enable = true,
    style = 'tree',  -- 'simple', 'tree'
    markers = {
      vertical = '│',  -- Thin vertical line
      corner = '└',    -- Thin corner
    },
  },
  icons = {
    provider = 'mini', -- 'mini', 'builtin', 'none'
    fold_open = '',  -- Icon for expanded/open fold '▼'
    fold_closed = '',  -- Icon for collapsed/closed fold '▶'
  },
  fold = {
    enable_memory = true,
    save_on_close = true,
  },
  keymaps = {
    jump = '<CR>',
    preview = 'p',
    toggle_fold = 'o',
    close = 'q',
    refresh = 'R',
    switch_mode = 's',
    toggle_kind = 't',
    jump_split = 's',
    jump_vsplit = 'v',
    jump_tab = 't',
    expand_all = 'zR',
    collapse_all = 'zr',
  },
  symbol_icons = {},  -- Will be populated by setup
}

-- Builtin icons
M.builtin_icons = {
  File = '󰈔',
  Module = '󰆧',
  Namespace = '󰅪',
  Package = '󰏗',
  Class = '󰠱',
  Method = '󰊕',
  Property = '󰜢',
  Field = '󰆨',
  Constructor = '',
  Enum = '',
  Interface = '',
  Function = '󰊕',
  Variable = '󰀫',
  Constant = '󰏿',
  String = '󰀬',
  Number = '󰎠',
  Boolean = '󰨙',
  Array = '󰅪',
  Object = '',
  Key = '󰌋',
  Null = '󰟢',
  EnumMember = '',
  Struct = '󰠱',
  Event = '',
  Operator = '󰆕',
  TypeParameter = '󰗴',
}

-- Mini.icons provider (will be loaded dynamically if available)
M.mini_icons = nil

-- Get icon for a symbol kind
function M.get_icon(kind, provider)
  provider = provider or M.config.icons.provider

  if provider == 'mini' and M.mini_icons then
    local icon, hl = M.mini_icons.get('lsp', kind)
    return icon or M.builtin_icons[kind] or '●'
  elseif provider == 'builtin' then
    return M.builtin_icons[kind] or '●'
  else
    return ''  -- No icon
  end
end

-- Setup configuration
function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.defaults, opts or {})

  -- Try to load mini.icons if available and configured
  if M.config.icons.provider == 'mini' then
    local ok, mini_icons = pcall(require, 'mini.icons')
    if ok then
      M.mini_icons = mini_icons
    else
      -- Fallback to builtin if mini.icons not available
      M.config.icons.provider = 'builtin'
    end
  end

  -- Populate symbol_icons based on provider
  for kind, _ in pairs(M.builtin_icons) do
    M.config.symbol_icons[kind] = M.get_icon(kind)
  end

  return M.config
end

-- Get current config
function M.get()
  if not M.config then
    M.setup({})  -- Initialize with defaults if not setup yet
  end
  return M.config
end

return M
