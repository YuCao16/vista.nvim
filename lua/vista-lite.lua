-- vista-lite.lua: A minimal LSP symbol viewer for Neovim
-- ~500 lines of focused functionality

local M = {}
local api = vim.api

-- State management
local state = {
  bufnr = nil,      -- Vista buffer
  winnr = nil,      -- Vista window
  symbols = {},
  folded = {}, -- key: "line:name" value: true/false
  mode = 'tree', -- 'tree' or 'type'
  width = 30,
  file_path = nil,
  source_bufnr = nil,  -- Source file buffer
  source_winnr = nil,  -- Source file window
  title_line = 1, -- 0 or 1 depending on config
  line_metadata = {}, -- Metadata for each line for highlighting
}

-- Configuration
local config = {
  width = 30,
  position = 'right',  -- Default to right side
  auto_close = false,
  show_title = true,
  icons = {
    provider = 'mini', -- 'mini', 'builtin', 'none'
  },
  fold = {
    enable_memory = true,
    save_on_close = true,
  },
  keymaps = {
    jump = '<CR>',
    preview = 'p',
    toggle_fold = 'o',
    switch_mode = 's',
    close = 'q',
    expand_all = 'zR',
    collapse_all = 'zr',
  },
}

-- Icons module reference (lazy loaded)
local icons = nil
local fold_memory = nil

-- Built-in LSP symbol kinds
local symbol_kinds = {
  'File', 'Module', 'Namespace', 'Package', 'Class', 'Method', 'Property',
  'Field', 'Constructor', 'Enum', 'Interface', 'Function', 'Variable',
  'Constant', 'String', 'Number', 'Boolean', 'Array', 'Object', 'Key',
  'Null', 'EnumMember', 'Struct', 'Event', 'Operator', 'TypeParameter'
}

-- Utility functions
local function get_icon(kind)
  if config.icons.provider == 'none' then
    return ''
  end

  if config.icons.provider == 'mini' and not icons then
    local ok, mod = pcall(require, 'vista-lite.icons')
    if ok then icons = mod end
  end

  if icons then
    return icons.get(kind)
  end

  -- Builtin fallback
  local builtin_icons = {
    File = '󰈔', Module = '󰆧', Namespace = '󰅪', Package = '󰏗',
    Class = '󰠱', Method = '󰊕', Property = '󰀫', Field = '󰄶',
    Constructor = '󰒬', Enum = '󰒻', Interface = '󰜰', Function = '󰊕',
    Variable = '󰀫', Constant = '󰏿', String = '󰀬', Number = '󰎠',
    Boolean = '󰨙', Array = '󰅨', Object = '󰀚', Key = '󰌋',
    Null = '󰟢', EnumMember = '󰒻', Struct = '󰠲', Event = '󱐋',
    Operator = '󰆕', TypeParameter = '󰠱',
  }

  local kind_name = symbol_kinds[kind] or 'Unknown'
  return builtin_icons[kind_name] or '○'
end

local function get_window_width()
  if type(config.width) == 'number' then
    return config.width
  elseif type(config.width) == 'string' and config.width:match('%d+%%') then
    local percent = tonumber(config.width:match('(%d+)'))
    return math.floor(vim.o.columns * percent / 100)
  end
  return 30
end

local function create_buffer()
  if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  state.bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(state.bufnr, 'Vista')
  api.nvim_buf_set_option(state.bufnr, 'filetype', 'vista')
  api.nvim_buf_set_option(state.bufnr, 'buftype', 'nofile')
  api.nvim_buf_set_option(state.bufnr, 'bufhidden', 'hide')
  api.nvim_buf_set_option(state.bufnr, 'swapfile', false)
  api.nvim_buf_set_option(state.bufnr, 'modifiable', false)

  return state.bufnr
end

