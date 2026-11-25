--[[
	tests/lint.lua — structural checks, each of which must first fail on a fixture.

	Two rules here exist because balanced-paren checks are not enough:
	  * bare identifier pairs (`foo Bar(1)` where a `.` or `,` went missing)
	  * jammed call chains (`x.InputEndedtrack(Connect)` — three compile errors
	    in a row once passed a "clean" lint because every bracket still balanced)

	Order of work is fixed: self-test the linter on tests/fixtures, and refuse to
	report on src/ unless every fixture produced the verdict it should.
]]

local lint = {}

lint.fixtures = {
	{ file = "tests/fixtures/clean.lua", code = "clean" },
	{ file = "tests/fixtures/broken_balance.lua", code = "balance" },
	{ file = "tests/fixtures/bare_identifiers.lua", code = "bare" },
	{ file = "tests/fixtures/jammed_call.lua", code = "bare" },
	{ file = "tests/fixtures/unterminated_string.lua", code = "string" },
}

local KEYWORDS = {
	["and"] = true, ["break"] = true, ["do"] = true, ["else"] = true, ["elseif"] = true,
	["end"] = true, ["false"] = true, ["for"] = true, ["function"] = true, ["goto"] = true,
	["if"] = true, ["in"] = true, ["local"] = true, ["nil"] = true, ["not"] = true,
	["or"] = true, ["repeat"] = true, ["return"] = true, ["then"] = true, ["true"] = true,
	["until"] = true, ["while"] = true, ["continue"] = true,
}

local MULTI = { "...", "..", "==", "~=", "<=", ">=", "<<", ">>", "//", "::" }

-------------------------------------------------------------------- lexer ----

