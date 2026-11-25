--[[
	run_all.lua — the whole suite, ordered so that nothing is trusted early.

	1. self-test (can the checks fail at all?)
	2. linter over src/
	3. theme, layout, navigation, build
	Non-zero exit on any failure, for CI and for the VS Code launch config.
]]

package.path = "./?.lua;" .. package.path

local harness = require("tests.harness")

print("AFTERBURN check suite")

-- The self-test runs in-process: the linter must trip every fixture, and the
-- loader must refuse to compile the broken ones, before src/ is scanned.
local brokenFixture, brokenError = loadfile("tests/fixtures/broken_balance.lua", "t", {})
local cleanFixture = loadfile("tests/fixtures/clean.lua", "t", {})
harness.test("loader rejects a broken fixture", function()
	harness.expect(brokenFixture == nil and brokenError ~= nil)
end)
harness.test("loader accepts the clean fixture", function()
	harness.expect(cleanFixture ~= nil)
end)

local lint = require("tests.lint")
local lintOk, lines = lint.selfTest()
for _, line in ipairs(lines) do
	print("  lint " .. line)
end
if lintOk then
	local pipe = io.popen('find src -name "*.lua" -type f | sort')
	local findings = 0
	for file in pipe:lines() do
		findings = findings + #lint.file(file)
	end
	pipe:close()
	if findings == 0 then
		harness.test("linter reports src/ clean", function() end)
	else
		harness.test("linter reports src/ clean", function()
			error(("%d lint finding(s) in src/"):format(findings))
		end)
	end
else
	harness.test("linter self-test", function() error("linter not trustworthy") end)
end

require("tests.suite_theme")
require("tests.suite_layout")
require("tests.suite_enums")
require("tests.suite_nav")
require("tests.suite_build")
require("tests.suite_dashboard")
require("tests.suite_toggles")
require("tests.suite_release")

harness.run()
local ok = harness.summary()
os.exit(ok and 0 or 1)
