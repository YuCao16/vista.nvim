-- vista-lite.lua: A minimal LSP symbol viewer for Neovim
-- ~500 lines of focused functionality

local M = {}
local api = vim.api
local Config = require("vista-lite.config")

-- State management
local state = {
  bufnr = nil, -- Vista buffer
  winnr = nil, -- Vista window
  symbols = {},
  folded = {}, -- key: "line:name" value: true/false
  mode = "tree", -- 'tree' or 'type'
  width = 30,
  file_path = nil,
  source_bufnr = nil, -- Source file buffer
  source_winnr = nil, -- Source file window
  title_line = 1, -- 0 or 1 depending on config
  line_metadata = {}, -- Metadata for each line for highlighting
  last_refresh = {}, -- bufnr -> changedtick last rendered
  rendered_bufnr = nil, -- the buffer whose symbols are currently rendered
}

-- Get configuration from Config module
local config = Config.get()

-- Icons module reference (lazy loaded)
local icons = nil
local fold_memory = nil
local autocmds_installed = false

-- Forward declarations for functions referenced before definition
local lsp_supports_document_symbols
local request_symbols
local process_symbols
local render

local function ensure_autocmds()
  if autocmds_installed then
    return
  end
  local group = api.nvim_create_augroup("VistaLiteFollow", { clear = true })
  -- Follow on buffer enter
  api.nvim_create_autocmd({ "BufEnter" }, {
    group = group,
    callback = function(ev)
      if not state.winnr or not api.nvim_win_is_valid(state.winnr) then
        return
      end
      if not state.bufnr then
        return
      end
      if ev.buf == state.bufnr then
        return
      end
      if vim.bo[ev.buf].buftype ~= "" then
        return
      end
      if not lsp_supports_document_symbols(ev.buf) then
        return
      end

      state.source_bufnr = ev.buf
      local curwin = api.nvim_get_current_win()
      if curwin ~= state.winnr then
        state.source_winnr = curwin
      end
      state.file_path = api.nvim_buf_get_name(ev.buf)

      if config.fold.enable_memory and fold_memory and state.file_path then
        state.folded = fold_memory.load(state.file_path) or {}
      end

      -- Refresh logic: always refresh when switching to a different buffer,
      -- otherwise only refresh if changedtick differs (content changed)
      local tick = api.nvim_buf_get_changedtick(ev.buf)
      if state.rendered_bufnr ~= ev.buf then
        request_symbols(function(symbols)
          state.symbols = process_symbols(symbols)
          render()
          state.rendered_bufnr = ev.buf
          state.last_refresh[ev.buf] = tick
        end)
      elseif state.last_refresh[ev.buf] == tick then
      else
        request_symbols(function(symbols)
          state.symbols = process_symbols(symbols)
          render()
          state.rendered_bufnr = ev.buf
          state.last_refresh[ev.buf] = tick
        end)
      end
    end,
  })

  -- Refresh when LSP attaches
  api.nvim_create_autocmd({ "LspAttach" }, {
    group = group,
    callback = function(ev)
      if not state.winnr or not api.nvim_win_is_valid(state.winnr) then
        return
      end
      if not state.bufnr then
        return
      end
      if ev.buf == state.bufnr then
        return
      end
      if vim.bo[ev.buf].buftype ~= "" then
        return
      end
      if not lsp_supports_document_symbols(ev.buf) then
        return
      end

      state.source_bufnr = ev.buf
      state.file_path = api.nvim_buf_get_name(ev.buf)
      if config.fold.enable_memory and fold_memory and state.file_path then
        state.folded = fold_memory.load(state.file_path) or {}
      end
      local tick = api.nvim_buf_get_changedtick(ev.buf)
      if state.rendered_bufnr ~= ev.buf then
        request_symbols(function(symbols)
          state.symbols = process_symbols(symbols)
          render()
          state.rendered_bufnr = ev.buf
          state.last_refresh[ev.buf] = tick
        end)
      elseif state.last_refresh[ev.buf] == tick then
      else
        request_symbols(function(symbols)
          state.symbols = process_symbols(symbols)
          render()
          state.rendered_bufnr = ev.buf
          state.last_refresh[ev.buf] = tick
        end)
      end
    end,
  })
  autocmds_installed = true
