local openai = require("openai")
local client = openai.new(
	os.getenv("OPENAI_API_KEY")
		or "sk-HM40uWYjTGBrmFSVRjoJ73yYUdy1Rq9mMxkKhX9oKXT3BlbkFJDcVGdH6dhsB7BqlrQXXyg3Xf1IFB316f7IkqMB0qEA"
)
local utils = require("wingman.utils")

local M = {}

local SYSTEM_PROMPT =
	[[You are a Senior Engineer with extensive experience in both backend and frontend development across various programming languages and frameworks, including React, Angular, Vue.js, Svelte, Node.js, Python, Java, C++, and Go. You excel in designing RESTful APIs and GraphQL services, and have expertise in blockchain and web3 development.
You stay current with trends for building efficient, scalable user interfaces using modern CSS and UI frameworks like TailwindCSS, ShadCN, Bootstrap, and Material-UI. Your skills include writing clean, maintainable TypeScript and JavaScript code.
You possess strong knowledge of database technologies (SQL: PostgreSQL, MySQL; NoSQL: MongoDB, Redis) and cloud services (AWS, Azure, Google Cloud Platform). Your problem-solving skills enable you to provide concise, actionable answers with source code for fixing issues or generating new features.
You are familiar with DevOps practices, including CI/CD, Docker, Kubernetes, and Terraform. Avoid redundant comments in code. Respond to inquiries with the necessary context, specifying affected files and only writing required changes.
Following is a list of file paths and relevant code snippets:
]]

function M.send_to_openai(final_output, popup)
	local initial_prompt = utils.split_string_by_newlines(SYSTEM_PROMPT)
	local messages = {}
	local extra_line_count = 0
	local popup_is_open = false

	for _, line in ipairs(initial_prompt) do
		table.insert(messages, { role = "system", content = line })
	end

	-- Add the final output and user question to the messages
	for _, line in ipairs(final_output) do
		table.insert(messages, { role = "user", content = line })
	end

	local accumulated_content = ""

	client:chat(messages, { stream = true, model = "gpt-4o-mini", temperature = 0.15 }, function(chunk)
		if not popup_is_open then
			popup:show()
			popup_is_open = true
			vim.api.nvim_win_set_option(popup.winid, "wrap", true)
		end

		if chunk.content and chunk.content ~= "" then
			print(chunk.content)
			-- Accumulate content
			accumulated_content = accumulated_content .. chunk.content

			-- Check for newlines to determine if we have a complete paragraph
			while true do
				local newline_pos = string.find(accumulated_content, "\n")
				if not newline_pos then
					break -- No more newlines found
				end

				-- Extract the paragraph up to the newline
				local paragraph = string.sub(accumulated_content, 1, newline_pos - 1)
				if paragraph ~= "" then
					vim.api.nvim_buf_set_lines(popup.bufnr, -1, -1, false, { paragraph })
					extra_line_count = extra_line_count + 1
				end

				-- Remove the processed paragraph from accumulated_content
				accumulated_content = string.sub(accumulated_content, newline_pos + 1)
			end

			-- Move the cursor to the end of the buffer
			local current_line_count = vim.api.nvim_buf_line_count(popup.bufnr)
			vim.api.nvim_win_set_cursor(popup.winid, { current_line_count, 0 })
		end
	end)
end

return M
