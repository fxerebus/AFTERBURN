--[[
	Enum names: every `Enum.<Type>` and `Enum.<Type>.<Member>` in src/ must be a
	name Roblox actually defines.

	The defect this exists for is a fabricated member. `Enum.AutoSize` is not a
	real Roblox enum — the real one is `Enum.AutomaticSize` — and Roblox raises on
	the index, so it aborted the boot at the `finish` stage. Sixty-five green
	checks let it through because the mock answered every name it was handed and
	the suite never compared those names against a list.

	The allowlist lives in harness.members so the mock and this scan read one
	table: a member added for a test is immediately legal in src/, and a member
	used in src/ is immediately legal in a test.

	Self-tested first — a scan that cannot find a planted bogus name is worthless.
]]

local harness = require("tests.harness")

local members = harness.enumMembers

harness.suite("enums")

local function scan(text)
	local findings = {}
	for kind, member in text:gmatch("Enum%.([%w_]+)%.?([%w_]*)") do
		local known = members[kind]
		if known == nil then
			findings[#findings + 1] = "Enum." .. kind .. " is not a real enum"
		elseif member ~= "" and known[member] == nil then
			findings[#findings + 1] = ("Enum.%s.%s is not a member of Enum.%s"):format(kind, member, kind)
		end
	end
	return findings
end

--------------------------------------------------------------- self-test ----

harness.test("[enums] the scan finds a planted bogus enum type", function()
	local findings = scan("local x = Enum.AutoSize\nlocal y = Enum.Font.Gotham")
	harness.equal(#findings, 1, "expected exactly one finding")
	harness.matches(findings[1], "AutoSize", "finding does not name the bogus type")
end)

harness.test("[enums] the scan finds a planted bogus enum member", function()
	local findings = scan("local x = Enum.Font.GothamNonsense")
	harness.equal(#findings, 1, "expected exactly one finding")
	harness.matches(findings[1], "GothamNonsense", "finding does not name the bogus member")
end)

harness.test("[enums] the scan reads digits in a member", function()
	local findings = scan("local a = Enum.UserInputType.MouseButton1\nlocal b = Enum.UserInputType.MouseButton2")
	harness.equal(#findings, 0, "scan truncated a member at its digit")
	local bogus = scan("local a = Enum.UserInputType.MouseButton9")
	harness.equal(#bogus, 1, "scan did not still catch a bogus digit member")
end)

harness.test("[enums] the scan passes real names", function()
	local findings = scan("local a = Enum.Font.Gotham\nlocal b = Enum.AutomaticSize.Y\nlocal c = Enum.UserInputType.Touch")
	harness.equal(#findings, 0, "scan flagged real names")
end)

------------------------------------------------------------ real scan ----

harness.test("[enums] src/ uses only real enum names", function()
	local pipe = io.popen('find src -name "*.lua" -type f | sort')
	local findings = {}
	for file in pipe:lines() do
		local handle = io.open(file, "r")
		if handle then
			local text = handle:read("a")
			handle:close()
			for _, finding in ipairs(scan(text or "")) do
				findings[#findings + 1] = file .. ": " .. finding
			end
		end
	end
	pipe:close()

	if #findings > 0 then
		for _, finding in ipairs(findings) do
			print("  " .. finding)
		end
		error(("%d false enum name(s) in src/"):format(#findings))
	end
end)
