--[[
	Core/Theme.lua — the only place in AFTERBURN where a colour literal may exist.

	Two token sets, identical key sets, one active name. Every screen resolves
	through Theme.color(token); nothing else types a hex or calls Color3.

	`Theme.assertComplete()` is what keeps the light set honest: the suite calls
	it, so adding a dark token without a light counterpart fails the build rather
	than silently rendering a black panel on a white page.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")

local Theme = {}

local SETS = {
	dark = {
		bg = "#0B0C0E",
		bgElevated = "#111317",
		surface = "#15181D",
		surfaceAlt = "#1B1F26",
		rail = "#0D0F12",
		railActive = "#1F242C",
		header = "#0E1013",
		border = "#2A2F38",
		borderStrong = "#3A414D",
		text = "#F2F4F7",
		textDim = "#9AA3B0",
		textInverse = "#0B0C0E",
		accent = "#FF6A00",
		accentHover = "#FF8330",
		accentText = "#120800",
		focus = "#FFC46B",
		danger = "#E23B2E",
		warning = "#FFB020",
		success = "#33C77D",
		glow = "#FF6A00",
		track = "#262C35",
		knob = "#F2F4F7",
		disabled = "#4A525E",
		overlay = "#08090B",
		scrim = "#05060A",
		toast = "#191D24",
		shadow = "#000000",
	},

	light = {
		bg = "#F4F5F7",
		bgElevated = "#FFFFFF",
		surface = "#FFFFFF",
		surfaceAlt = "#EDEFF3",
		rail = "#FAFBFC",
		railActive = "#FFE7D3",
		header = "#FFFFFF",
		border = "#D8DCE3",
		borderStrong = "#BCC2CC",
		text = "#12151A",
		textDim = "#5C6674",
		textInverse = "#FFFFFF",
		accent = "#E85D00",
		accentHover = "#C94F00",
		accentText = "#FFFFFF",
		focus = "#B4500A",
		danger = "#C4362A",
		warning = "#A96A00",
		success = "#1E8F57",
		glow = "#FF8A33",
		track = "#DDE1E7",
		knob = "#FFFFFF",
		disabled = "#AEB5C0",
		overlay = "#FFFFFF",
		scrim = "#0B0C0E",
		toast = "#FFFFFF",
		shadow = "#8892A0",
	},
}

local active = Config.theme.default

------------------------------------------------------------------ helpers ----

local function hexToColor3(hex)
	local r = tonumber(hex:sub(2, 3), 16) / 255
	local g = tonumber(hex:sub(4, 5), 16) / 255
	local b = tonumber(hex:sub(6, 7), 16) / 255
	return Color3.new(r, g, b)
end

-- Resolved colours are cached per name+token; Color3 objects are immutable, so
-- reuse is safe and keeps re-theming from allocating on every frame rebuild.
local cache = { dark = {}, light = {} }

-------------------------------------------------------------------- api ----

function Theme.names()
	return { "dark", "light" }
end

function Theme.has(name)
	return SETS[name] ~= nil
end

function Theme.current()
	return active
end

function Theme.hex(token, name)
	local set = SETS[name or active]
	local value = set and set[token]
	if not value then
		warn(("AFTERBURN theme: unknown token '%s' in set '%s'"):format(tostring(token), tostring(name or active)))
		return "#FF00FF" -- magenta: visibly wrong beats silently invisible
	end
	return value
end

function Theme.color(token, name)
	local set = name or active
	local bucket = cache[set]
	local hit = bucket and bucket[token]
	if hit then
		return hit
	end
	local built = hexToColor3(Theme.hex(token, set))
	if bucket then
		bucket[token] = built
	end
	return built
end

function Theme.set(name)
	if not Theme.has(name) then
		return false, ("unknown theme '%s'"):format(tostring(name))
	end
	active = name
	return true
end

function Theme.toggle()
	return Theme.set(active == "dark" and "light" or "dark")
end

function Theme.tokens(name)
	local out = {}
	for token in pairs(SETS[name or active]) do
		out[#out + 1] = token
	end
	table.sort(out)
	return out
end

-- Returns ok, list of problems. Empty list means both sets carry every token.
function Theme.assertComplete()
	local problems = {}
	local reference = Theme.tokens("dark")

	for _, name in ipairs(Theme.names()) do
		local set = SETS[name]
		for _, token in ipairs(reference) do
			if set[token] == nil then
				problems[#problems + 1] = ("set '%s' is missing token '%s'"):format(name, token)
			end
		end
		for token, value in pairs(set) do
			if type(value) ~= "string" or not value:match("^#%x%x%x%x%x%x$") then
				problems[#problems + 1] = ("set '%s' token '%s' is not a 6-digit hex"):format(name, token)
			end
		end
	end

	for _, token in ipairs(reference) do
		if SETS.dark[token] == SETS.light[token] then
			problems[#problems + 1] = ("token '%s' is identical in both sets"):format(token)
		end
	end

	return #problems == 0, problems
end

-- Applies the active set to any instance carrying a token tag.
-- tags: { [inst] = { BackgroundColor3 = "surface", TextColor3 = "text" } }
function Theme.paint(tags)
	for inst, mapping in pairs(tags) do
		if inst and inst.Parent ~= nil then
			for property, token in pairs(mapping) do
				local ok = pcall(function()
					inst[property] = Theme.color(token)
				end)
				if not ok then
					warn(("AFTERBURN theme: cannot paint %s.%s"):format(tostring(inst.ClassName), property))
				end
			end
		end
	end
end

return Theme
