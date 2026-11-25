--[[
	Build guard: ORDER drift must abort, and a good tree must bundle and compile.

	ORDER stores bare module ids — "Components/Stats", not "src/Components/Stats.lua".
	`withoutOrderKey` finds the id in its stored shape and asserts it was found, so a
	mutation that silently matched nothing cannot be mistaken for a passing test.
	The Stage 2 case exists because the new entries need covering, not just Stage 1's.
]]

local harness = require("tests.harness")

local world = harness.newWorld()
local Build = world.AB.Require("Build")

harness.suite("build")

local function scratch()
	local dir = "/tmp/ab_build_" .. tostring(math.random(100000, 999999))
	os.execute("mkdir -p " .. dir)
	os.execute("cp -r src Build.lua README.md " .. dir .. "/")
	return dir
end

--- Runs fn with one ORDER entry removed, then restores the list in place.
-- Build.validate reads Build.ORDER, so the scratch tree's own Build.lua copy is
-- irrelevant here; editing it would be a mutation that matches nothing. The key
-- must be found in its stored shape or the helper asserts, so a rename can never
-- turn this into a silent pass.
local function withoutOrderKey(key, fn)
	local list = Build.ORDER
	local saved = {}
	for index, entry in ipairs(list) do
		saved[index] = entry
	end

	local at
	for index, entry in ipairs(list) do
		if entry == key then
			at = index
			break
		end
	end
	assert(at, "ORDER has no entry stored as \"" .. key .. "\"")

	table.remove(list, at)
	local ok, first, second = pcall(fn)

	for index = #list, 1, -1 do
		list[index] = nil
	end
	for index, entry in ipairs(saved) do
		list[index] = entry
	end

	if not ok then
		error(first, 0)
	end
	return first, second
end

harness.test("clean tree builds and the bundle compiles", function()
	local dir = scratch()
	local ok, err, path = Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	harness.expect(ok, "build refused a clean tree: " .. tostring(err))
	local chunk, compileError = loadfile(path, "t", {})
	harness.expect(chunk ~= nil, "bundle does not compile: " .. tostring(compileError))
	os.execute("rm -rf " .. dir)
end)

harness.test("a Stage 2 module dropped from ORDER aborts the build", function()
	local dir = scratch()
	local ok, err = withoutOrderKey("Components/Stats", function()
		return Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	end)
	harness.equal(ok, false, "build accepted a Stage 2 module missing from ORDER")
	harness.matches(err, "Stats")
	os.execute("rm -rf " .. dir)
end)

harness.test("a Stage 1 module dropped from ORDER aborts the build", function()
	local dir = scratch()
	local ok, err = withoutOrderKey("Core/Navigation", function()
		return Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	end)
	harness.equal(ok, false, "build accepted a Stage 1 module missing from ORDER")
	harness.matches(err, "Navigation")
	os.execute("rm -rf " .. dir)
end)

harness.test("a file absent from disk but present in ORDER aborts", function()
	local dir = scratch()
	os.execute("rm " .. dir .. "/src/Pages/Raids.lua")
	local ok, err = Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	harness.equal(ok, false)
	harness.matches(err, "Raids")
	os.execute("rm -rf " .. dir)
end)

harness.test("a stray module not in ORDER aborts", function()
	local dir = scratch()
	local handle = assert(io.open(dir .. "/src/Core/Stray.lua", "w"))
	handle:write("return {}\n")
	handle:close()
	local ok, err = Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	harness.equal(ok, false)
	harness.matches(err, "Stray")
	os.execute("rm -rf " .. dir)
end)

harness.test("the README build block stays single after two runs", function()
	local dir = scratch()
	Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	local handle = assert(io.open(dir .. "/README.md", "r"))
	local readme = handle:read("a")
	handle:close()
	local opens, pos = 0, 1
	while true do
		local start = readme:find("<!-- build:begin -->", pos, true)
		if not start then
			break
		end
		opens = opens + 1
		pos = start + 1
	end
	harness.equal(opens, 1, "build block duplicated")
	os.execute("rm -rf " .. dir)
end)

-- The unused-component rule: an ORDER entry nothing mounts is dead weight in the
-- bundle. Only Components are checked — Core is pulled in by main/Shell and the
-- pages by Navigation, so their reachability is structural rather than a require.
harness.test("no component in ORDER is unreferenced by any page or core module", function()
	local pipe = io.popen('find src/Pages src/Core src/main.lua -name "*.lua" -type f')
	local corpus = {}
	for file in pipe:lines() do
		local handle = io.open(file, "r")
		corpus[#corpus + 1] = handle:read("a")
		handle:close()
	end
	pipe:close()
	local haystack = table.concat(corpus, "\n")

	local unused = {}
	for _, key in ipairs(Build.ORDER) do
		local short = key:match("^Components/(.+)$")
		if short and not haystack:find('Components.' .. short, 1, true) then
			unused[#unused + 1] = key
		end
	end
	harness.equal(#unused, 0, "in ORDER and used by nothing: " .. table.concat(unused, ", "))
end)
