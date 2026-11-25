--[[
	Build.lua — bundles src/ into one paste-ready chunk.

	ORDER is authoritative. Three ways to abort, all tested:
	  * a file on disk that is not in ORDER
	  * an entry in ORDER with no file on disk
	  * a compile error in any module, or in the finished bundle

	The point is that a module can never be silently left out of the artefact.
	Run with `lua Build.lua`; the test suite calls Build.run directly with a
	scratch root.
]]

package.path = "./?.lua;" .. package.path

local Build = {}

local ORDER = {
	"Config",
	"Core/Theme",
	"Core/Session",
	"Core/DataManager",
	"Core/Layout",
	"Components/Cards",
	"Components/Buttons",
	"Components/Badges",
	"Components/Stats",
	"Components/ProgressBar",
	"Components/Toggles",
	"Core/NotificationManager",
	"Core/Navigation",
	"Core/UIManager",
	"Core/Shell",
	"Pages/Dashboard",
	"Pages/Farming",
	"Pages/Mastery",
	"Pages/Bosses",
	"Pages/Raids",
	"Pages/Fruits",
	"Pages/Inventory",
	"Pages/Servers",
	"Pages/Settings",
	"main",
}

Build.ORDER = ORDER

local BEGIN_MARK = "<!-- build:begin -->"
local END_MARK = "<!-- build:end -->"

local function readFile(path)
	local handle = io.open(path, "r")
	if not handle then
		return nil
	end
	local content = handle:read("a")
	handle:close()
	return content
end

local function writeFile(path, content)
	local handle = assert(io.open(path, "w"))
	handle:write(content)
	handle:close()
end

--- Stamp data for the bundle header. Never fails: a missing VERSION or a
--- non-git checkout still produces a build, just an unidentifiable one.
-- Build time, fixed when SOURCE_DATE_EPOCH is set. Without this a rebuild a
-- second later differs in the header alone, so byte identity could not be proven.
function Build.stampTime()
	local epoch = os.getenv("SOURCE_DATE_EPOCH")
	if epoch and epoch:match("^%d+$") then
		return os.date("!%Y-%m-%dT%H:%M:%SZ", tonumber(epoch))
	end
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

function Build.stamp(root)
	local version = readFile(root .. "/VERSION")
	if version then
		version = version:gsub("%s+$", "")
	end
	if not version or version == "" then
		version = "0.0.0-unstamped"
	end

	local commit = "nogit"
	local pipe = io.popen("git -C " .. root .. " rev-parse --short HEAD 2>/dev/null")
	if pipe then
		local out = pipe:read("a")
		pipe:close()
		if out and out:match("^%x+") then
			commit = out:gsub("%s+$", "")
		end
	end

	return version, commit
end