end

-- Built-in LSP symbol kinds
local symbol_kinds = {
  "File",
  "Module",
  "Namespace",
  "Package",
  "Class",
  "Method",
  "Property",
  "Field",
  "Constructor",
  "Enum",
  "Interface",
  "Function",
  "Variable",
  "Constant",
  "String",
  "Number",
  "Boolean",
  "Array",
  "Object",
  "Key",
  "Null",
  "EnumMember",
  "Struct",
  "Event",
  "Operator",
  "TypeParameter",
}

-- Utility functions
local function get_icon(kind)
  if config.icons.provider == "none" then
    return ""
  end

  if config.icons.provider == "mini" and not icons then
    local ok, mod = pcall(require, "vista-lite.icons")
    if ok then
      icons = mod
    end
  end

  if icons then
    return icons.get(kind)
  end

  -- Builtin fallback
  local builtin_icons = {
    File = "󰈔",
    Module = "󰆧",
    Namespace = "󰅪",
    Package = "󰏗",
    Class = "󰠱",
    Method = "󰊕",
    Property = "󰀫",
    Field = "󰄶",
    Constructor = "󰒬",
    Enum = "󰒻",
    Interface = "󰜰",
    Function = "󰊕",
    Variable = "󰀫",
    Constant = "󰏿",
    String = "󰀬",
    Number = "󰎠",
    Boolean = "󰨙",
    Array = "󰅨",
    Object = "󰀚",
    Key = "󰌋",
    Null = "󰟢",
    EnumMember = "󰒻",
    Struct = "󰠲",
    Event = "󱐋",
    Operator = "󰆕",
    TypeParameter = "󰠱",
  }

  local kind_name = symbol_kinds[kind] or "Unknown"
  return builtin_icons[kind_name] or "○"
end

local function get_window_width()
  if type(config.width) == "number" then
    return config.width
  elseif type(config.width) == "string" and config.width:match("%d+%%") then
    local percent = tonumber(config.width:match("(%d+)"))
    return math.floor(vim.o.columns * percent / 100)
  end
  return 30
end

local function create_buffer()
  if state.bufnr and api.nvim_buf_is_valid(state.bufnr) then
    return state.bufnr
  end

  state.bufnr = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(state.bufnr, "Vista")
  api.nvim_buf_set_option(state.bufnr, "filetype", "vista")
  api.nvim_buf_set_option(state.bufnr, "buftype", "nofile")
  api.nvim_buf_set_option(state.bufnr, "bufhidden", "hide")
  api.nvim_buf_set_option(state.bufnr, "swapfile", false)
  api.nvim_buf_set_option(state.bufnr, "modifiable", false)

  return state.bufnr
end

local function create_window()
  if state.winnr and api.nvim_win_is_valid(state.winnr) then
    return state.winnr
  end

  local width = get_window_width()
  -- For vsplit: 'topleft' puts window on left, 'botright' puts window on right
  local position_cmd = config.position == "left" and "topleft" or "botright"
  local cmd = string.format("noautocmd %s vertical %d split", position_cmd, width)

  vim.cmd(cmd)
  state.winnr = api.nvim_get_current_win()

  -- Set window options
  local win_opts = {
    number = false,
    relativenumber = false,
    list = false,
    winfixwidth = true,
    winfixheight = false,
    foldenable = false,
    spell = false,
    signcolumn = "no",
    foldmethod = "manual",
    foldcolumn = "0",
    cursorcolumn = false,
    colorcolumn = "",
  }

  for opt, val in pairs(win_opts) do
    api.nvim_win_set_option(state.winnr, opt, val)
  end

  return state.winnr
