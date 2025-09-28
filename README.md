# Vista-Lite

A minimal, fast LSP symbol viewer for Neovim. Rewritten from scratch to be simple and maintainable.

## Features

- =€ **Lightweight**: ~600 lines of code total
- =æ **LSP Only**: Focused on modern LSP integration
- <¨ **Mini.icons Support**: Beautiful icons with fallback
- =¾ **Fold Memory**: Persistent fold states across sessions
- <2 **Dual Modes**: Tree view and Type-grouped view
- ¡ **Fast**: No complex caching, direct rendering

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'liuchengxu/vista.nvim',
  branch = 'vista-lite',
  cmd = { 'Vista', 'VistaOpen', 'VistaFocus' },
  config = function()
    require('vista-lite').setup({
      width = 30,           -- number or "30%"
      position = 'left',    -- 'left' or 'right'
      auto_close = false,   -- close vista when jumping to symbol
      show_title = true,    -- show file name at top
      icons = {
        provider = 'mini',  -- 'mini', 'builtin', 'none'
      },
      fold = {
        enable_memory = true,   -- remember fold states
        save_on_close = true,   -- auto-save on close
      },
    })
  end,
}
```

## Commands

- `:Vista` - Toggle the symbol viewer
- `:VistaOpen` - Open the symbol viewer
- `:VistaClose` - Close the symbol viewer
- `:VistaFocus` - Focus the symbol viewer window
- `:VistaRefresh` - Refresh symbols from LSP

## Keybindings (in Vista window)

- `<CR>` - Jump to symbol
- `p` - Preview symbol (don't move focus)
- `o` - Toggle fold
- `s` - Switch between tree/type mode
- `q` - Close vista
- `zR` - Expand all
- `zr` - Collapse all

## Configuration

Full configuration example:

```lua
require('vista-lite').setup({
  width = 30,           -- fixed width, or...
  -- width = '25%',     -- percentage of window
  position = 'left',    -- or 'right'
  auto_close = false,   -- auto close on jump
  show_title = true,    -- show filename header

  icons = {
    provider = 'mini',  -- 'mini' (requires mini.icons)
                       -- 'builtin' (nerd font icons)
                       -- 'none' (no icons)
  },

  fold = {
    enable_memory = true,   -- save fold states
    save_on_close = true,   -- auto-save when closing
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
})
```

## Why Vista-Lite?

The original Vista.nvim grew to over 4600 lines of code with complex abstractions and features. Vista-Lite is a complete rewrite focusing on:

- **Simplicity**: One main file, clear code structure
- **Performance**: Direct rendering without complex caching
- **Maintainability**: Easy to understand and modify
- **Reliability**: Fewer moving parts = fewer bugs

## Requirements

- Neovim 0.8+ with LSP configured
- (Optional) [mini.icons](https://github.com/echasnovski/mini.icons) for better icons
- (Optional) Nerd Font for builtin icons

## License

MIT