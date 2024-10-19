-- lua/wingman/utils.lua
local Path = require("plenary.path")

local ignored_folders = {
	-- JavaScript/Node.js
	"node_modules",
	".npm",
	".yarn",
	".yarn-cache",
	".yarn-integrity",
	".pnp", -- Yarn Plug'n'Play

	-- Python
	"__pycache__",
	".venv",
	"venv",
	"env",
	"envs",
	".mypy_cache",
	".pytest_cache",
	".tox",
	"*.egg-info",

	-- Java
	"target",
	"*.jar",
	"*.war",
	".gradle",
	".idea", -- IntelliJ IDEA project files

	-- C/C++
	"build",
	"bin",
	"obj",
	"CMakeFiles",

	-- Rust
	"target",
	"Cargo.lock",

	-- Go
	"bin",
	"pkg",
	"vendor",

	-- Ruby
	".bundle",
	"vendor/bundle",

	-- PHP
	"vendor",

	-- Haskell
	".stack-work",

	-- Dart/Flutter
	"pubspec.lock",
	".dart_tool",

	-- Elixir/Erlang
	"_build",
	"deps",
	"*.ez",

	-- Lua
	"luarocks",

	-- Swift
	".build",
	"*.xcodeproj",
	"*.xcworkspace",

	-- Kotlin
	".gradle",
	"build",

	-- Miscellaneous
	"dist",
	"out",
	".DS_Store", -- macOS system file
	".vscode", -- Visual Studio Code settings
	".idea", -- IntelliJ IDEA settings
	".git", -- Git version control
	".hg", -- Mercurial version control
	".svn", -- Subversion version control
	".terraform", -- Terraform state files
	".next", -- Next.js build output
	".nuxt", -- Nuxt.js build output
	".expo", -- Expo for React Native
	".angular", -- Angular build output
	".svelte-kit", -- SvelteKit build output
}

local M = {}

function M.print_summary(tbl)
	if type(tbl) ~= "table" then
		print("Provided argument is not a table.")
		return
	end

	print("Summary of table:")
	for key, value in pairs(tbl) do
		if type(value) == "table" then
			print(string.format("  %s: table (contains %d keys)", key, #value))
		else
			print(string.format("  %s: %s", key, value))
		end
	end
end

function M.starts_with_ignored_folder(path)
	for _, folder in ipairs(ignored_folders) do
		if string.sub(path, 1, #folder) == folder then
			return true
		end
	end
	return false
end

function M.get_relative_path(absolute_path)
	local project_root = vim.fn.getcwd()

	return Path:new(absolute_path):make_relative(project_root)
end

function M.lines_to_table(filename)
	local lines = {}
	for line in io.lines(filename) do
		table.insert(lines, line)
	end
	return lines
end

function M.split_string_by_newlines(input_string)
	local lines = {}
	for line in string.gmatch(input_string, "[^\r\n]+") do
		table.insert(lines, line)
	end
	return lines
end

function M._get(root, paths)
	local c = root
	for _, path in ipairs(paths) do
		if not c[path] then
			return nil
		end
	end
	return c
end

function M.get_client()
	for _, client in pairs(vim.lsp.get_clients({ bufnr = 0 })) do
		if
			M._get(client.server_capabilities, { "documentSymbolProvider", "referencesProvider", "definitionProvider" })
		then
			return client
		end
	end
	return nil
end

function M.get_code_block_from_file(file_path, start_line, end_line)
	local code_block

	-- Create a new buffer for the specified file
	local temp_bufnr = vim.fn.bufadd(file_path)
	vim.fn.bufload(temp_bufnr) -- Load the buffer

	-- Set the buffer to be hidden
	vim.api.nvim_buf_set_option(temp_bufnr, "buflisted", false) -- Prevent the buffer from being listed
	vim.api.nvim_buf_set_option(temp_bufnr, "modifiable", false) -- Make the buffer read-only
	vim.api.nvim_buf_set_option(temp_bufnr, "bufhidden", "wipe") -- Automatically delete when hidden

	-- Get the parser for the newly created buffer
	local parser = vim.treesitter.get_parser(temp_bufnr)
	local tree = parser:parse()[1]
	local root = tree:root()

	-- Instead of using get_node_at_cursor, find the node directly from the tree
	local node_at_position = root:named_descendant_for_range(start_line, 0, end_line, 0)

	-- Check if node_at_position is valid
	if node_at_position == nil then
		print("Error: node_at_position is nil")
		return
	end

	code_block = vim.treesitter.get_node_text(node_at_position, temp_bufnr)

	return code_block
end

function M.merge_ranges(ranges)
	-- Sort the ranges by the starting number
	table.sort(ranges, function(a, b)
		return a[1] < b[1]
	end)

	local merged = {}
	local current_range = ranges[1]

	for i = 2, #ranges do
		local next_range = ranges[i]

		-- Check if the current range overlaps with the next range
		if current_range[2] >= next_range[1] then
			-- Merge the ranges by taking the higher end
			current_range[2] = math.max(current_range[2], next_range[2])
		else
			-- No overlap, add the current range to the merged list
			table.insert(merged, current_range)
			current_range = next_range
		end
	end

	-- Add the last range
	table.insert(merged, current_range)

	return merged
end

function M.extract_ranges(source_table, range)
	local extracted = {}
	local start_idx = range[1]
	local end_idx = range[2]

	-- Adjust end index if it exceeds the length of the source table
	if end_idx > #source_table then
		end_idx = #source_table
	end

	-- Extract the elements from the source table
	for i = start_idx + 1, end_idx do -- +1 because Lua uses 1-based indexing
		table.insert(extracted, source_table[i])
	end

	return extracted
end

return M
