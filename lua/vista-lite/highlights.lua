local M = {}
local api = vim.api

-- Namespace for highlights
local ns = api.nvim_create_namespace("vista_lite")

-- Setup custom highlight groups
local function setup_highlights()
  -- Create custom highlight group for tree structure (markers and fold icons)
  api.nvim_set_hl(0, "VistaTreeStructure", { fg = "#ABB2BF" })
  -- Create a custom title highlight that's guaranteed to be visible
  api.nvim_set_hl(0, "VistaTitle", { fg = "#61AFEF", bold = true })
  -- Link flash highlight to Search for better visibility
  api.nvim_set_hl(0, "VistaFlashLine", { link = "Search" })
end

-- Initialize highlights on module load
setup_highlights()

-- Helper function to set extmark with proper end_col handling
local function set_extmark_highlight(bufnr, ns, line, start_col, end_col, hl_group)
  if end_col == -1 then
    -- Highlight to end of line
    api.nvim_buf_set_extmark(bufnr, ns, line, start_col, {
      end_line = line,
      hl_group = hl_group,
      hl_eol = true,
    })
  else
    api.nvim_buf_set_extmark(bufnr, ns, line, start_col, {
      end_col = end_col,
      hl_group = hl_group,
    })
  end
end

-- Treesitter-aligned highlight groups for symbol kinds
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
  [13] = "@variable.parameter", -- Variable
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

-- Apply highlights to buffer
function M.apply(bufnr, metadata, config)
  if not bufnr or not api.nvim_buf_is_valid(bufnr) then
    vim.notify("Buffer not valid for highlights", vim.log.levels.WARN)
    return
  end

  -- Clear existing highlights
  api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  -- Highlight title with our custom highlight
  if config.show_title then
    -- Get the first line to find its length
    local lines = api.nvim_buf_get_lines(bufnr, 0, 1, false)
    if #lines > 0 then
      local line_length = #lines[1]
      -- Use extmark with explicit end_col
      api.nvim_buf_set_extmark(bufnr, ns, 0, 0, {
        end_col = line_length,
        hl_group = "VistaTitle",
        priority = 100,  -- Ensure it's not overridden
      })
    end
  end

  -- Apply highlights based on line metadata
  local highlight_count = 0
  for line_num, line_metadata in pairs(metadata) do
    if line_metadata.is_category and line_metadata.positions then
      -- Highlight category headers (for type mode)
      local pos = line_metadata.positions
      if pos.fold then
        set_extmark_highlight(bufnr, ns, line_num, pos.fold[1], pos.fold[2], "VistaTreeStructure")
      end
      if pos.name then
        set_extmark_highlight(bufnr, ns, line_num, pos.name[1], pos.name[2], "Type")
      end
    elseif line_metadata.positions then
      local pos = line_metadata.positions

      -- Highlight indent guides (connector)
      if pos.connector and config.indent_guides.enable then
        set_extmark_highlight(
          bufnr,
          ns,
          line_num,
          pos.connector[1],
          pos.connector[2],
          "VistaTreeStructure"
        )
      end

      -- Highlight fold icons
      if line_metadata.has_children and pos.fold then
        set_extmark_highlight(bufnr, ns, line_num, pos.fold[1], pos.fold[2], "VistaTreeStructure")
      end

      -- Highlight based on symbol kind
      if line_metadata.kind then
        local hl_group = kind_highlights[line_metadata.kind] or "Identifier"

        if pos.icon then
          -- Icon exists, color only the icon
          local ok =
            pcall(set_extmark_highlight, bufnr, ns, line_num, pos.icon[1], pos.icon[2], hl_group)
          if ok then
            highlight_count = highlight_count + 1
          end
        elseif pos.name then
          -- No icon, color the first few characters of the name to simulate an "icon"
          local name_end = pos.name[1] + 3 -- Color first 3 chars
          local ok =
            pcall(set_extmark_highlight, bufnr, ns, line_num, pos.name[1], name_end, hl_group)
          if ok then
            highlight_count = highlight_count + 1
          end
        end
      end

      -- Highlight line number
      if pos.line_num then
        set_extmark_highlight(bufnr, ns, line_num, pos.line_num[1], pos.line_num[2], "Comment")
      end
    end
  end

  return highlight_count
end

-- Clear all highlights
function M.clear(bufnr)
  if bufnr and api.nvim_buf_is_valid(bufnr) then
    api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  end
end

-- Get namespace ID
function M.get_namespace()
  return ns
end

-- Update kind highlights mapping (for customization)
function M.set_kind_highlight(kind, hl_group)
  kind_highlights[kind] = hl_group
end

-- Get all kind highlights
function M.get_kind_highlights()
  return vim.deepcopy(kind_highlights)
end

-- Re-setup highlights (useful when colorscheme changes)
function M.setup()
  setup_highlights()
end

return M