local function create_window()
  if state.winnr and api.nvim_win_is_valid(state.winnr) then
    return state.winnr
  end

  local width = get_window_width()
  -- For vsplit: 'topleft' puts window on left, 'botright' puts window on right
  local position_cmd = config.position == 'left' and 'topleft' or 'botright'
  local cmd = string.format('noautocmd %s vertical %d split',
    position_cmd, width)

  vim.cmd(cmd)
  state.winnr = api.nvim_get_current_win()

  -- Set window options
  local win_opts = {
    number = false, relativenumber = false, list = false,
    winfixwidth = true, winfixheight = false, foldenable = false,
    spell = false, signcolumn = 'no', foldmethod = 'manual',
    foldcolumn = '0', cursorcolumn = false, colorcolumn = '',
  }

  for opt, val in pairs(win_opts) do
    api.nvim_win_set_option(state.winnr, opt, val)
  end

  return state.winnr
end

-- LSP integration
local function request_symbols(callback)
  -- Use the source buffer, not the current (Vista) buffer
  local bufnr = state.source_bufnr or vim.api.nvim_get_current_buf()

  -- Check for active LSP clients
  local clients = vim.lsp.get_active_clients({ bufnr = bufnr })
  if #clients == 0 then
    vim.notify('No LSP client attached', vim.log.levels.WARN)
    callback({})
    return
  end

  -- Create params for documentSymbol request
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr)
  }

  vim.lsp.buf_request(bufnr, 'textDocument/documentSymbol', params, function(err, result)
    if err then
      vim.notify('LSP Error: ' .. vim.inspect(err), vim.log.levels.ERROR)
      callback({})
      return
    end

    if not result or vim.tbl_isempty(result) then
      vim.notify('No symbols found', vim.log.levels.INFO)
      callback({})
      return
    end

    callback(result)
  end)
end

-- Symbol processing
local function process_symbols(symbols, parent_name)
  local processed = {}
  parent_name = parent_name or ''

  for _, symbol in ipairs(symbols) do
    local item = {
      name = symbol.name,
      kind = symbol.kind,
      range = symbol.range or (symbol.location and symbol.location.range),
      detail = symbol.detail,
      parent = parent_name,
      children = {},
    }

    if symbol.children and #symbol.children > 0 then
      item.children = process_symbols(symbol.children, symbol.name)
    end

    table.insert(processed, item)
  end

  return processed
end

