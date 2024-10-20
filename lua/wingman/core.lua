local Popup = require("nui.popup")
local ts_utils = require("nvim-treesitter.ts_utils")
local api = vim.api
local pending_requests = 0
local symbol_set = {} -- To track unique symbols
local utils = require("wingman.utils")
local llm = require("wingman.llm")

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
						code = code_block,
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
			-- print(own_unique_key .. " " .. level)

			-- Check for duplicates before inserting
			if not symbol_set[own_unique_key] then
				table.insert(symbols, {
					name = name,
					line = start_row,
					end_line = end_row,
					path = file_path,
					code = own_code_block,
					type = "own_reference",
				})
				symbol_set[own_unique_key] = true -- Mark this symbol as added

				-- Increment pending requests counter
				pending_requests = pending_requests + 1

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

function M.print_symbols()
	get_symbols(function(symbols)
		-- Create a new buffer
		local buf = vim.api.nvim_create_buf(false, true)
		-- Set buffer options
		vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
		vim.api.nvim_buf_set_option(buf, "swapfile", false)

		local final_output = {}
		local file_contents = {}
		local ranges = {}
		local paths = {}
		symbol_set = {}
		pending_requests = 0

		table.sort(symbols, function(a, b)
			return a["path"] < b["path"]
		end)

		table.sort(symbols, function(a, b)
			return a["line"] < b["line"]
		end)

		for _, symbol in ipairs(symbols) do
			if string.sub(utils.get_relative_path(symbol.path), 1, 1) == "/" then
				goto continue
			end

			if not ranges[symbol.path] then
				ranges[symbol.path] = {}
				table.insert(paths, symbol.path)
				file_contents[symbol.path] = utils.lines_to_table(symbol.path)
			end

			local code_block = utils.split_string_by_newlines(symbol.code)

			table.insert(ranges[symbol.path], { symbol.line, symbol.line + #code_block })

			::continue::
		end

		for _, path in ipairs(paths) do
			local header = string.format("%s", utils.get_relative_path(path))

			table.insert(final_output, "")
			table.insert(final_output, header)
			table.insert(final_output, string.rep("=", #header))
			table.insert(final_output, "")

			for _, range in ipairs(utils.merge_ranges(ranges[path])) do
				local extracted_lines = utils.extract_ranges(file_contents[path], range)

				table.insert(final_output, "```")

				for _, line in ipairs(extracted_lines) do
					table.insert(final_output, line)
				end

				table.insert(final_output, "```")
				table.insert(final_output, "")
			end
		end

		utils.multi_line_input(function(user_input)
			local user_question = user_input or utils.load_user_input()
			local q = utils.split_string_by_newlines(user_question)

			for _, qline in ipairs(q) do
				table.insert(final_output, qline)
			end

			-- Set the lines in the buffer
			-- vim.api.nvim_buf_set_lines(buf, 0, -1, false, final_output)

			local popup = Popup({
				bufnr = buf,
				position = "50%",
				size = {
					width = 120,
					height = 60,
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