--- Returns tokens or nil, error. Tokens: { kind, value, line }.
function lint.tokenize(source)
	local tokens = {}
	local index, line = 1, 1
	local length = #source

	local function push(kind, value)
		tokens[#tokens + 1] = { kind = kind, value = value, line = line }
	end

	while index <= length do
		local char = source:sub(index, index)

		if char == "\n" then
			line = line + 1
			index = index + 1
		elseif char:match("%s") then
			index = index + 1
		elseif char == "-" and source:sub(index + 1, index + 1) == "-" then
			-- comment: long form --[[ ]] / --[==[ ]==] or to end of line
			local longOpen = source:match("^%-%-%[(=*)%[", index)
			if longOpen ~= nil then
				local close = "]" .. longOpen .. "]"
				local _, stop = source:find(close, index, true)
				if not stop then
					return nil, ("unterminated long comment at line %d"):format(line)
				end
				local body = source:sub(index, stop)
				line = line + select(2, body:gsub("\n", ""))
				index = stop + 1
			else
				local newline = source:find("\n", index, true)
				index = newline and newline or (length + 1)
			end
		elseif char == "-" and source:sub(index + 1, index + 1) == ">" then
			push("symbol", "->")
			index = index + 2
		elseif char == "[" and source:match("^%[(=*)%[", index) then
			local level = source:match("^%[(=*)%[", index)
			local close = "]" .. level .. "]"
			local _, stop = source:find(close, index, true)
			if not stop then
				return nil, ("unterminated long string at line %d"):format(line)
			end
			local body = source:sub(index, stop)
			line = line + select(2, body:gsub("\n", ""))
			push("string", body)
			index = stop + 1
		elseif char == '"' or char == "'" then
			local quote = char
			local startLine = line
			local cursor = index + 1
			local closed = false
			while cursor <= length do
				local inner = source:sub(cursor, cursor)
				if inner == "\\" then
					cursor = cursor + 2
				elseif inner == quote then
					closed = true
					cursor = cursor + 1
					break
				elseif inner == "\n" then
					line = line + 1
					cursor = cursor + 1
				else
					cursor = cursor + 1
				end
			end
			if not closed then
				return nil, ("unterminated string starting at line %d"):format(startLine)
			end
			push("string", source:sub(index, cursor - 1))
			index = cursor
		elseif char:match("%d") or (char == "." and source:sub(index + 1, index + 1):match("%d")) then
			local number = source:match("^0[xX]%x+", index) or source:match("^%d*%.?%d+[eE][%+%-]?%d+", index) or source:match("^%d*%.?%d*", index)
			push("number", number)
			index = index + #number
		elseif char:match("[%a_]") then
			local name = source:match("^[%a_][%w_]*", index)
			push(KEYWORDS[name] and "keyword" or "name", name)
			index = index + #name
		else
			local matched = nil
			for _, symbol in ipairs(MULTI) do
				if source:sub(index, index + #symbol - 1) == symbol then
					matched = symbol
					break
				end
			end
			if matched then
				push("symbol", matched)
				index = index + #matched
			else
				push("symbol", char)
				index = index + 1
			end
		end
	end

	return tokens
end

-------------------------------------------------------------------- rules ----

local OPENERS = { ["("] = ")", ["["] = "]", ["{"] = "}" }
local CLOSERS = { [")"] = "(", ["]"] = "[", ["}"] = "{" }

--- Bracket, block and keyword balance.
function lint.checkBalance(tokens)
	local stack = {}

	for _, token in ipairs(tokens) do
		local value = token.value
		if token.kind == "symbol" and OPENERS[value] then
			stack[#stack + 1] = { value = value, line = token.line }
		elseif token.kind == "symbol" and CLOSERS[value] then
			local top = stack[#stack]
			if not top or top.value ~= CLOSERS[value] then
				return { line = token.line, code = "balance", message = ("unexpected '%s'"):format(value) }
			end
			stack[#stack] = nil
		elseif token.kind == "keyword" then
			if value == "elseif" and stack[#stack] and stack[#stack].value == "then" then
				-- `elseif` continues the same block; drop the pending `then`
				stack[#stack] = nil
			elseif value == "function" or value == "do" or value == "then" or value == "repeat" then
				-- `then` is closed by a later `end`; counted as a block opener.
				stack[#stack + 1] = { value = value, line = token.line }
			elseif value == "end" or value == "until" then
				local wanted = value == "end" and { "function", "do", "then", "if", "for", "while" } or { "repeat" }
				local top = stack[#stack]
				local ok = false
				for _, candidate in ipairs(wanted) do
					if top and top.value == candidate then
						ok = true
						break
					end
				end
				if not ok then
					return { line = token.line, code = "balance", message = ("unmatched '%s'"):format(value) }
				end
				stack[#stack] = nil
			end
		end
	end

	if #stack > 0 then
		local top = stack[#stack]
		return { line = top.line, code = "balance", message = ("unclosed '%s'"):format(top.value) }
	end
	return nil
end

--- A NAME immediately followed by another NAME on the SAME LINE: a missing
--- separator. `frame.InputEnded track(Connect)` after a dropped dot, or
--- `local x = foo bar`.
---
--- Same-line only matters: two adjacent names split across a newline are
--- usually the tail of one statement and the head of the next, which is legal
--- and accounted for. Restricting the rule is only safe because both jammed
--- fixtures keep their pair on one line — remove that property from a fixture
--- and the rule can go quiet without anything noticing.
function lint.checkBareIdentifiers(tokens)
	local problems = {}
	for index = 1, #tokens - 1 do
		local here, next_token = tokens[index], tokens[index + 1]
		if here.kind == "name" and next_token.kind == "name" and here.line == next_token.line then
			problems[#problems + 1] = {
				line = next_token.line,
				code = "bare",
				message = ("'%s' jammed against '%s'"):format(here.value, next_token.value),
			}
		end
	end
	return problems
end

--- Constructs that compile in Lua 5.4 but not in Luau, or vice versa. Files
--- must sit in the intersection, because they run in both environments.
function lint.checkSubset(tokens)
	local problems = {}
	local BANNED = {
		["goto"] = "goto/labels are Lua 5.4 only",
		["::"] = "label syntax is Lua 5.4 only (Luau uses `::` for casts)",
		continue = "continue is Luau only",
	}

	for _, token in ipairs(tokens) do
		if token.kind == "keyword" and BANNED[token.value] then
			problems[#problems + 1] = { line = token.line, code = "subset", message = BANNED[token.value] }
		elseif token.kind == "symbol" and BANNED[token.value] then
			problems[#problems + 1] = { line = token.line, code = "subset", message = BANNED[token.value] }
		end
	end
	return problems
end

--- Everything at once. First offending code decides, so a fixture can assert one.
function lint.file(path)
	local handle = assert(io.open(path, "r"))
	local source = handle:read("a")
	handle:close()

	local tokens, err = lint.tokenize(source)
	if not tokens then
		return { { line = 0, code = "string", message = err } }
	end

	local problems = {}
	local balance = lint.checkBalance(tokens)
	if balance then
		problems[#problems + 1] = balance
	end
	for _, problem in ipairs(lint.checkBareIdentifiers(tokens)) do
		problems[#problems + 1] = problem
	end
	for _, problem in ipairs(lint.checkSubset(tokens)) do
		problems[#problems + 1] = problem
	end
	return problems
end

function lint.codes(problems)
	local seen = {}
	for _, problem in ipairs(problems) do
		seen[problem.code] = true
	end
	return seen
end

---------------------------------------------------------------- self-test ----

--- Runs the fixtures. Returns ok, report lines.
function lint.selfTest()
	local lines = {}
	local ok = true

	for _, fixture in ipairs(lint.fixtures) do
		local problems = lint.file(fixture.file)
		local seen = lint.codes(problems)

		if fixture.code == "clean" then
			if #problems == 0 then
				lines[#lines + 1] = ("ok    %s produced no findings"):format(fixture.file)
			else
				ok = false
				lines[#lines + 1] = ("BROKEN %s should be clean, got %d finding(s)"):format(fixture.file, #problems)
			end
		elseif seen[fixture.code] then
			lines[#lines + 1] = ("ok    %s tripped '%s'"):format(fixture.file, fixture.code)
		else
			ok = false
			lines[#lines + 1] = ("BROKEN %s did not trip '%s'"):format(fixture.file, fixture.code)
		end
	end

	return ok, lines
end

------------------------------------------------------------------- command ----

local function collect(dir, out)
	local pipe = io.popen(('find %s -name "*.lua" -type f | sort'):format(dir))
	if not pipe then
		error("cannot list " .. dir)
	end
	for line in pipe:lines() do
		out[#out + 1] = line
	end
	pipe:close()
	return out
end

if arg and arg[0] and arg[0]:match("lint%.lua$") then
	local ok, lines = lint.selfTest()
	print("linter self-test:")
	for _, line in ipairs(lines) do
		print("  " .. line)
	end
	if not ok then
		print("\nlinter is not trustworthy — refusing to scan src/")
		os.exit(1)
	end

	local files = collect("src", {})
	local findings = 0
	for _, file in ipairs(files) do
		for _, problem in ipairs(lint.file(file)) do
			findings = findings + 1
			print(("%s:%d  [%s] %s"):format(file, problem.line, problem.code, problem.message))
		end
	end

	print(("\n%d file(s) scanned, %d finding(s)"):format(#files, findings))
	os.exit(findings == 0 and 0 or 1)
end

return lint