-- Rendering functions
local function render_tree(symbols, lines, indent, parent_folded, is_last_child)
  lines = lines or {}
  indent = indent or 0
  is_last_child = is_last_child or {}

  for i, symbol in ipairs(symbols) do
    local is_folded = state.folded[symbol.range.start.line .. ':' .. symbol.name]
    local has_children = symbol.children and #symbol.children > 0
    local fold_icon = has_children and (is_folded and '▸' or '▾') or ' '
    local is_last = (i == #symbols)

    -- Build indent guides
    local indent_str = ''
    for level = 1, indent do
      if is_last_child[level] then
        indent_str = indent_str .. '  '  -- No line for completed branches
      else
        indent_str = indent_str .. '│ '  -- Vertical line for continuing branches
      end
    end

    -- Add the branch connector
    local branch = ''
    if indent > 0 then
      branch = is_last and '└─' or '├─'
    end

    local line = indent_str .. branch .. fold_icon .. ' ' ..
                 get_icon(symbol.kind) .. ' ' .. symbol.name
    table.insert(lines, line)

    -- Store line metadata for highlighting
    local line_num = #lines + state.title_line - 1
    local prefix_len = vim.fn.strwidth(indent_str .. branch)
    state.line_metadata[line_num] = {
      kind = symbol.kind,
      has_children = has_children,
      indent = indent,
      indent_guide_start = 0,
      indent_guide_end = vim.fn.strwidth(indent_str),
      branch_start = vim.fn.strwidth(indent_str),
      branch_end = prefix_len,
      fold_start = prefix_len,
      fold_end = prefix_len + 1,
      icon_start = prefix_len + 2,
      icon_end = prefix_len + 3,
      name_start = prefix_len + 4 + vim.fn.strwidth(get_icon(symbol.kind)),
    }

    -- Store symbol info for navigation
    symbol.display_line = #lines + state.title_line

    if has_children and not is_folded and not parent_folded then
      -- Update is_last_child for recursion
      local new_is_last = vim.deepcopy(is_last_child)
      new_is_last[indent + 1] = is_last
      render_tree(symbol.children, lines, indent + 1, false, new_is_last)
    end
  end

  return lines
end

local function render_type(symbols)
  local lines = {}
  local categorized = {}

  -- Categorize symbols by type
  local function categorize(syms)
    for _, symbol in ipairs(syms) do
      local kind_name = symbol_kinds[symbol.kind] or 'Unknown'
      categorized[kind_name] = categorized[kind_name] or {}
      table.insert(categorized[kind_name], symbol)

      if symbol.children and #symbol.children > 0 then
        categorize(symbol.children)
      end
    end
  end

  categorize(symbols)

  -- Render categorized symbols
  for kind_name, syms in pairs(categorized) do
    local is_folded = state.folded['type:' .. kind_name]
    local fold_icon = is_folded and '▸' or '▾'

    local header_line = fold_icon .. ' ' .. kind_name .. ' (' .. #syms .. ')'
    table.insert(lines, header_line)

    -- Store metadata for category header
    local line_num = #lines + state.title_line - 1
    state.line_metadata[line_num] = {
      is_category = true,
      kind_name = kind_name,
      fold_start = 0,
      fold_end = 1,
      name_start = 2,
    }

    if not is_folded then
      for _, symbol in ipairs(syms) do
        local line = '    ' .. get_icon(symbol.kind) .. ' ' .. symbol.name
        table.insert(lines, line)

        -- Store metadata for symbol line
        local sym_line_num = #lines + state.title_line - 1
        state.line_metadata[sym_line_num] = {
          kind = symbol.kind,
          indent = 2,
          icon_start = 4,
          icon_end = 5,
          name_start = 6 + vim.fn.strwidth(get_icon(symbol.kind)),
        }

        symbol.display_line = #lines + state.title_line
      end
    end
  end

  return lines
end

local function render()
  if not state.bufnr or not api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  api.nvim_buf_set_option(state.bufnr, 'modifiable', true)

  -- Clear line metadata before rendering
  state.line_metadata = {}

  local lines = {}

  -- Add title if enabled
  if config.show_title then
    local title = '▾ ' .. (state.file_path or 'No file') .. ' [' .. state.mode .. ']'
    table.insert(lines, title)
    state.title_line = 1
  else
    state.title_line = 0
  end

  -- Render based on mode
  if state.mode == 'tree' then
    local content = render_tree(state.symbols)
    vim.list_extend(lines, content)
  else
    local content = render_type(state.symbols)
    vim.list_extend(lines, content)
  end

  -- Set buffer content
  api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  api.nvim_buf_set_option(state.bufnr, 'modifiable', false)

  -- Apply highlights
  apply_highlights()
end

-- Highlighting
function apply_highlights()
  if not state.bufnr or not api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  local ns = api.nvim_create_namespace('vista_lite')
  api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

  -- Highlight title
  if config.show_title then
    api.nvim_buf_add_highlight(state.bufnr, ns, 'Title', 0, 0, -1)
  end

  -- Get highlight groups for different symbol kinds
  local kind_highlights = {
    [1] = 'VistaFile',           -- File
    [2] = 'VistaModule',         -- Module
    [3] = 'VistaNamespace',      -- Namespace
    [4] = 'VistaPackage',        -- Package
    [5] = 'VistaClass',          -- Class
    [6] = 'VistaMethod',         -- Method
    [7] = 'VistaProperty',       -- Property
    [8] = 'VistaField',          -- Field
    [9] = 'VistaConstructor',    -- Constructor
    [10] = 'VistaEnum',          -- Enum
    [11] = 'VistaInterface',     -- Interface
    [12] = 'VistaFunction',      -- Function
    [13] = 'VistaVariable',      -- Variable
    [14] = 'VistaConstant',      -- Constant
    [15] = 'VistaString',        -- String
    [16] = 'VistaNumber',        -- Number
    [17] = 'VistaBoolean',       -- Boolean
    [18] = 'VistaArray',         -- Array
    [19] = 'VistaObject',        -- Object
    [20] = 'VistaKey',           -- Key
    [21] = 'VistaNull',          -- Null
    [22] = 'VistaEnumMember',    -- EnumMember
    [23] = 'VistaStruct',        -- Struct
    [24] = 'VistaEvent',         -- Event
    [25] = 'VistaOperator',      -- Operator
    [26] = 'VistaTypeParameter', -- TypeParameter
  }

  -- Apply highlights based on line metadata
  for line_num, metadata in pairs(state.line_metadata) do
    if metadata.is_category then
      -- Highlight category headers
      api.nvim_buf_add_highlight(state.bufnr, ns, 'Comment', line_num, metadata.fold_start, metadata.fold_end)
      api.nvim_buf_add_highlight(state.bufnr, ns, 'Type', line_num, metadata.name_start, -1)
    else
      -- Highlight indent guides and branches
      if metadata.indent_guide_end and metadata.indent_guide_end > 0 then
        api.nvim_buf_add_highlight(state.bufnr, ns, 'Comment', line_num, metadata.indent_guide_start, metadata.indent_guide_end)
      end
      if metadata.branch_start and metadata.branch_end and metadata.branch_end > metadata.branch_start then
        api.nvim_buf_add_highlight(state.bufnr, ns, 'Comment', line_num, metadata.branch_start, metadata.branch_end)
      end

      -- Highlight fold icons
      if metadata.has_children then
        api.nvim_buf_add_highlight(state.bufnr, ns, 'Comment', line_num, metadata.fold_start, metadata.fold_end)
      end

      -- Highlight icons (use a special color for icons)
      if metadata.icon_start and metadata.icon_end then
        api.nvim_buf_add_highlight(state.bufnr, ns, 'Special', line_num, metadata.icon_start, metadata.icon_end + 1)
      end

      -- Highlight symbol names based on their kind
      if metadata.kind and metadata.name_start then
        local hl_group = kind_highlights[metadata.kind] or 'Identifier'
        api.nvim_buf_add_highlight(state.bufnr, ns, hl_group, line_num, metadata.name_start, -1)
      end
    end
  end
end

-- Navigation functions
local function find_symbol_at_line(line_num)
  local function search(symbols)
    for _, symbol in ipairs(symbols) do
      if symbol.display_line == line_num then
        return symbol
      end
      if symbol.children then
        local found = search(symbol.children)
        if found then return found end
      end
    end
  end
  return search(state.symbols)
end

local function jump_to_symbol(preview_only)
  local line = api.nvim_win_get_cursor(state.winnr)[1]
  local symbol = find_symbol_at_line(line)

  if not symbol or not symbol.range then
    return
  end

  -- Use the stored source window if it's still valid
  local target_win = nil
  if state.source_winnr and api.nvim_win_is_valid(state.source_winnr) then
    target_win = state.source_winnr
  else
    -- Find a window with the source file
    local wins = api.nvim_list_wins()
    for _, win in ipairs(wins) do
      if win ~= state.winnr then
        local buf = api.nvim_win_get_buf(win)
        if buf == state.source_bufnr then
          target_win = win
          break
        end
      end
    end
  end

  if not target_win then
    -- Create a new split if no window found
    vim.cmd('wincmd w')
    vim.cmd('edit ' .. vim.fn.fnameescape(state.file_path))
    target_win = api.nvim_get_current_win()
  end

  -- Jump to position
  api.nvim_win_set_cursor(target_win, {
    symbol.range.start.line + 1,
    symbol.range.start.character
  })

  -- Center the view
  vim.cmd('normal! zz')

  if not preview_only then
    api.nvim_set_current_win(target_win)
    if config.auto_close then
      M.close()
    end
  else
    api.nvim_set_current_win(state.winnr)
  end
end

local function toggle_fold()
  local line = api.nvim_win_get_cursor(state.winnr)[1]

  if state.mode == 'tree' then
    local symbol = find_symbol_at_line(line)
    if symbol and symbol.children and #symbol.children > 0 then
      local key = symbol.range.start.line .. ':' .. symbol.name
      state.folded[key] = not state.folded[key]

      -- Save fold state if memory enabled
      if config.fold.enable_memory and fold_memory then
        fold_memory.save(state.file_path, state.folded)
      end

      render()
      api.nvim_win_set_cursor(state.winnr, {line, 0})
    end
  else -- type mode
    -- Find which category this line belongs to
    local lines = api.nvim_buf_get_lines(state.bufnr, line - 1, line, false)
    if #lines > 0 then
      local line_text = lines[1]
      -- Check if it's a category header
      if line_text:match('^[▸▾] %w+ %(') then
        local kind_name = line_text:match('^[▸▾] (%w+) %(')
        local key = 'type:' .. kind_name
        state.folded[key] = not state.folded[key]

        if config.fold.enable_memory and fold_memory then
          fold_memory.save(state.file_path, state.folded)
        end

        render()
        api.nvim_win_set_cursor(state.winnr, {line, 0})
      end
    end
  end
end

local function switch_mode()
  state.mode = state.mode == 'tree' and 'type' or 'tree'
  render()
end

local function expand_all()
  state.folded = {}
  if config.fold.enable_memory and fold_memory then
    fold_memory.save(state.file_path, state.folded)
  end
  render()
end

local function collapse_all()
  if state.mode == 'tree' then
    local function mark_folded(symbols)
      for _, symbol in ipairs(symbols) do
        if symbol.children and #symbol.children > 0 then
          local key = symbol.range.start.line .. ':' .. symbol.name
          state.folded[key] = true
          mark_folded(symbol.children)
        end
      end
    end
    mark_folded(state.symbols)
  else -- type mode
    for kind_name, _ in pairs(state.symbols) do
      state.folded['type:' .. kind_name] = true
    end
  end

  if config.fold.enable_memory and fold_memory then
    fold_memory.save(state.file_path, state.folded)
  end
  render()
end

-- Keymaps
local function setup_keymaps()
  if not state.bufnr then return end

  local opts = { noremap = true, silent = true, buffer = state.bufnr }

  vim.keymap.set('n', config.keymaps.jump, function() jump_to_symbol(false) end, opts)
  vim.keymap.set('n', config.keymaps.preview, function() jump_to_symbol(true) end, opts)
  vim.keymap.set('n', config.keymaps.toggle_fold, toggle_fold, opts)
  vim.keymap.set('n', config.keymaps.switch_mode, switch_mode, opts)
  vim.keymap.set('n', config.keymaps.close, M.close, opts)
  vim.keymap.set('n', config.keymaps.expand_all, expand_all, opts)
  vim.keymap.set('n', config.keymaps.collapse_all, collapse_all, opts)
end

-- Public API
function M.setup(opts)
  config = vim.tbl_deep_extend('force', config, opts or {})

  -- Load fold memory if enabled
  if config.fold.enable_memory then
    local ok, mod = pcall(require, 'vista-lite.fold-memory')
    if ok then fold_memory = mod end
  end
end

function M.open()
  -- Save source buffer and window info BEFORE creating vista window
  state.source_bufnr = api.nvim_get_current_buf()
  state.source_winnr = api.nvim_get_current_win()
  state.file_path = api.nvim_buf_get_name(state.source_bufnr)

  -- Create buffer and window
  create_buffer()
  create_window()

  -- Switch to vista buffer
  api.nvim_win_set_buf(state.winnr, state.bufnr)

  -- Setup keymaps
  setup_keymaps()

  -- Load fold memory if available
  if config.fold.enable_memory and fold_memory then
    state.folded = fold_memory.load(state.file_path) or {}
  end

  -- Request symbols and render
  request_symbols(function(symbols)
    state.symbols = process_symbols(symbols)
    render()
  end)

  -- Focus back to original window
  if state.source_winnr and api.nvim_win_is_valid(state.source_winnr) then
    api.nvim_set_current_win(state.source_winnr)
  end
end

function M.close()
  -- Save fold state if memory enabled
  if config.fold.save_on_close and fold_memory and state.file_path then
    fold_memory.save(state.file_path, state.folded)
  end

  if state.winnr and api.nvim_win_is_valid(state.winnr) then
    api.nvim_win_close(state.winnr, true)
    state.winnr = nil
  end
end

function M.toggle()
  if state.winnr and api.nvim_win_is_valid(state.winnr) then
    M.close()
  else
    M.open()
  end
end

function M.focus()
  if not state.winnr or not api.nvim_win_is_valid(state.winnr) then
    M.open()
  end
  if state.winnr and api.nvim_win_is_valid(state.winnr) then
    api.nvim_set_current_win(state.winnr)
  end
end

function M.refresh()
  if not state.winnr or not api.nvim_win_is_valid(state.winnr) then
    return
  end

  request_symbols(function(symbols)
    state.symbols = process_symbols(symbols)
    render()
  end)
end

return M