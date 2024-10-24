vim.api.nvim_create_user_command("Wingman", require("wingman").start, {})
vim.api.nvim_create_user_command("WingmanCollect", require("wingman").collect, {})
vim.api.nvim_create_user_command("WingmanClean", require("wingman").reset, {})