end

-- LSP integration
lsp_supports_document_symbols = function(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local clients = {}
  if vim.lsp.get_clients then
    clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentSymbol" })
  else
    ---@diagnostic disable-next-line: deprecated
    clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    clients = vim.tbl_filter(function(c)
      return c.supports_method and c:supports_method("textDocument/documentSymbol")
    end, clients)
  end
  return #clients > 0
end

request_symbols = function(callback)
  -- Use the source buffer, not the current (Vista) buffer
  local bufnr = state.source_bufnr or vim.api.nvim_get_current_buf()

  -- Check for active LSP clients
  local clients
  if vim.lsp.get_clients then
    clients = vim.lsp.get_clients({ bufnr = bufnr, method = "textDocument/documentSymbol" })
  else
    ---@diagnostic disable-next-line: deprecated
    clients = vim.lsp.get_active_clients({ bufnr = bufnr })
    clients = vim.tbl_filter(function(c)
      return c.supports_method and c:supports_method("textDocument/documentSymbol")
    end, clients)
  end

  if #clients == 0 then
    callback({})
    return
  end

  -- Use only the first LSP client to avoid duplicate requests
  -- Priority: prefer language servers that provide better symbol info
  local preferred_order = { "basedpyright", "pyright", "rust_analyzer", "tsserver", "gopls" }
  local selected_client = nil

  -- First try to find a preferred client
  for _, preferred_name in ipairs(preferred_order) do
    for _, client in ipairs(clients) do
      if client.name == preferred_name then
        selected_client = client
        break
      end
    end
    if selected_client then
      break
    end
  end

  -- If no preferred client found, just use the first one
  if not selected_client then
    selected_client = clients[1]
  end

  -- Create params for documentSymbol request
  local params = {
    textDocument = vim.lsp.util.make_text_document_params(bufnr),
  }

  -- Make request with only the selected client
  selected_client.request("textDocument/documentSymbol", params, function(err, result)
    if err then
      callback({})
      return
    end

    if not result or vim.tbl_isempty(result) then
      callback({})
      return
    end

    -- Filter out import/module symbols that some LSPs include
    local filtered = {}
    for _, sym in ipairs(result) do
      -- Skip pure import statements (modules without children at the top of file)
      if
        not (
          sym.kind == 2
          and sym.range
          and sym.range.start.line < 30
          and (not sym.children or #sym.children == 0)
        )
      then
        table.insert(filtered, sym)
      end
    end

    callback(filtered)
  end)
end

-- Symbol processing
process_symbols = function(symbols, parent_name)
  local processed = {}
  parent_name = parent_name or ""

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
local function render_tree(symbols, lines, indent_stack, parent_folded)
  lines = lines or {}
  indent_stack = indent_stack or {}

  for i, symbol in ipairs(symbols) do
    local is_folded = state.folded[symbol.range.start.line .. ":" .. symbol.name]
    local has_children = symbol.children and #symbol.children > 0
    local fold_icon = has_children
        and (is_folded and config.icons.fold_closed or config.icons.fold_open)
      or " "
    local is_last = (i == #symbols)

    local line_parts = {}
    local part_positions = {} -- Track start/end positions of each part

    -- Add a leading space for all lines to shift everything right
    table.insert(line_parts, " ")

    -- Build indentation from the stack
    -- Only add connectors for non-top-level items (i.e., when indent_stack is not empty)
    if
      config.indent_guides.enable
      and config.indent_guides.style == "tree"
      and #indent_stack > 0
    then
      -- Output parent continuation lines first (but skip for direct children of root)
      if #indent_stack > 1 then
        -- Skip the first item in the stack (which represents root level continuation)
        for i = 2, #indent_stack do
          local cont = indent_stack[i]
          if cont == "continue" then
            table.insert(line_parts, config.indent_guides.markers.vertical)
            table.insert(line_parts, " ")
          else -- 'space'
            table.insert(line_parts, "  ")
          end
        end
      end

      -- Add the connector for current item
      local connector = is_last and config.indent_guides.markers.corner
        or config.indent_guides.markers.vertical
      table.insert(line_parts, connector)
      table.insert(line_parts, " ")

      part_positions.indent = { 1, #table.concat(line_parts) }  -- Start from position 1 due to leading space
    elseif #indent_stack > 0 then
      -- No tree guides, just add spaces
      local base_indent = string.rep("  ", #indent_stack + 1)
      table.insert(line_parts, base_indent)
      part_positions.indent = { 1, #table.concat(line_parts) }  -- Start from position 1 due to leading space
    else
      -- No indentation for top-level items (but still has the leading space)
      part_positions.indent = { 1, 1 }
    end

    -- Add fold icon for items with children
    if has_children then
      local cur = #table.concat(line_parts)
      table.insert(line_parts, fold_icon .. " ")
      part_positions.fold = { cur, cur + #fold_icon }
    else
      -- Items without children - add two spaces for alignment with fold icon
      table.insert(line_parts, "  ")
    end

    -- Add icon
    local icon = get_icon(symbol.kind)
    local icon_width = #icon

    -- Calculate position before adding icon to line_parts
    local current_pos = #table.concat(line_parts)

    -- Add icon and space
    if icon and icon ~= "" then
      table.insert(line_parts, icon .. " ")
      -- Store icon position if icon exists
      if icon_width > 0 then
        part_positions.icon = { current_pos, current_pos + icon_width }
      end
    else
      -- No icon, just add spacing for alignment
      table.insert(line_parts, "  ")
    end

    -- Calculate name position after icon/spacing is added
    local name_start = #table.concat(line_parts)

    -- Add name
    table.insert(line_parts, symbol.name)
    part_positions.name = { name_start, -1 }

    local line = table.concat(line_parts)
    table.insert(lines, line)

    -- Store line metadata for highlighting with correct positions
    -- Buffer is 0-based, lines array is 1-based
    -- We store the actual buffer line number (0-based)
    local buffer_line = #lines - 1 + (config.show_title and 1 or 0)
    state.line_metadata[buffer_line] = {
      kind = symbol.kind,
      has_children = has_children,
      indent = indent,
      positions = part_positions, -- Store all part positions
      symbol_name = symbol.name, -- Store for debugging
      icon_width = icon_width, -- Store for debugging
    }

    -- Store symbol info for navigation
    -- Note: display_line will be calculated in a second pass after rendering

    if has_children and not is_folded and not parent_folded then
      -- Push the appropriate symbol onto the stack for children
      local new_stack = vim.deepcopy(indent_stack)

      -- Add continuation status for the current level
      -- This tells children whether their parent continues
      if is_last then
        table.insert(new_stack, "space") -- Parent ended, just add space
      else
        table.insert(new_stack, "continue") -- Parent continues, show vertical line
      end

      render_tree(symbol.children, lines, new_stack, false)
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
      local kind_name = symbol_kinds[symbol.kind] or "Unknown"
      categorized[kind_name] = categorized[kind_name] or {}
      table.insert(categorized[kind_name], symbol)

      if symbol.children and #symbol.children > 0 then
        categorize(symbol.children)
      end
    end
  end

  categorize(symbols)

  -- Save for line mapping
  state.categorized_symbols = categorized

  -- Render categorized symbols
  for kind_name, syms in pairs(categorized) do
    local is_folded = state.folded["type:" .. kind_name]
    local fold_icon = is_folded and config.icons.fold_closed or config.icons.fold_open

    local header_line = fold_icon .. " " .. kind_name .. " (" .. #syms .. ")"
    table.insert(lines, header_line)

    -- Store metadata for category header
    local line_num = #lines - 1 + (config.show_title and 1 or 0)
    state.line_metadata[line_num] = {
      is_category = true,
      kind_name = kind_name,
      positions = {
        fold = { 0, #fold_icon },
        name = { #fold_icon + 1, -1 }, -- after the space
      },
    }

    if not is_folded then
      for _, symbol in ipairs(syms) do
        local icon = get_icon(symbol.kind)
        local line = "    " .. icon .. " " .. symbol.name
        table.insert(lines, line)

        -- Store metadata for symbol line with byte positions
        local sym_line_num = #lines - 1 + (config.show_title and 1 or 0)
        state.line_metadata[sym_line_num] = {
          kind = symbol.kind,
          positions = {
            indent = { 0, 4 }, -- 4 ASCII spaces
            icon = { 4, 4 + #icon },
            name = { 4 + #icon + 1, -1 },
          },
        }

        symbol.display_line = #lines + state.title_line
      end
    end
  end

  return lines
end

-- Build a mapping from display line to symbol
local function build_line_to_symbol_map()
  state.line_to_symbol = {}

  local function map_tree(symbols, current_line, parent_folded)
    for _, symbol in ipairs(symbols) do
      local is_folded = state.folded[symbol.range.start.line .. ":" .. symbol.name]

      -- Map this line to the symbol
      state.line_to_symbol[current_line] = symbol
      symbol.display_line = current_line
      current_line = current_line + 1

      -- If not folded and has children, process them
      if symbol.children and #symbol.children > 0 and not is_folded and not parent_folded then
        current_line = map_tree(symbol.children, current_line, false)
      end
    end
    return current_line
  end

  -- Start from line after title (if present)
  local start_line = config.show_title and 2 or 1

  if state.mode == "tree" then
    map_tree(state.symbols, start_line, false)
  else
    -- For type mode, different logic needed
    local current_line = start_line
    for kind_name, syms in pairs(state.categorized_symbols or {}) do
      -- Category header
      state.line_to_symbol[current_line] = { is_category = true, kind_name = kind_name }
      current_line = current_line + 1

      local is_folded = state.folded["type:" .. kind_name]
      if not is_folded then
        for _, symbol in ipairs(syms) do
          state.line_to_symbol[current_line] = symbol
          symbol.display_line = current_line
          current_line = current_line + 1
        end
      end
    end
  end
end

render = function()
  if not state.bufnr or not api.nvim_buf_is_valid(state.bufnr) then
    return
  end

  api.nvim_buf_set_option(state.bufnr, "modifiable", true)

  -- Clear line metadata before rendering
  state.line_metadata = {}

  local lines = {}

  -- Add title if enabled
  if config.show_title then
    local title = config.icons.fold_open
      .. " "
      .. (state.file_path or "No file")
      .. " ["
      .. state.mode
      .. "]"
    table.insert(lines, title)
    state.title_line = 1
  else
    state.title_line = 0
  end

  -- Render based on mode
  if state.mode == "tree" then
    local content = render_tree(state.symbols, nil, {}, false, true)
    vim.list_extend(lines, content)
  else
    local content = render_type(state.symbols)
    vim.list_extend(lines, content)
  end

  -- Set buffer content
  api.nvim_buf_set_lines(state.bufnr, 0, -1, false, lines)
  api.nvim_buf_set_option(state.bufnr, "modifiable", false)

  -- Build line-to-symbol mapping AFTER rendering
  build_line_to_symbol_map()

  -- Apply highlights
  apply_highlights()
end

-- Highlighting
function apply_highlights()
  if not state.bufnr or not api.nvim_buf_is_valid(state.bufnr) then
    vim.notify("Buffer not valid for highlights", vim.log.levels.WARN)
    return
  end

  local ns = api.nvim_create_namespace("vista_lite")
  api.nvim_buf_clear_namespace(state.bufnr, ns, 0, -1)

  -- Debug: count metadata
  local metadata_count = 0
  for _ in pairs(state.line_metadata) do
    metadata_count = metadata_count + 1
  end

  -- Highlight title
  if config.show_title then
    api.nvim_buf_add_highlight(state.bufnr, ns, "Title", 0, 0, -1)
  end

  -- Treesitter-aligned highlight groups for symbol kinds (avoid custom Vista* groups)
  local kind_highlights = {
    [1] = "Normal", -- File
    [2] = "@module", -- Module
    [3] = "@module", -- Namespace
    [4] = "@module", -- Package
    [5] = "@type", -- Class
    [6] = "@function.method", -- Method
    [7] = "@property", -- Property
    [8] = "@variable.member", -- Field
    [9] = "@constructor", -- Constructor
    [10] = "@lsp.type.enum", -- Enum
    [11] = "@lsp.type.interface", -- Interface
    [12] = "@function", -- Function
    [13] = "@variable", -- Variable
    [14] = "@constant", -- Constant
    [15] = "@string", -- String
    [16] = "@number", -- Number
    [17] = "@boolean", -- Boolean
    [18] = "@punctuation.bracket", -- Array
    [19] = "@constant", -- Object
    [20] = "@lsp.type.keyword", -- Key
    [21] = "@constant.builtin", -- Null
    [22] = "@lsp.type.enumMember", -- EnumMember
    [23] = "@lsp.type.struct", -- Struct
    [24] = "Special", -- Event
    [25] = "@operator", -- Operator
    [26] = "@lsp.type.typeParameter", -- TypeParameter
  }

  -- Apply highlights based on line metadata
  local highlight_count = 0
  for line_num, metadata in pairs(state.line_metadata) do
    -- Debug output disabled

    if metadata.is_category and metadata.positions then
      -- Highlight category headers
      local pos = metadata.positions
      if pos.fold then
        api.nvim_buf_add_highlight(state.bufnr, ns, "Comment", line_num, pos.fold[1], pos.fold[2])
      end
      if pos.name then
        api.nvim_buf_add_highlight(state.bufnr, ns, "Type", line_num, pos.name[1], pos.name[2])
      end
    elseif metadata.positions then
      local pos = metadata.positions

      -- Highlight indent guides (connector)
      if pos.connector and config.indent_guides.enable then
        api.nvim_buf_add_highlight(
          state.bufnr,
          ns,
          "Comment",
          line_num,
          pos.connector[1],
          pos.connector[2]
        )
      end

      -- Highlight fold icons
      if metadata.has_children and pos.fold then
        api.nvim_buf_add_highlight(state.bufnr, ns, "Comment", line_num, pos.fold[1], pos.fold[2])
      end

      -- Highlight based on whether icon exists
      if metadata.kind then
        local hl_group = kind_highlights[metadata.kind] or "Identifier"

        -- Debug individual highlights
        if pos.icon then
          -- Icon exists, color only the icon
          local ok = pcall(
            api.nvim_buf_add_highlight,
            state.bufnr,
            ns,
            hl_group,
            line_num,
            pos.icon[1],
            pos.icon[2]
          )
          if ok then
            highlight_count = highlight_count + 1
          end
        elseif pos.name then
          -- No icon, color the first few characters of the name to simulate an "icon"
          local name_end = pos.name[1] + 3 -- Color first 3 chars
          local ok = pcall(
            api.nvim_buf_add_highlight,
            state.bufnr,
            ns,
            hl_group,
            line_num,
            pos.name[1],
            name_end
          )
          if ok then
            highlight_count = highlight_count + 1
          end
        end
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
        if found then
          return found
        end
      end
    end
  end
  return search(state.symbols)
end

local function jump_to_symbol(preview_only)
  local line = api.nvim_win_get_cursor(state.winnr)[1]
  local symbol = state.line_to_symbol and state.line_to_symbol[line]

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
    vim.cmd("wincmd w")
    vim.cmd("edit " .. vim.fn.fnameescape(state.file_path))
    target_win = api.nvim_get_current_win()
  end

  -- Jump to position
  api.nvim_win_set_cursor(target_win, {
    symbol.range.start.line + 1,
    symbol.range.start.character,
  })

  -- Center the view
  vim.cmd("normal! zz")

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

  if state.mode == "tree" then
    -- Use the line mapping instead of find_symbol_at_line
    local symbol = state.line_to_symbol and state.line_to_symbol[line]
    if symbol and symbol.children and #symbol.children > 0 then
      local key = symbol.range.start.line .. ":" .. symbol.name
      state.folded[key] = not state.folded[key]

      -- Save fold state if memory enabled
      if config.fold.enable_memory and fold_memory then
        fold_memory.save(state.file_path, state.folded)
      end

      render()
      api.nvim_win_set_cursor(state.winnr, { line, 0 })
    end
  else -- type mode
    -- Find which category this line belongs to
    local lines = api.nvim_buf_get_lines(state.bufnr, line - 1, line, false)
    if #lines > 0 then
      local line_text = lines[1]
      -- Check if it's a category header by looking for the pattern
      local pattern = "^[^%s]+ (%w+) %((%d+)%)"
      local kind_name = line_text:match(pattern)
      if kind_name then
        local key = "type:" .. kind_name
        state.folded[key] = not state.folded[key]

        if config.fold.enable_memory and fold_memory then
          fold_memory.save(state.file_path, state.folded)
        end

        render()
        api.nvim_win_set_cursor(state.winnr, { line, 0 })
      end
    end
  end
end

local function switch_mode()
  state.mode = state.mode == "tree" and "type" or "tree"
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
  if state.mode == "tree" then
    local function mark_folded(symbols)
      for _, symbol in ipairs(symbols) do
        if symbol.children and #symbol.children > 0 then
          local key = symbol.range.start.line .. ":" .. symbol.name
          state.folded[key] = true
          mark_folded(symbol.children)
        end
      end
    end
    mark_folded(state.symbols)
  else -- type mode
    for kind_name, _ in pairs(state.symbols) do
      state.folded["type:" .. kind_name] = true
    end
  end

  if config.fold.enable_memory and fold_memory then
    fold_memory.save(state.file_path, state.folded)
  end
  render()
end

-- Keymaps
local function setup_keymaps()
  if not state.bufnr then
    return
  end

  local opts = { noremap = true, silent = true, buffer = state.bufnr }

  vim.keymap.set("n", config.keymaps.jump, function()
    jump_to_symbol(false)
  end, opts)
  vim.keymap.set("n", config.keymaps.preview, function()
    jump_to_symbol(true)
  end, opts)
  vim.keymap.set("n", config.keymaps.toggle_fold, toggle_fold, opts)
  vim.keymap.set("n", config.keymaps.switch_mode, switch_mode, opts)
  vim.keymap.set("n", config.keymaps.close, M.close, opts)
  vim.keymap.set("n", config.keymaps.expand_all, expand_all, opts)
  vim.keymap.set("n", config.keymaps.collapse_all, collapse_all, opts)
end

-- Public API
function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})

  -- Load fold memory if enabled
  if config.fold.enable_memory then
    local ok, mod = pcall(require, "vista-lite.fold-memory")
    if ok then
      fold_memory = mod
    end
  end
  -- Ensure autocmds are installed even if user never calls setup
  ensure_autocmds()
end

function M.open()
  ensure_autocmds()
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
    -- Mark the initially rendered buffer and tick
    local buf = state.source_bufnr
    if buf and api.nvim_buf_is_valid(buf) then
      state.rendered_bufnr = buf
      state.last_refresh[buf] = api.nvim_buf_get_changedtick(buf)
    end
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
    -- Check if this is the last window
    local win_count = #api.nvim_list_wins()
    if win_count == 1 then
      -- If it's the last window, just quit vim
      vim.cmd("quit")
    else
      -- Otherwise close the vista window
      api.nvim_win_close(state.winnr, true)
      state.winnr = nil
    end
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
