local command = {}

local function tree_cmd()
  if require("vista-nvim.view").is_win_open() then
    require("vista-nvim.writer").structure_theme = "tree"
    require("vista-nvim.handlers.basic").current_theme = "tree"
    require("vista-nvim.handlers").update("lsp")
  elseif require("vista-nvim.view").View.bufnr == nil then
    require("vista-nvim.writer").structure_theme = "tree"
    require("vista-nvim.handlers.basic").current_theme = "tree"
    require("vista-nvim.config").theme = "tree"
    require("vista-nvim").toggle()
  else
    require("vista-nvim.writer").structure_theme = "tree"
    require("vista-nvim.handlers.basic").current_theme = "tree"
    require("vista-nvim").toggle()
    require("vista-nvim.handlers").update("lsp")
  end
end

local function type_cmd()
  if require("vista-nvim.view").is_win_open() then
    require("vista-nvim.writer").structure_theme = "type"
    require("vista-nvim.handlers.basic").current_theme = "type"
    require("vista-nvim.handlers").update("lsp")
  elseif require("vista-nvim.view").View.bufnr == nil then
    require("vista-nvim.writer").structure_theme = "type"
    require("vista-nvim.handlers.basic").current_theme = "type"
    require("vista-nvim.config").theme = "type"
    require("vista-nvim").toggle()
  else
    require("vista-nvim.writer").structure_theme = "type"
    require("vista-nvim.handlers.basic").current_theme = "type"
    require("vista-nvim").open()
    require("vista-nvim.handlers").update("lsp")
  end
end

local function status_cmd()
  local config = require("vista-nvim.config")
  local icons = require("vista-nvim.icons")

  local messages = {
    "=== Vista.nvim Status ===",
    "",
    "Icon Provider: " .. icons.get_provider_name(),
    "Icon Provider Available: " .. tostring(icons.has_icon_provider()),
    "Use Icons Provider: " .. tostring(config.use_icons_provider),
    "",
  }

  -- Test a few common icon kinds to show what's actually being used
  local test_kinds = { "Function", "Variable", "Class", "Method" }
  table.insert(messages, "Current Icons:")

  for _, kind in ipairs(test_kinds) do
    local icon, hl = icons.get_icon(kind)
    local source = "config"

    -- Check if this icon came from a provider
    if config.use_icons_provider then
      local ok, mini_icons = pcall(require, "mini.icons")
      if ok then
        local mini_icon, _ = mini_icons.get("lsp", kind)
        if mini_icon and mini_icon ~= "" and #mini_icon ~= 3 then
          source = "mini.icons"
        end
      end
    end

    table.insert(messages, string.format("  %s: %s (from %s)", kind, icon or "none", source))
  end

  table.insert(messages, "")
  table.insert(
    messages,
    "Current Theme: " .. (require("vista-nvim.writer").structure_theme or "unknown")
  )

  -- Display the status
  vim.notify(table.concat(messages, "\n"), vim.log.levels.INFO, {
    title = "Vista.nvim Status",
  })
end

local subcommands = {
  tree = tree_cmd,
  type = type_cmd,
  status = status_cmd,
}

function command.command_list()
  return vim.tbl_keys(subcommands)
end

function command.load_command(cmd, ...)
  local args = { ... }
  subcommands[cmd]()
end

return command
