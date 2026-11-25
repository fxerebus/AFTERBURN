-- Bare identifier fixture: two names jammed with no separator.
local function foo() return 1 end
local function bar() return 2 end

local x = foo bar
local y = bar foo()

return x, y
