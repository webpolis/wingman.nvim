local core = require("wingman.core")
local llm = require("wingman.llm")

---@class Config
---@field opt string Your config option
local config = {
	openai_api_key = os.getenv("OPENAI_API_KEY"),
}

---@class MyModule
local M = {}

---@type Config
M.config = config

---@param args Config?
M.setup = function(args)
	M.config = vim.tbl_deep_extend("force", M.config, args or {})
end

M.start = function()
	llm.init_client(M.config)

	return core.parse()
end

M.collect = function()
	return core.parse(true)
end

return M
