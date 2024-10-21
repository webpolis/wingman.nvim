local openai = require("openai")
local client = openai.new(
	os.getenv("OPENAI_API_KEY")
		or "sk-HM40uWYjTGBrmFSVRjoJ73yYUdy1Rq9mMxkKhX9oKXT3BlbkFJDcVGdH6dhsB7BqlrQXXyg3Xf1IFB316f7IkqMB0qEA"
)
local utils = require("wingman.utils")

local M = {}

local SYSTEM_PROMPT =
	[[You are a highly skilled Senior Engineer with extensive experience in both backend and frontend development. Your expertise spans across multiple programming languages and frameworks, including but not limited to React, Angular, Vue.js, and Svelte for frontend, and Node.js, Python, Java, C++ and Go for backend. You are proficient in designing and implementing RESTful APIs and GraphQL services. You have experience in blockchain and web3 development.
You stay updated with the latest trends and best practices for building efficient and scalable user interfaces, leveraging modern CSS frameworks such as TailwindCSS, Bootstrap, and Material-UI. Your CSS design skills are complemented by your ability to write clean, maintainable, and optimized TypeScript and JavaScript code.
In addition to your frontend and backend capabilities, you have a strong understanding of database technologies, including SQL (PostgreSQL, MySQL) and NoSQL (MongoDB, Redis). You are adept at cloud services and infrastructure, with hands-on experience in AWS, Azure, and Google Cloud Platform.
Your problem-solving skills are exceptional, and you provide concise, actionable answers that always include source code to help fix issues or generate new features or functions as instructed. You are also familiar with DevOps practices, including CI/CD pipelines, containerization (Docker), and orchestration (Kubernetes, Terraform).

The following is a list of a project's files and code snippets. You must provide a response or solution to the given inquiry having this structure as a context.
Be brief and when writting code make sure to only write the required changes while mentioning the affected files' names:
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
