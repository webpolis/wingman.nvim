local sqlite = require("sqlite.db")
local tbl = require("sqlite.tbl")

local SQLiteWrapper = {}
SQLiteWrapper.__index = SQLiteWrapper

local instance = nil

function SQLiteWrapper:new(uri)
	if not instance then
		instance = setmetatable({ db = sqlite({ uri = uri, opts = {} }) }, self)
	end
	return instance
end

function SQLiteWrapper:create_table(name, schema)
	local table_instance = tbl(name, schema)
	table_instance:set_db(self.db)
	self.db[name] = table_instance
end

function SQLiteWrapper:check_table_exists(table_name)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
end

function SQLiteWrapper:exists(table_name, condition)
	self:check_table_exists(table_name)
	local result = self.db[table_name]:where(condition)
	return result and next(result) ~= nil
end

function SQLiteWrapper:add(table_name, row)
	self:check_table_exists(table_name)
	return self.db[table_name]:insert(row)
end

function SQLiteWrapper:get(table_name, condition)
	self:check_table_exists(table_name)
	return self.db[table_name]:get(condition)
end

function SQLiteWrapper:where(table_name, condition)
	self:check_table_exists(table_name)
	return self.db[table_name]:get({ where = condition })
end

function SQLiteWrapper:update_by_id(table_name, id, row)
	self:check_table_exists(table_name)
	self.db[table_name]:update({ where = { id = id }, set = row })
end

function SQLiteWrapper:remove_by_id(table_name, id)
	self:check_table_exists(table_name)
	self.db[table_name]:remove({ id = id })
end

function SQLiteWrapper:cleanup()
	vim.defer_fn(function()
		vim.loop.fs_unlink(self.uri)
	end, 40000)
end

return {
	get_instance = function(uri)
		return SQLiteWrapper:new(uri)
	end,
}
