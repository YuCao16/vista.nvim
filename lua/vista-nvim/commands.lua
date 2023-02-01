local command = {}

local subcommands = {
    tree = function()
        if require("vista-nvim.view").is_win_open() then
            require("vista-nvim.writer").structure_theme = "tree"
            require("vista-nvim.handlers").update("lsp")
        else
            require("vista-nvim.writer").structure_theme = "tree"
            require("vista-nvim").open()
        end
    end,
    type = function()
        if require("vista-nvim.view").is_win_open() then
            require("vista-nvim.writer").structure_theme = "type"
            require("vista-nvim.handlers").update("lsp")
        else
            require("vista-nvim.writer").structure_theme = "type"
            require("vista-nvim").open()
        end
    end,
}

function command.command_list()
    return vim.tbl_keys(subcommands)
end

function command.load_command(cmd, ...)
    local args = { ... }
    subcommands[cmd]()
end

return command
