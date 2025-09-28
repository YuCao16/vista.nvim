# Vista.nvim

A powerful symbol viewer & outliner for Neovim, written in Lua.

Vista.nvim provides a tree-like view of symbols in your code, supporting LSP and Markdown. It helps you navigate and understand code structure with ease.

## Features

- 🚀 **LSP Integration**: Full support for Language Server Protocol symbols
- 📝 **Markdown Support**: Outline view for Markdown documents
- 🎨 **Multiple Themes**: Choose between `tree` or `type` layout styles
- 🔧 **Highly Configurable**: Customize appearance, behavior, and keybindings
- 🎯 **Symbol Filtering**: Blacklist unwanted symbols per filetype
- 📏 **Flexible Layout**: Position on left or right, adjustable width
- ⚡ **Performance**: Optimized for large files with size/line limits

## Requirements

- Neovim >= 0.5.0
- LSP server configured (for LSP support)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yucao16/vista.nvim",
  config = function()
    require("vista-nvim").setup({
      -- your configuration here
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'yucao16/vista.nvim',
  config = function()
    require('vista-nvim').setup({
      -- your configuration here
    })
  end
}
```

## Configuration

### Default Configuration

```lua
require("vista-nvim").setup({
  -- Window settings
  width = 30,                    -- Width of the vista window
  side = "right",                 -- Position: "left" or "right"
  border = "rounded",             -- Border style
  show_title = true,              -- Show title in vista window

  -- Display settings
  theme = "type",                 -- Layout theme: "tree" or "type"
  show_guides = true,             -- Show indent guides
  show_symbol_details = true,     -- Show symbol details
  highlight_hovered_item = true,  -- Highlight item under cursor

  -- Behavior settings
  auto_close = false,             -- Auto close vista when last window
  auto_preview = false,           -- Auto preview symbol location
  auto_unfold_hover = false,      -- Auto unfold when hovering

  -- Folding settings
  autofold_depth = 2,             -- Auto fold depth level
  fold_markers = { "", "" },    -- Fold/unfold markers
  theme_markers = { "🆃 ", "🅲 " }, -- Theme indicators

  -- Performance settings
  disable_max_lines = 10000,     -- Disable for files with more lines
  disable_max_sizes = 2000000,   -- Disable for files larger than 2MB

  -- Provider settings
  default_provider = "lsp",       -- Default provider: "lsp" or "markdown"
  lsp_blacklist = { "pyright", "null-ls" }, -- Blacklisted LSP clients

  -- Keybindings
  disable_default_keybindings = false,
  bindings = {
    -- Add custom keybindings here
  },

  -- Symbol blacklist (global)
  type_symbol_blacklist = {
    "Variable", "Constant", "String",
    "Number", "Boolean", "Array", "Package"
  },

  -- Per-filetype configuration
  filetype_map = {
    python = {
      provider = "lsp",
      symbol_blacklist = { "Module" },
      type_symbol_blacklist = { "Module" },
    },
    lua = {
      provider = "lsp",
      symbol_blacklist = {
        "Variable", "Constant", "String",
        "Number", "Boolean", "Array", "Package",
      },
      type_symbol_blacklist = {
        "Variable", "Constant", "String",
        "Number", "Boolean", "Array", "Package",
      },
    },
    -- Add more filetype configurations...
  },

  -- Symbol icons and highlights
  symbols = {
    Method = { icon = "󰆧", hl = "@Method" },
    Function = { icon = "󰊕", hl = "@Function" },
    Constructor = { icon = "", hl = "@Constructor" },
    Field = { icon = "󰜢", hl = "@Field" },
    Variable = { icon = "󰀫", hl = "@Constant" },
    Class = { icon = "󰠱", hl = "@Type" },
    Interface = { icon = "", hl = "@Type" },
    Module = { icon = "", hl = "@namespace" },
    Property = { icon = "󰜢", hl = "@Method" },
    Enum = { icon = "", hl = "@Type" },
    Struct = { icon = "󰙅", hl = "@Type" },
    -- ... more symbols
  },
})
```

## Commands

Vista.nvim provides several commands to control the symbol viewer:

| Command | Description |
|---------|-------------|
| `:VistaNvimOpen` | Open the vista window |
| `:VistaNvimClose` | Close the vista window |
| `:VistaNvimToggle` | Toggle the vista window |
| `:VistaNvimFocus` | Focus the vista window |
| `:VistaNvimResize <width>` | Resize the vista window |
| `:VistaNvim <subcommand>` | Run various subcommands |

## Default Keybindings

When the vista window is focused:

| Key | Action |
|-----|--------|
| `q` | Close vista window |
| `Q` | Destroy vista window and cleanup |
| `<CR>` | Jump to symbol location |
| `o` | Toggle fold |
| `O` | Toggle all folds |
| `p` | Preview symbol location |

## Themes

Vista.nvim supports two layout themes:

### Tree Theme
Displays symbols in a hierarchical tree structure, showing the relationships between parent and child elements.

```
▾ Class: MyClass
  ▾ Method: __init__
    Variable: self.value
  ▸ Method: process
```

### Type Theme
Groups symbols by their type (functions, classes, variables, etc.), making it easier to find specific kinds of symbols.

```
▾ Classes
  MyClass
  AnotherClass
▾ Functions
  process_data
  calculate_result
▾ Variables
  config
  settings
```

## LSP Support

Vista.nvim automatically detects and uses your configured LSP servers. To ensure proper functionality:

1. Make sure you have LSP servers configured for your languages
2. Vista will use the active LSP client for the current buffer
3. You can blacklist specific LSP clients in the configuration

## Markdown Support

For Markdown files, Vista.nvim provides an outline based on headings:

```markdown
# Title           -> Level 1
## Section        -> Level 2
### Subsection    -> Level 3
```

## Performance Optimization

Vista.nvim includes several performance optimizations:

- **File size limits**: Automatically disables for very large files
- **Line count limits**: Skips files with too many lines
- **Lazy loading**: Only processes visible symbols
- **Smart updates**: Updates only when necessary

## API

You can programmatically control Vista.nvim:

```lua
-- Open vista
require("vista-nvim").open()

-- Close vista
require("vista-nvim").close()

-- Toggle vista
require("vista-nvim").toggle()

-- Focus vista window
require("vista-nvim").focus()

-- Resize vista window
require("vista-nvim").resize(40)

-- Check if vista is open
local is_open = require("vista-nvim").is_open()
```

## Troubleshooting

### Vista doesn't show symbols
- Ensure LSP is properly configured and running (`:LspInfo`)
- Check if the filetype is supported
- Verify the file isn't exceeding size/line limits

### Symbols are not updating
- Try manually refreshing with `:VistaNvimOpen`
- Check if LSP client is not blacklisted

### Performance issues
- Adjust `disable_max_lines` and `disable_max_sizes` settings
- Consider blacklisting unnecessary symbol types
- Reduce `autofold_depth` for files with many symbols

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## TODO

- [x] Implement a loading page
- [x] Title change while width change
- [ ] Implement set_all_fold for type
- [ ] Implement preview
- [ ] Implement detail
- [ ] Quit all Vista window within current tabpage
- [ ] Predefinable fold class for 'nvim.lsp' type layout
- [ ] Memorable fold
- [ ] Implement universal-ctags, with source switch
- [ ] Implement treesitter, with source switch
- [ ] Move general way to setting key bindings
- [ ] Make first line foldable (Optional)

## License

MIT License - see [LICENSE](LICENSE) for details

## Acknowledgments

- Inspired by [tagbar](https://github.com/preservim/tagbar) and [vista.vim](https://github.com/liuchengxu/vista.vim)
- Built with love for the Neovim community