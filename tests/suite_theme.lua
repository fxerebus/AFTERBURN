-- Colour policy: token completeness, coverage, and no literals outside Theme.
local harness = require("tests.harness")

local world = harness.newWorld()
local AB = world.AB
local Theme = AB.Require("Core.Theme")
local UIManager = AB.Require("Core.UIManager")

harness.suite("theme")

harness.test("both sets define every token and differ", function()
	local complete, problems = Theme.assertComplete()
	harness.expect(complete, "token sets incomplete: " .. table.concat(problems, "; "))
end)

harness.test("every token resolves to a colour in both sets", function()
	for _, name in ipairs(Theme.names()) do
		for _, token in ipairs(Theme.tokens("dark")) do
			local value = Theme.color(token, name)
			harness.expect(type(value) == "table", ("token %s/%s did not resolve"):format(name, token))
		end
	end
end)

harness.test("toggle switches sets and changes a surface", function()
	Theme.set("dark")
	local before = Theme.hex("surface")
	local ok = Theme.toggle()
	harness.expect(ok)
	harness.equal(Theme.current(), "light")
	harness.notEqual(Theme.hex("surface"), before)
	Theme.set("dark")
end)

harness.test("unknown token warns and returns a visible fallback", function()
	world.clear()
	local value = Theme.hex("does_not_exist")
	harness.equal(value, "#FF00FF")
	harness.equal(world.countWarnings("unknown token"), 1)
end)

harness.test("paint applies tokens to a live instance", function()
	local frame = world.env.Instance.new("Frame")
	frame.Parent = world.playerGui
	UIManager.themed(frame, { BackgroundColor3 = "bg" })
	Theme.set("light")
	UIManager.applyTheme()
	harness.expect(frame.BackgroundColor3 ~= nil, "surface was not painted")
	Theme.set("dark")
	frame:Destroy()
end)

harness.test("no colour literal or Color3 call outside Theme.lua", function()
	local pipe = io.popen('find src -name "*.lua" -type f ! -path "src/Core/Theme.lua" | sort')
	harness.expect(pipe ~= nil)
	local offenders = {}
	for file in pipe:lines() do
		local handle = assert(io.open(file, "r"))
		local source = handle:read("a")
		handle:close()
		if source:match("#%x%x%x%x%x%x") or source:match("Color3%s*%.") then
			offenders[#offenders + 1] = file
		end
	end
	pipe:close()
	harness.equal(#offenders, 0, "colour literals found in: " .. table.concat(offenders, ", "))
end)
