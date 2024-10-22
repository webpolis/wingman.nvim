vim.api.nvim_create_user_command("Wingman", require("wingman").start, {})
vim.api.nvim_create_user_command("WingmanCollect", require("wingman").collect, {})
