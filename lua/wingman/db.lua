-- sqlite_wrapper.lua
local sqlite = require("sqlite.db")
local tbl = require("sqlite.tbl")

local SQLiteWrapper = {}
SQLiteWrapper.__index = SQLiteWrapper

--- Create a new SQLiteWrapper instance
---@param uri string: The database URI
function SQLiteWrapper:new(uri)
	local instance = sqlite({ uri = uri, opts = {} })

	setmetatable(instance, self)
	return instance
end

--- Create a new table in the database
---@param name string: The name of the table
---@param schema table: The schema of the table
function SQLiteWrapper:create_table(name, schema)
	local table_instance = tbl(name, schema)
	table_instance:set_db(self.db) -- Set the database object for the table
	self.db[name] = table_instance
end

--- Check if a record exists in a specified table
---@param table_name string: The name of the table
---@param condition table: A table containing the condition to check
---@return boolean: True if the record exists, false otherwise
function SQLiteWrapper:exists(table_name, condition)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
	local result = self.db[table_name]:where(condition)
	return result and next(result) ~= nil
end

--- Add a new record to a specified table
---@param table_name string: The name of the table
---@param row table: A table containing the record data
function SQLiteWrapper:add(table_name, row)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
	return self.db[table_name]:insert(row)
end

--- Get all records from a specified table
---@param table_name string: The name of the table
---@param q sqlite_query_select: A query to limit the number of entries returned
---@return table: A list of records
function SQLiteWrapper:get(table_name, q)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
	return self.db[table_name]:map(function(record)
		return record
	end, q)
end

--- Update a record by ID in a specified table
---@param table_name string: The name of the table
---@param id number: The ID of the record to update
---@param row table: A table containing the new data
function SQLiteWrapper:update_by_id(table_name, id, row)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
	self.db[table_name]:update({
		where = { id = id },
		set = row,
	})
end

--- Remove a record by ID in a specified table
---@param table_name string: The name of the table
---@param id number: The ID of the record to remove
function SQLiteWrapper:remove_by_id(table_name, id)
	if not self.db[table_name] then
		error("Table " .. table_name .. " does not exist.")
	end
	self.db[table_name]:remove({ id = id })
end

--- Cleanup the database file
function SQLiteWrapper:cleanup()
	vim.defer_fn(function()
		vim.loop.fs_unlink(self.uri)
	end, 40000)
end

return SQLiteWrapper
