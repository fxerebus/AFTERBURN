-- Balance fixture: one `end` is missing.
local M = {}

function M.go(flag)
	if flag then
		return 1
	end
	return 2

return M
