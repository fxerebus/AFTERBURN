-- Clean fixture: must produce no findings.
local AB = AB or _G.AFTERBURN

local M = {}

local ORDER = { "one", "two" }

function M.build(name, total)
	local record = { name = name, total = total or #ORDER }
	for index, value in ipairs(ORDER) do
		record[index] = value
	end
	return record
end

return M
