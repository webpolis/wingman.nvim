local Popup = require("nui.popup")
local ts_utils = require("nvim-treesitter.ts_utils")
local api = vim.api
local pending_requests = 0
local symbol_set = {} -- To track unique symbols
local utils = require("wingman.utils")
local llm = require("wingman.llm")
local db_instance = require("wingman.db")

local symbols_db_path = vim.fn.stdpath("cache") .. "/wingman_symbols.db"
local symbols_db = db_instance.get_instance(symbols_db_path)

local M = {}

local function request_document(req_type, client, name, line_number, start_col, symbols, callback)
	client.request("textDocument/" .. req_type, {
		textDocument = vim.lsp.util.make_text_document_params(),
		position = { line = line_number, character = start_col },
		context = { includeDeclaration = true },
	}, function(ref_err, refs)
		if ref_err then
			print(ref_err)
			return
		end

		if not refs or vim.tbl_isempty(refs) then
			-- print("No " .. req_type .. " found for symbol: " .. name)
			pending_requests = pending_requests - 1
			return
		end

		for _, _ref in ipairs(refs) do
			local uri = _ref.targetUri or _ref.uri
			local range = _ref.targetRange or _ref.range
			local ref_file_path = vim.uri_to_fname(uri) or ""
			local rel_path = utils.get_relative_path(ref_file_path)

			if string.sub(rel_path, 1, 1) == "/" or utils.starts_with_ignored_folder(rel_path) then
				goto continue
			end

			if ref_file_path then
				local code_block = utils.get_code_block_from_file(ref_file_path, range.start.line, range["end"].line)

				-- Create a unique key for the symbol
				local unique_key = string.format("%s:%d:%s", name, range.start.line, ref_file_path)

				-- Check for duplicates before inserting
				if not symbol_set[unique_key] then
					table.insert(symbols, {
						name = name,
						line = range.start.line,
						end_line = range["end"].line,
						path = ref_file_path,
						code = utils.escape(code_block),
						type = req_type,
					})
					symbol_set[unique_key] = true -- Mark this symbol as added
				end
			end

			::continue::
		end

		pending_requests = pending_requests - 1

		-- Call the callback if all requests are done
		if pending_requests == 0 then
			callback(symbols)
		end
	end)
end

local function get_symbols(callback)
	local bufnr = api.nvim_get_current_buf()
	local parser = vim.treesitter.get_parser(bufnr)
	local tree = parser:parse()[1]
	local root = tree:root()
	local client = utils.get_client()
	local symbols = {}

	if not client then
		print("No LSP clients attached")
		return
	end

	-- Function to recursively collect symbols
	local function collect_symbols(node, level)
		local name = ts_utils.get_node_text(node)[1]
		local start_row, start_col, end_row, end_col = node:range()

		if node:type() == "identifier" then
			if name == nil then
				return
			end

			local file_path = api.nvim_buf_get_name(bufnr)
			local own_code_block = utils.get_code_block_from_file(file_path, start_row, end_row)
			local own_unique_key = string.format("%s:%d:%s", name, start_row, file_path)

			symbols_db:remove_by_path("symbols", file_path)
			-- print(own_unique_key .. " " .. level)

			-- Check for duplicates before inserting
			if not symbol_set[own_unique_key] then
				table.insert(symbols, {
					name = name,
					line = start_row,
					end_line = end_row,
					path = file_path,
					code = utils.escape(own_code_block),
					type = "own_reference",
				})
				symbol_set[own_unique_key] = true -- Mark this symbol as added

				-- Increment pending requests counter
				pending_requests = pending_requests
				request_document("definition", client, name, start_row, start_col, symbols, callback)
				-- request_document("references", client, name, line_number, start_col, symbols, callback)
			end
		end

		level = level + 1
		for child in node:iter_children() do
			collect_symbols(child, level)
		end
	end

	collect_symbols(root, 0)

	-- If there are no pending requests, call the callback immediately
	if pending_requests == 0 then
		callback(symbols)
	end
end

function M.check_and_update_symbol(db, symbol)
	-- Define the condition to check for the existing record
	local condition = {
		path = symbol.path,
		name = symbol.name,
		-- line = symbol.line,
	}

	-- Check if the record exists
	if db:exists("symbols", condition) then
		-- Get the existing record
		local existing_records = db:get("symbols", { where = condition })

		if #existing_records > 0 then
			local existing_record = existing_records[1] -- Assuming unique records

			-- Update the record with the new code
			db:update_by_id("symbols", existing_record.id, { code = utils.escape(symbol.code) })

			return existing_record.id
		end
	else
		return db:add("symbols", symbol)
	end
end

