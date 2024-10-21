local core = require("wingman.core")

---@class Config
---@field opt string Your config option
local config = {
	opt = "Hello!",
}

---@class MyModule
local M = {}

---@type Config
M._config = config

---@param args Config?
-- you can define your setup function here. Usually configurations can be merged, accepting outside params and
-- you can also put some validation here for those.
M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M._config, args or {})
end

M.config = M.setup

M.start = function()
	return core.parse()
end

return M
