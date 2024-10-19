-- lua/wingman/config.lua
local M = {}

M.max_length = 30 -- Default value

function M.set(user_config)
	if user_config and user_config.max_length then
		M.max_length = user_config.max_length
	end
end

return M
