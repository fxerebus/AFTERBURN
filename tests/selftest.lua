--[[
	selftest.lua — proves the machinery can fail before anything trusts it.

	Two levels: the linter must trip every fixture, and the harness loader must
	refuse to compile the broken ones. A suite that cannot fail is not a check.
]]

package.path = "./?.lua;" .. package.path

local harness = require("tests.harness")
local lint = require("tests.lint")

print("harness / linter self-test")

local ok, lines = lint.selfTest()
for _, line in ipairs(lines) do
	print("  " .. line)
end

local broken = 0

local function check(name, condition)
	if condition then
		print(("PASS  %s"):format(name))
	else
		broken = broken + 1
		print(("FAIL  %s"):format(name))
	end
end

check("every fixture produced its expected verdict", ok)

local chunk, err = loadfile("tests/fixtures/broken_balance.lua", "t", {})
check("harness loader rejects an unbalanced fixture", chunk == nil and err ~= nil)

local chunk2 = loadfile("tests/fixtures/clean.lua", "t", {})
check("harness loader accepts the clean fixture", chunk2 ~= nil)

if broken > 0 then
	print(("%d self-test failure(s)"):format(broken))
	os.exit(1)
end

print("self-test clean")
os.exit(0)
