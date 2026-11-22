-- HyprDora's additions to LazyVim.
return {
    -- QML, through the language server that comes with Qt.
    {
        "neovim/nvim-lspconfig",
        opts = {
            servers = {
                qmlls = { cmd = { "/usr/lib64/qt6/bin/qmlls" }, mason = false },
            },
        },
    },
    {
        "nvim-treesitter/nvim-treesitter",
        opts = { ensure_installed = { "qmljs" } },
    },

    -- A whole commit or branch at once: the changed files beside their differences.
    {
        "sindrets/diffview.nvim",
        cmd = { "DiffviewOpen", "DiffviewFileHistory" },
        keys = {
            {
                "<leader>gv",
                function()
                    if require("diffview.lib").get_current_view() then
                        vim.cmd("DiffviewClose")
                    else
                        vim.cmd("DiffviewOpen")
                    end
                end,
                desc = "Diffview: changes (again: close)",
            },
            { "<leader>gV", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: this file's history" },
        },
    },
}