function M.symbols_to_markdown(symbol_ids, symbols)
	local _symbols = symbols ~= nil and symbols or symbols_db:where("symbols", { id = symbol_ids })
	local ranges = {}
	local paths = {}
	local file_contents = {}
	local output = {}

	table.sort(_symbols, function(a, b)
		return a["path"] < b["path"]
	end)

	table.sort(_symbols, function(a, b)
		return a["line"] < b["line"]
	end)

	for _, symbol in ipairs(_symbols) do
		if string.sub(utils.get_relative_path(symbol.path), 1, 1) == "/" then
			goto continue
		end

		if not ranges[symbol.path] then
			ranges[symbol.path] = {}
			table.insert(paths, symbol.path)
			file_contents[symbol.path] = utils.lines_to_table(symbol.path)
		end

		local code_block = utils.split_string_by_newlines(utils.unescape(symbol.code))

		table.insert(ranges[symbol.path], { symbol.line, symbol.line + #code_block })

		::continue::
	end
	for _, path in ipairs(paths) do
		local header = string.format("%s", utils.get_relative_path(path))

		table.insert(output, "")
		table.insert(output, header)
		table.insert(output, string.rep("=", #header))
		table.insert(output, "")

		for _, range in ipairs(utils.merge_ranges(ranges[path])) do
			local extracted_lines = utils.extract_ranges(file_contents[path], range)

			table.insert(output, "```")

			for _, line in ipairs(extracted_lines) do
				table.insert(output, line)
			end

			table.insert(output, "```")
			table.insert(output, "")
		end
	end

	return output
end

function M.parse(collect)
	local symbols_schema = {
		id = true, -- Unique identifier for each symbol
		name = { "text", required = true }, -- Name of the symbol
		line = { "integer", required = true }, -- Starting line number
		end_line = { "integer", required = true }, -- Ending line number
		path = { "text", required = true }, -- File path
		code = { "text", required = true }, -- Code block
		type = { "text", required = true }, -- Type of the symbol
	}
	local collected_symbols_ids = {}

	symbols_db:create_table("symbols", symbols_schema)

	get_symbols(function(symbols)
		-- Create a new buffer
		local buf = vim.api.nvim_create_buf(false, true)
		-- Set buffer options
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "swapfile", false)

		local PROJ_FILES_PROMPT =
			[[Tell me which files in my repo are the most likely to **need changes** to solve the requests I make.
Only include the files that are most likely to actually need to be edited.
Don't include files that might contain relevant context, just files that will need to be changed.
]]
		local final_output =
			{ "Here are summaries of some files with code snippets present in my project.", PROJ_FILES_PROMPT }
		symbol_set = {}
		pending_requests = 0

		for _, symbol in ipairs(symbols) do
			if string.sub(utils.get_relative_path(symbol.path), 1, 1) == "/" then
				goto continue
			end

			local symbol_id = M.check_and_update_symbol(symbols_db, symbol)

			table.insert(collected_symbols_ids, symbol_id)

			::continue::
		end

		if collect then
			return
		end

		utils.multi_line_input(function(user_input)
			local user_question = user_input or utils.load_user_input()
			local q = utils.split_string_by_newlines(user_question)

			-- Extract the additional references
			local md_links = utils.extract_md_links(user_question)

			if #md_links > 0 then
				for _, link in ipairs(md_links) do
					local ref_symbols_by_name = symbols_db:get("symbols", { contains = { name = link["text"] } })
					local ref_symbols_by_path = symbols_db:get("symbols", { contains = { path = "*" .. link["url"] } })
					local ref_symbols = utils.table_concat(ref_symbols_by_name, ref_symbols_by_path)
					-- local additional_context = M.symbols_to_markdown(nil, ref_symbols)
					-- final_output = utils.table_concat(final_output, additional_context)
					for _, symbol in ipairs(ref_symbols) do
						collected_symbols_ids[#collected_symbols_ids + 1] = symbol["id"]
					end
				end
			end

			final_output = utils.table_concat(final_output, M.symbols_to_markdown(collected_symbols_ids))
			final_output[#final_output + 1] = "ONLY EVER RETURN CODE IN A *SEARCH/REPLACE BLOCK*!"
			final_output[#final_output + 1] = ""

			for _, qline in ipairs(q) do
				table.insert(final_output, qline)
			end

			local tmp_path = vim.fn.stdpath("cache") .. "/wingman_final.out"
			local tmp_file = io.open(tmp_path, "w")

			if tmp_file ~= nil then
				tmp_file:write(llm.SYSTEM_PROMPT)
				for _, line in ipairs(final_output) do
					tmp_file:write(line .. "\n")
				end
				tmp_file:close()
			end

			local popup = Popup({
				bufnr = buf,
				position = "100%",
				anchor = "SW",
				size = {
					width = 80,
					height = 45,
				},
				enter = true,
				focusable = true,
				zindex = 50,
				relative = "editor",
				border = {
					padding = {
						top = 2,
						bottom = 2,
						left = 3,
						right = 3,
					},
					style = "rounded",
					text = {
						top = "< [Wingman]  Model response >",
						top_align = "center",
						bottom = "< Press <Esc> to close >",
						bottom_align = "center",
					},
				},
				buf_options = {
					modifiable = true,
					readonly = false,
				},
				win_options = {
					winblend = 10,
					winhighlight = "Normal:Normal,FloatBorder:FloatBorder",
				},
			})

			popup:map("n", "<esc>", function()
				popup:hide()
				popup:unmount()
			end, { noremap = true })

			popup:map("n", "<CR>", function() end, { noremap = true })

			llm.send_to_openai(final_output, popup)

			-- Move the cursor to the end of the buffer
			local line_count = vim.api.nvim_buf_line_count(buf)
			vim.api.nvim_win_set_cursor(popup.winid, { line_count, 0 })
		end)
	end)
end

return M
