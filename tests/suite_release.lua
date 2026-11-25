--[[
	Release path: the loader, the stamp, and the workflows must agree.

	The failure this suite exists for is drift. A loader pointed at one path while
	the publisher writes another is invisible until someone in an executor gets a
	404, so the branch and filename are read out of Loader.lua and matched against
	what publish.yml actually pushes.

	Workflows are parsed as text; the workspace has no Actions runner.
]]

local harness = require("tests.harness")

local world = harness.newWorld()

harness.suite("release")

local function slurp(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local content = handle:read("a")
	handle:close()
	return content
end

local loader = slurp("Loader.lua")
local publish = slurp(".github/workflows/publish.yml")
local ci = slurp(".github/workflows/ci.yml")
local docs = slurp("docs/GITHUB.md")

local function required(value, what)
	harness.expect(value ~= nil, what .. " is missing")
	return value or ""
end

required(loader, "Loader.lua")
required(publish, "publish.yml")
required(ci, "ci.yml")
required(docs, "docs/GITHUB.md")

local function loaderConstant(name)
	local pattern = 'local ' .. name .. ' = "([^"]+)"'
	local value = (loader or ""):match(pattern)
	harness.expect(value ~= nil, "Loader.lua has no `local " .. name .. ' = "..."` constant')
	return value or ""
end

harness.test("the loader compiles", function()
	local chunk, err = loadfile("Loader.lua", "t", {})
	harness.expect(chunk ~= nil, "Loader.lua does not compile: " .. tostring(err))
end)

harness.test("the loader declares the branch and bundle the publisher writes", function()
	local branch = loaderConstant("BRANCH")
	local bundle = loaderConstant("BUNDLE")
	harness.equal(branch, "dist", "loader fetches a branch other than the published one")
	harness.equal(bundle, "Afterburn.lua", "loader fetches a different file name")

	-- The publisher must push that branch and that exact file, at the branch root.
	harness.matches(publish, "-b " .. branch, "publish.yml does not create the '" .. branch .. "' branch")
	harness.matches(publish, "publish/" .. bundle, "publish.yml does not stage " .. bundle .. " at the branch root")
end)

harness.test("the loader's own version matches the published VERSION", function()
	local declared = (loader or ""):match('local LOADER_VERSION = "([%d%.]+)"')
	harness.expect(declared ~= nil, "Loader.lua declares no LOADER_VERSION")

	local handle = io.open("VERSION", "r")
	harness.expect(handle ~= nil, "VERSION is missing")
	local onDisk = handle and handle:read("a"):gsub("%s+$", "") or ""
	if handle then
		handle:close()
	end

	harness.equal(declared, onDisk, "LOADER_VERSION and VERSION have drifted apart")
end)

harness.test("the loader guards every failure it can hit", function()
	-- Each of these is a distinct pcall'd branch; losing one means a silent death.
	for _, needle in ipairs({
		"no game:HttpGet",
		"no loadstring",
		"Could not reach the version file",
		"This loader is stale",
		"Could not download the bundle",
		"did not compile",
		"failed while starting",
	}) do
		harness.expect((loader or ""):find(needle, 1, true) ~= nil, "loader has no guard for: " .. needle)
	end
end)

harness.test("the loader refuses a stale published version", function()
	-- compareVersions must exist and be used against LOADER_VERSION, not just declared.
	harness.matches(loader, "compareVersions%(published, LOADER_VERSION%)")
	harness.matches(loader, "> 0", "no 'remote is newer' comparison")
end)

harness.test("publish.yml cannot run without CI passing", function()
	harness.matches(publish, "workflow_run", "publish does not trigger on another workflow")
	harness.matches(publish, "workflows: %[\"ci\"%]")
	harness.matches(publish, "conclusion == 'success'", "no success gate on the CI conclusion")
end)

harness.test("publish.yml compile-checks the bundle before pushing", function()
	harness.matches(publish, "loadfile%(\"dist/Afterburn%.lua\"%)", "publisher does not compile the bundle")
	harness.matches(publish, "test %-s dist/Afterburn%.lua", "publisher does not reject an empty bundle")
end)

harness.test("publish.yml refuses a version that does not increase", function()
	harness.matches(publish, "is not greater than published", "no monotonic VERSION guard")
end)

harness.test("ci.yml runs the suite on lua 5.4 and cannot swallow a failure", function()
	harness.matches(ci, "lua5%.4 tests/run_all%.lua", "ci does not run the suite")
	harness.matches(ci, "lua5%.4 Build%.lua", "ci does not build")
	harness.expect(not ci:find("|| true", 1, true), "ci masks a failing step with '|| true'")
end)

harness.test("docs cover the private-repo and stale-cache cases", function()
	harness.matches(docs, "private", "docs never mention the private-repo failure")
	harness.matches(docs, "401", "docs do not name the 401 that private raw URLs return")
	harness.matches(docs, "cache", "docs never mention CDN caching")
	harness.matches(docs, "rollback", "docs give no rollback path")
end)

harness.test("a built bundle is stamped with version and commit", function()
	local version = loadfile("VERSION")
	harness.expect(version ~= nil or slurp("VERSION") ~= nil, "VERSION is missing")

	local dir = "/tmp/ab_release_" .. tostring(math.random(100000, 999999))
	os.execute("mkdir -p " .. dir)
	os.execute("cp -r src VERSION Build.lua README.md " .. dir .. "/")

	local Build = world.AB.Require("Build")
	local ok, err, path = Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	harness.expect(ok, "build refused a stamped tree: " .. tostring(err))

	local body = slurp(path) or ""
	local declared = (slurp("VERSION") or ""):gsub("%s+$", "")
	harness.expect(body:find("Version " .. declared, 1, true) ~= nil, "header carries no version")
	harness.expect(body:find("commit ", 1, true) ~= nil, "header carries no commit")
	harness.expect(body:find("nogit", 1, true) ~= nil or body:match("commit %x+") ~= nil, "commit stamp is malformed")

	os.execute("rm -rf " .. dir)
end)

harness.test("an unstamped tree still builds", function()
	local dir = "/tmp/ab_release_" .. tostring(math.random(100000, 999999))
	os.execute("mkdir -p " .. dir)
	os.execute("cp -r src Build.lua README.md " .. dir .. "/")

	local Build = world.AB.Require("Build")
	local ok, err = Build.run({ root = dir, out = dir .. "/dist/Out.lua", silent = true })
	harness.expect(ok, "a missing VERSION broke the build: " .. tostring(err))
	harness.matches(slurp(dir .. "/dist/Out.lua") or "", "0%.0%.0%-unstamped")

	os.execute("rm -rf " .. dir)
end)
