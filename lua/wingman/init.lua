local core = require("wingman.core")
local llm = require("wingman.llm")
local db_instance = require("wingman.db")

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
  print("New context added!")
	return core.parse(true)
end

M.reset = function()
	local symbols_db_path = vim.fn.stdpath("cache") .. "/wingman_symbols.db"
	local symbols_db = db_instance.get_instance(symbols_db_path)

	symbols_db:cleanup()

  print("Wingman has been cleaned up!")
end

return M