--- Every .lua under <root>/src, as keys relative to src/ without extension.
function Build.collect(root)
	local keys = {}
	local pipe = io.popen(('find %s/src -name "*.lua" -type f | sort'):format(root))
	if not pipe then
		return keys
	end
	for line in pipe:lines() do
		local key = line:gsub("^" .. root:gsub("%p", "%%%0") .. "/src/", ""):gsub("%.lua$", "")
		keys[#keys + 1] = key
	end
	pipe:close()
	return keys
end

local function setOf(list)
	local set = {}
	for _, value in ipairs(list) do
		set[value] = true
	end
	return set
end

--- Validates ORDER against disk. Returns ok, message.
function Build.validate(root)
	local disk = Build.collect(root)
	local onDisk = setOf(disk)
	local inOrder = setOf(Build.ORDER)

	if #disk == 0 then
		return false, "no modules found under " .. root .. "/src"
	end

	local missing, stray = {}, {}
	for _, key in ipairs(Build.ORDER) do
		if not onDisk[key] then
			missing[#missing + 1] = key
		end
	end
	for _, key in ipairs(disk) do
		if not inOrder[key] then
			stray[#stray + 1] = key
		end
	end

	if #missing > 0 then
		return false, "in ORDER but absent from disk: " .. table.concat(missing, ", ")
	end
	if #stray > 0 then
		return false, "on disk but absent from ORDER: " .. table.concat(stray, ", ")
	end

	return true, nil
end

--- Builds. opts: { root, out, silent }
function Build.run(opts)
	local options = opts or {}
	local root = options.root or "."
	local out = options.out or (root .. "/dist/Afterburn.lua")

	local ok, err = Build.validate(root)
	if not ok then
		if not options.silent then
			print("build aborted: " .. err)
		end
		return false, err
	end

	local chunks = {}
	for _, key in ipairs(Build.ORDER) do
		local path = root .. "/src/" .. key .. ".lua"
		local source = readFile(path)
		if not source then
			return false, "cannot read " .. path
		end

		local chunk, compileError = load(source, "@" .. path, "t", {})
		if not chunk then
			return false, ("compile error in %s: %s"):format(key, tostring(compileError))
		end

		chunks[#chunks + 1] = ("-- >>> %s\nAB.modules[%q] = function(AB)\n%s\nend\n"):format(key, key, source)
	end

	local version, commit = Build.stamp(root)

	local head = table.concat({
		"--[[",
		"	AFTERBURN — generated bundle. Do not edit; edit src/ and run `lua Build.lua`.",
		("	Version %s — commit %s — built %s"):format(version, commit, Build.stampTime()),
		("	%s modules, built from the ORDER list in Build.lua."):format(#ORDER),
		"	Target: Android first (Arceus X / Delta), Windows second.",
		"]]",
		"",
		"local AB = { modules = {}, cache = {}, faults = {} }",
		"AB.autorun = false",
		"_G.AFTERBURN = AB",
		"",
		"function AB.Require(path)",
		"\tlocal key = tostring(path):gsub('%.', '/')",
		"\tlocal cached = AB.cache[key]",
		"\tif cached ~= nil then",
		"\t\treturn cached",
		"\tend",
		"\tlocal factory = AB.modules[key]",
		"\tif not factory then",
		"\t\terror((\"AFTERBURN: no module '%s'\"):format(key), 0)",
		"\tend",
		"\tlocal value = factory(AB)",
		"\tAB.cache[key] = value",
		"\treturn value",
		"end",
		"",
	}, "\n")

	local tail = table.concat({
		"",
		"-- Entry: load main, then start explicitly so a paste never half-runs.",
		"AB.Require('main')",
		"AB.autorun = true",
		"AB.start()",
		"",
	}, "\n")

	local bundle = head .. table.concat(chunks, "\n") .. tail

	local chunk, compileError = load(bundle, "@bundle", "t", {})
	if not chunk then
		return false, "bundle does not compile: " .. tostring(compileError)
	end

	os.execute("mkdir -p " .. out:match("^(.*)/[^/]+$"))
	writeFile(out, bundle)

	Build.stampReadme(root, #ORDER, #bundle, version)

	if not options.silent then
		print(("built %s — %d modules, %d bytes"):format(out, #ORDER, #bundle))
	end

	return true, nil, out
end

--- Idempotent README stamp: replaces the marked block, never duplicates it.
function Build.stampReadme(root, modules, bytes, version)
	local path = root .. "/README.md"
	local readme = readFile(path)
	if not readme then
		return
	end

	local block = table.concat({
		BEGIN_MARK,
		"## 8. Last build",
		"",
		("`dist/Afterburn.lua` at **v%s** — %d modules, %d bytes. Regenerate with `lua Build.lua`; never edit the bundle."):format(tostring(version), modules, bytes),
		END_MARK,
	}, "\n")

	local start = readme:find(BEGIN_MARK, 1, true)
	if start then
		local _, stop = readme:find(END_MARK, start, true)
		if stop then
			writeFile(path, readme:sub(1, start - 1) .. block .. readme:sub(stop + 1))
			return
		end
	end

	writeFile(path, readme:gsub("%s*$", "") .. "\n\n" .. block .. "\n")
end

if arg and arg[0] and arg[0]:match("Build%.lua$") then
	local ok, err = Build.run({ root = "." })
	if not ok then
		os.exit(1)
	end
	os.exit(0)
end

return Build
