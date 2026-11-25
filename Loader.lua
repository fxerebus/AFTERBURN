--[[
	Loader.lua — the stable one-liner target for AFTERBURN.

	Paste this once, in an executor, attached to the experience:

		loadstring(game:HttpGet("https://raw.githubusercontent.com/fxerebus/AFTERBURN/main/Loader.lua?v=" .. os.time()))()

	This file is the only address users ever need. It does not change when the hub
	does, so an update never invalidates a shared one-liner. Its whole job is:

	  1. refuse early, with a readable on-screen fault, if the executor lacks what
	     we need — HttpGet, loadstring, and a Roblox environment to hang a frame on
	  2. refuse if this loader copy is stale relative to what dist/ publishes, so a
	     CDN-cached loader cannot quietly drive a newer bundle with older rules
	  3. fetch the built bundle from the `dist` branch with a cache-busting
	     parameter, compile it under pcall, and run it
	  4. on any failure, show why on screen instead of dying in the console where
	     nobody on a phone will see it

	The bundle target lives in BUNDLE below. tests/suite_release.lua asserts that
	path against the destination the publish workflow actually writes, so the two
	cannot drift without a red check.

	Raw GitHub returns text/plain with a wildcard CORS header, which is why
	game:HttpGet accepts it. It is CDN-cached for minutes and rate-limited per IP,
	so this is not instant publishing — see docs/GITHUB.md.
]]

local OWNER = "fxerebus"
local REPO = "AFTERBURN"
local BRANCH = "dist"
local BUNDLE = "Afterburn.lua"
local VERSION_FILE = "VERSION"

-- Bumped alongside VERSION. A loader older than the published VERSION refuses to run.
local LOADER_VERSION = "1.0.3"

local RAW_BASE = ("https://raw.githubusercontent.com/%s/%s/%s/"):format(OWNER, REPO, BRANCH)

local function cacheBust()
	return ("%d%d"):format(os.time(), math.random(1000, 9999))
end

-- Plain numeric compare of dotted versions; enough to spot a stale loader.
local function compareVersions(a, b)
	local left = tostring(a):match("^[%d%.]+$")
	local right = tostring(b):match("^[%d%.]+$")
	if not left or not right then
		return 0
	end
	local la, lb = {}, {}
	for piece in left:gmatch("%d+") do
		la[#la + 1] = tonumber(piece) or 0
	end
	for piece in right:gmatch("%d+") do
		lb[#lb + 1] = tonumber(piece) or 0
	end
	for index = 1, math.max(#la, #lb) do
		local x = la[index] or 0
		local y = lb[index] or 0
		if x ~= y then
			return x < y and -1 or 1
		end
	end
	return 0
end

-- Pre-UI fault surface. Deliberately does not require the hub's theme layer:
-- if the hub never loaded, there is no theme to consult.
local function fault(message)
	local text = "AFTERBURN failed to load\n\n" .. tostring(message) .. "\n\nDiscord: discord.gg/afterburn"

	local ok = pcall(function()
		local gui = Instance.new("ScreenGui")
		gui.Name = "AFTERBURN_Fault"
		gui.ResetOnSpawn = false
		gui.IgnoreGuiInset = true
		gui.DisplayOrder = 100

		local frame = Instance.new("Frame")
		frame.Size = UDim2.fromOffset(340, 150)
		frame.Position = UDim2.new(0.5, -170, 0.5, -75)
		frame.BackgroundColor3 = Color3.fromRGB(14, 14, 14)
		frame.BorderSizePixel = 0
		frame.Parent = gui

		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, -24, 1, -24)
		label.Position = UDim2.fromOffset(12, 12)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.Gotham
		label.TextSize = 13
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextYAlignment = Enum.TextYAlignment.Top
		label.TextColor3 = Color3.fromRGB(240, 240, 240)
		label.Text = text
		label.Parent = frame

		local host = nil
		pcall(function()
			host = gethui and gethui() or nil
		end)
		if not host then
			host = game:GetService("CoreGui")
		end
		gui.Parent = host
	end)

	if not ok then
		warn("[AFTERBURN] " .. text)
	end
end

-- Environment gate. Each requirement is separate so the message says which one failed.
if typeof(game) ~= "Instance" then
	fault("Not running inside Roblox — game is missing.")
	return
end
if typeof(game.HttpGet) ~= "function" then
	fault("This executor has no game:HttpGet, so the bundle cannot be fetched.")
	return
end

local loader = loadstring or load
if typeof(loader) ~= "function" then
	fault("This executor has no loadstring, so the bundle cannot be compiled.")
	return
end

-- Stale-loader gate: a cached Loader.lua must not drive a newer bundle.
do
	local okFetch, published = pcall(function()
		return game:HttpGet(RAW_BASE .. VERSION_FILE .. "?v=" .. cacheBust())
	end)
	if not okFetch then
		fault("Could not reach the version file.\n\n" .. tostring(published))
		return
	end
	if compareVersions(published, LOADER_VERSION) > 0 then
		fault(("This loader is stale (v%s) and the hub is now v%s."):format(
			LOADER_VERSION,
			tostring(published):gsub("%s+$", "")
		) .. "\n\nRe-paste the one-liner from the README.")
		return
	end
end

-- Fetch the bundle.
local okGet, body = pcall(function()
	return game:HttpGet(RAW_BASE .. BUNDLE .. "?v=" .. cacheBust())
end)
if not okGet then
	fault("Could not download the bundle.\n\n" .. tostring(body))
	return
end
if type(body) ~= "string" or #body < 256 then
	fault("The bundle came back empty or truncated (" .. tostring(#body) .. " bytes).")
	return
end

-- Compile, then run. Both under pcall so a syntax error and a runtime error read
-- the same way instead of one dumping a raw stack into a collapsed console.
local chunk, compileError = loader(body, "@AFTERBURN")
if not chunk then
	fault("The bundle did not compile.\n\n" .. tostring(compileError))
	return
end

local okRun, runError = pcall(chunk)
if not okRun then
	fault("The bundle compiled but failed while starting.\n\n" .. tostring(runError))
end
