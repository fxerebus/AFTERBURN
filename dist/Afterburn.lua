--[[
	AFTERBURN — generated bundle. Do not edit; edit src/ and run `lua Build.lua`.
	Version 1.0.0 — commit nogit — built 2026-11-25T06:15:50Z
	25 modules, built from the ORDER list in Build.lua.
	Target: Android first (Arceus X / Delta), Windows second.
]]

local AB = { modules = {}, cache = {}, faults = {} }
AB.autorun = false
_G.AFTERBURN = AB

function AB.Require(path)
	local key = tostring(path):gsub('%.', '/')
	local cached = AB.cache[key]
	if cached ~= nil then
		return cached
	end
	local factory = AB.modules[key]
	if not factory then
		error(("AFTERBURN: no module '%s'"):format(key), 0)
	end
	local value = factory(AB)
	AB.cache[key] = value
	return value
end
-- >>> Config
AB.modules["Config"] = function(AB)
--[[
	Config.lua — AFTERBURN's single source of tunable truth.

	Everything a user might reasonably want to change before running the hub lives
	here and nowhere else: brand strings, layout thresholds, theme default, the
	PlaceId -> plugin registry, and the live-data switches.

	Rule: no screen module may hardcode a threshold, a brand string or a place ID.
	It reads Config (or, for geometry, Core.Layout, which reads Config for it).
]]

local AB = AB or _G.AFTERBURN

local Config = {}

-------------------------------------------------------------------- brand ----

Config.brand = {
	name = "AFTERBURN",
	product = "AFTERBURN HUB",
	tagline = "Beyond Speed. Beyond Limits.",
	version = "0.1.0-stage1",
	channel = "stage1",
}

------------------------------------------------------------------- theme ----

Config.theme = {
	-- Dark is the identity. Light exists because the spec asks for it, and
	-- because a brightness switch is the cheapest proof that tokens are wired.
	default = "dark",
	persist = false, -- Stage 6 turns this on with real storage probing.
}

------------------------------------------------------------------ layout ----

-- Thresholds are widths in pixels of the viewport, not of the window.
-- `targetPx` is a *post-scale* floor: Core.Layout converts it to a pre-scale
-- size so that the effective hit area never drops below it.
Config.layout = {
	minScale = 0.7,
	maxScale = 1.15,
	targetPx = 44,
	compactBelow = 520, -- rail drops labels, drawer overlays the content
	mediumBelow = 760, -- full rail, drawer still overlays
	wideAt = 760, -- at or above: drawer docks, content shares the row
	scaleUpAbove = 1024, -- only past here does the UI grow past 1.0
	scaleDownBelow = 480,
	gutter = 8,
	windowMax = 1180,
	windowMin = 300,
}

---------------------------------------------------------------------- ui ----

Config.ui = {
	notifications = {
		max = 3,
		lifetime = 4.5, -- seconds on screen before auto-dismiss
	},
	animations = true,
	animationSpeed = 0.18,
	transparency = 1, -- 1 = opaque; the Settings page walks this down
	showStatusBar = true,
}

--------------------------------------------------------------- live data ----

Config.live = {
	-- Off by default, per spec. Nothing in Stage 1 reads a live path, but the
	-- registry below is where Stage 7 attaches, so paths never get hardcoded.
	enabled = false,

	-- PlaceId -> { name, file } — mirrors the dispatch table the reference hub
	-- keeps in its own source. Keys are strings so the file survives JSON later.
	plugins = {
		["994732206"] = { name = "Blox Fruits", file = "BloxFruits.lua" },
		["9186719164"] = { name = "Sailor Piece", file = "SailorPiece.lua" },
		["8191429227"] = { name = "Cut Trees", file = "CutTrees.lua" },
	},

	remoteRoot = "", -- set at Stage 7; empty means "resolve locally"
}

--------------------------------------------------------------- storage ----

Config.storage = {
	folder = "Afterburn",
	file = "Settings.json",
}

----------------------------------------------------------------- links ----

Config.links = {
	support = "https://discord.gg/quantumonyx", -- reference hub's community; swap when AFTERBURN has its own
}

return Config

end

-- >>> Core/Theme
AB.modules["Core/Theme"] = function(AB)
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

end

-- >>> Core/Session
AB.modules["Core/Session"] = function(AB)
--[[
	Core/Session.lua — how long this run has been up.

	Plain Lua, no Roblox API, so the timer is provable here rather than in Studio.
	The clock is injected: Session.new({ clock = fn }) drives time forward in a
	test without sleeping, and defaults to os.clock at runtime.

	Session counts, it does not display policy. Formatting lives here only
	because the shape of the string is part of the contract (a run past an hour
	must not wrap to 0:00), and the Dashboard asks for it.
]]

local Session = {}
Session.__index = Session

local function realClock()
	return os.clock()
end

--- Starts a session. opts.clock replaces the time source; opts.at sets an origin.
function Session.new(opts)
	local o = opts or {}
	local self = setmetatable({}, Session)
	self._clock = o.clock or realClock
	self._origin = tonumber(o.at) or self._clock()
	self._frozen = nil
	return self
end

--- Seconds since the session opened. Never negative, even with a stuttering clock.
function Session:elapsed()
	if self._frozen ~= nil then
		return self._frozen
	end
	return math.max(0, self._clock() - self._origin)
end

--- Time the session has been up, as whole seconds. Alias kept explicit.
function Session:ticks()
	return math.floor(self:elapsed())
end

--- Stops the clock at its current value; further calls are idempotent.
function Session:stop()
	if self._frozen == nil then
		self._frozen = self:elapsed()
	end
	return self._frozen
end

function Session:stopped()
	return self._frozen ~= nil
end

--- h:mm:ss with unbounded hours, so 3600 reads 1:00:00 and not 0:00.
function Session.format(seconds)
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	return ("%d:%02d:%02d"):format(hours, minutes, secs)
end

--- The same value as a view label ("0:00:07" plus a unit word).
function Session.label(seconds)
	return Session.format(seconds)
end

return Session

end

-- >>> Core/DataManager
AB.modules["Core/DataManager"] = function(AB)
--[[
	Core/DataManager.lua — the one place the Dashboard gets values from.

	Every value leaves here wrapped: { value = ..., provenance = "simulated" }.
	Screens render the pair, never the bare value, so a badge cannot be forgotten
	as pages multiply — a missing field is a defect the suite can see, not
	something a screenshot has to catch.

	Provenance today is always "simulated": Config.live.enabled is false and no
	provider can read a real path yet. DataManager.provenance() is the single
	answer to "where did this come from", and Stage 7 changes only that function.

	Provider modes exist so degradation is testable rather than assumed:
	  "simulated" — the full fabricated set (default)
	  "blank"     — nothing at all
	  "partial"   — a value and a progress fraction missing
]]

local AB = AB or _G.AFTERBURN

local Config = AB.Require("Config")
local Session = AB.Require("Core.Session")

local DataManager = {}

-------------------------------------------------------------- provenance ----

--- The provenance every value carries right now.
function DataManager.provenance()
	if Config.live.enabled and DataManager.liveAvailable() then
		return "live"
	end
	return "simulated"
end

--- Stage 7 replaces the body; nothing can satisfy it yet, so it stays false.
function DataManager.liveAvailable()
	return false
end

--- Wraps a value with its provenance. Exported so fixtures speak the same shape.
function DataManager.badged(value, provenance)
	return { value = value, provenance = provenance or DataManager.provenance() }
end

---------------------------------------------------------------- provider ----

function DataManager.new(opts)
	local o = opts or {}
	local self = setmetatable({}, { __index = DataManager })
	self.mode = o.mode or "simulated"
	self.session = o.session or Session.new()
	self._provenance = o.provenance or "simulated"
	return self
end

local function wrap(self, value)
	return DataManager.badged(value, self._provenance)
end

function DataManager:identity()
	if self.mode == "blank" then
		return nil
	end
	local name = "Operator"
	local role = "Authorized session"
	if self.mode == "partial" then
		name = nil -- the tile has to fall back to a placeholder
	end
	return wrap(self, { name = name, role = role })
end

function DataManager:welcome()
	if self.mode == "blank" then
		return nil
	end
	return wrap(self, "Welcome back. Systems nominal.")
end

function DataManager:activity()
	if self.mode == "blank" then
		return nil
	end
	local state = "idle"
	if self.mode == "partial" then
		state = nil
	end
	return wrap(self, { state = state, text = "No routine running" })
end

--- Headline tiles. Values are fabricated and badged; the suite counts badges.
function DataManager:stats()
	if self.mode == "blank" then
		return {}
	end
	local uptime = Session.format(self.session:ticks())
	local stats = {
		{ id = "uptime", label = "Session", value = uptime },
		{ id = "routes", label = "Routes ready", value = "9" },
		{ id = "provider", label = "Provider", value = "Simulated" },
	}
	if self.mode == "partial" then
		stats[3].value = nil
	end
	return stats
end

--- Feature overview fractions (0..1). All fabricated.
function DataManager:overview()
	if self.mode == "blank" then
		return {}
	end
	local rows = {
		{ id = "farming", label = "Farming", progress = 0.35 },
		{ id = "mastery", label = "Mastery", progress = 0.12 },
		{ id = "raids", label = "Raids", progress = 0 },
	}
	if self.mode == "partial" then
		rows[2].progress = nil
	end
	return rows
end

function DataManager:feed()
	if self.mode == "blank" then
		return {}
	end
	return {
		{ id = "boot", kind = "info", text = "Shell initialised" },
		{ id = "sim", kind = "warning", text = "Live data disabled in Config" },
	}
end

return DataManager

end

-- >>> Core/Layout
AB.modules["Core/Layout"] = function(AB)
--[[
	Core/Layout.lua — all geometry decisions, no instances.

	Pure functions only, so the whole file is unit-testable without Roblox.

	The contract that matters: a caller asks for `Layout.target(scale)` and gets a
	pre-scale size whose *product with scale* is at least Config.layout.targetPx.
	Layout never lets a control shrink below the floor; it reflows instead, by
	returning "icons" for the rail and "overlay" for the drawer once the viewport
	is compact.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")

local Layout = {}

local function if_else(cond, a, b)
	if cond then
		return a
	end
	return b
end

local function lerp(a, b, t)
	return a + (b - a) * t
end

local function clamp(value, low, high)
	if value < low then
		return low
	elseif value > high then
		return high
	end
	return value
end

-- Scale ramps: full size through the comfortable band, down to the floor on
-- narrow phones, up to the ceiling on wide desktops only.
function Layout.clampScale(scale)
	return clamp(scale, Config.layout.minScale, Config.layout.maxScale)
end

function Layout.scaleFor(width)
	local cfg = Config.layout
	local w = tonumber(width) or cfg.scaleDownBelow

	if w <= 320 then
		return cfg.minScale
	elseif w < cfg.scaleDownBelow then
		return Layout.clampScale(lerp(cfg.minScale, 1, (w - 320) / (cfg.scaleDownBelow - 320)))
	elseif w <= cfg.scaleUpAbove then
		return 1
	end

	return Layout.clampScale(lerp(1, cfg.maxScale, math.min(1, (w - cfg.scaleUpAbove) / 640)))
end

-- Pre-scale size for a control that must measure `px` (default: the floor)
-- once multiplied by `scale`.
function Layout.target(scale, px)
	local wanted = px or Config.layout.targetPx
	local s = Layout.clampScale(scale or 1)
	return math.ceil(wanted / s)
end

function Layout.gutter(scale)
	return math.max(4, math.floor(Config.layout.gutter * Layout.clampScale(scale or 1)))
end

-- Everything a view needs in one table, derived from the viewport.
function Layout.metrics(width, height)
	local w = tonumber(width) or 0
	local h = tonumber(height) or 0
	local scale = Layout.scaleFor(w)
	local compact = w < Config.layout.compactBelow
	local medium = w >= Config.layout.compactBelow and w < Config.layout.mediumBelow
	local wide = w >= Config.layout.wideAt

	local railWidth = if_else(compact, 56, 168)
	local target = Layout.target(scale)

	return {
		width = w,
		height = h,
		scale = scale,
		compact = compact,
		medium = medium,
		wide = wide,
		railMode = if_else(compact, "icons", "full"),
		sidebarMode = if_else(wide, "docked", "overlay"),
		target = target,
		targetPx = math.floor(target * scale + 0.5), -- effective, for assertions
		gutter = Layout.gutter(scale),
		railWidth = math.ceil(railWidth * scale),
		contentWidth = math.max(120, math.floor((w - (if_else(wide, railWidth, 0) + 24)) * 0.6)),
		windowWidth = clamp(math.floor(w * (if_else(compact, 0.94, 0.82))), Config.layout.windowMin, Config.layout.windowMax),
		windowHeight = math.floor(h * (if_else(compact, 0.86, 0.8))),
	}
end

-- True when the metrics satisfy the floor; the suite asserts this everywhere.
function Layout.meetsTarget(metrics)
	return metrics ~= nil and (metrics.target * metrics.scale) >= Config.layout.targetPx - 0.001
end

-- Compact viewports must never keep a labelled rail.
function Layout.reflects(metrics)
	if metrics == nil then
		return false
	end
	if metrics.compact then
		return metrics.railMode == "icons" and metrics.sidebarMode == "overlay"
	end
	if metrics.wide then
		return metrics.sidebarMode == "docked"
	end
	return metrics.railMode == "full"
end

return Layout

end

-- >>> Components/Cards
AB.modules["Components/Cards"] = function(AB)
--[[
	Components/Cards.lua — panel and card surfaces.

	A card is a header strip plus a body frame. Callers get the body and the
	header, never a bare Frame, so padding and token wiring stay consistent.

	All geometry comes from Layout, so a card that fits at scale 1 still fits at
	0.7 — the paddings grow while the viewport shrinks, and the card reflows its
	header to a stacked block when `compact` is set.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local Cards = {}

local function pad(size)
	return UDim.new(0, size)
end

--- Creates a card. opts: { title, subtitle, compact, scale, parent, tone }
-- tone: "surface" (default) | "accent" | "warning"
function Cards.create(opts)
	local o = opts or {}
	local scale = o.scale or 1
	local gap = Layout.gutter(scale)
	local padPx = Layout.target(scale, 10)

	local card = Instance.new("Frame")
	card.Name = o.name or "Card"
	card.BackgroundColor3 = Theme.color(o.tone == "accent" and "accent" or o.tone == "warning" and "warning" or "surface")
	card.BackgroundTransparency = o.tone and 0.86 or 0
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = o.order or 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color(o.tone and "accent" or "border")
	stroke.Thickness = 1
	stroke.Transparency = o.tone and 0.5 or 0
	stroke.Parent = card

	local list = Instance.new("UIListLayout")
	list.Padding = pad(gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -padPx * 2, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 10
	body.Parent = card

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(padPx)
	inner.PaddingRight = pad(padPx)
	inner.PaddingBottom = pad(padPx)
	inner.PaddingTop = pad(padPx)
	inner.Parent = body

	if o.title or o.subtitle then
		local header = Instance.new("Frame")
		header.Name = "Header"
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.LayoutOrder = 1
		header.Parent = card

		local headerPad = Instance.new("UIPadding")
		headerPad.PaddingLeft = pad(padPx)
		headerPad.PaddingRight = pad(padPx)
		headerPad.PaddingTop = pad(padPx)
		headerPad.Parent = header

		local headerList = Instance.new("UIListLayout")
		headerList.Padding = pad(math.max(2, gap // 2))
		headerList.SortOrder = Enum.SortOrder.LayoutOrder
		headerList.Parent = header

		if o.title then
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBold
			title.Text = o.title
			title.TextColor3 = Theme.color("text")
			title.TextSize = Layout.target(scale, 14)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = true
			title.Size = UDim2.new(1, 0, 0, 0)
			title.AutomaticSize = Enum.AutomaticSize.Y
			title.LayoutOrder = 1
			title.Parent = header
		end

		if o.subtitle then
			local sub = Instance.new("TextLabel")
			sub.Name = "Subtitle"
			sub.BackgroundTransparency = 1
			sub.Font = Enum.Font.Gotham
			sub.Text = o.subtitle
			sub.TextColor3 = Theme.color("textDim")
			sub.TextSize = Layout.target(scale, 11)
			sub.TextXAlignment = Enum.TextXAlignment.Left
			sub.TextWrapped = true
			sub.Size = UDim2.new(1, 0, 0, 0)
			sub.AutomaticSize = Enum.AutomaticSize.Y
			sub.LayoutOrder = 2
			sub.Parent = header
		end

		card:SetAttribute("HasHeader", true)
	end

	if o.parent then
		card.Parent = o.parent
	end

	return card, body
end

--- Compact single-line row: label left, optional trailing text right.
function Cards.row(parent, label, trailing, scale, order)
	local s = scale or 1
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, Layout.target(s))
	row.LayoutOrder = order or 1
	row.Parent = parent

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.Gotham
	name.Text = label
	name.TextColor3 = Theme.color("textDim")
	name.TextSize = Layout.target(s, 11)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Size = UDim2.new(1, trailing and -Layout.target(s, 96) or 0, 1, 0)
	name.Parent = row

	if trailing then
		local tail = Instance.new("TextLabel")
		tail.BackgroundTransparency = 1
		tail.Font = Enum.Font.GothamMedium
		tail.Text = trailing
		tail.TextColor3 = Theme.color("text")
		tail.TextSize = Layout.target(s, 11)
		tail.TextXAlignment = Enum.TextXAlignment.Right
		tail.Size = UDim2.new(0, Layout.target(s, 92), 1, 0)
		tail.Position = UDim2.new(1, -Layout.target(s, 92), 0, 0)
		tail.Parent = row
	end

	return row
end

return Cards

end

-- >>> Components/Buttons
AB.modules["Components/Buttons"] = function(AB)
--[[
	Components/Buttons.lua — the only button factory in AFTERBURN.

	Sizes are always derived: callers pass a role ("primary", "ghost", "nav",
	"icon") and a live scale, and the height comes back at or above the 44 px
	post-scale floor. A click with no handler is a build error, not a decoration.

	`Buttons.create` returns the instance; state lives in attributes so the
	themer can repaint a button without the caller tracking tokens.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Config = AB.Require("Config")

local Buttons = {}

local ROLES = {
	primary = { bg = "accent", text = "accentText", stroke = "accent", bold = true },
	ghost = { bg = "surfaceAlt", text = "text", stroke = "border", bold = false },
	nav = { bg = "rail", text = "textDim", stroke = "rail", bold = false },
	icon = { bg = "surfaceAlt", text = "text", stroke = "border", bold = false },
	danger = { bg = "danger", text = "textInverse", stroke = "danger", bold = true },
}

--- opts: { text, role, scale, parent, onClick, width, order, tooltip, name }
function Buttons.create(opts)
	local o = opts or {}
	local role = ROLES[o.role or "ghost"] or ROLES.ghost
	local scale = Layout.clampScale(o.scale or 1)
	-- Post-scale floor, expressed pre-scale. This is the whole 44 px contract.
	local height = Layout.target(scale)
	local width = o.width

	if not o.onClick then
		warn(("AFTERBURN buttons: '%s' has no onClick"):format(tostring(o.text or o.name)))
	end

	local button = Instance.new("TextButton")
	button.Name = o.name or "Button"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.color(role.bg)
	button.BackgroundTransparency = o.role == "nav" and 1 or 0
	button.BorderSizePixel = 0
	button.Font = role.bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	button.Text = o.text or ""
	button.TextColor3 = Theme.color(role.text)
	button.TextSize = Layout.target(scale, 12)
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.LayoutOrder = o.order or 1
	button.Size = if_width(width, height, scale, o)
	button:SetAttribute("Role", o.role or "ghost")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	if role.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.color(role.stroke)
		stroke.Thickness = 1
		stroke.Transparency = o.role == "nav" and 1 or 0.35
		stroke.Parent = button
	end

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingLeft = UDim.new(0, Layout.target(scale, 8))
	innerPad.PaddingRight = UDim.new(0, Layout.target(scale, 8))
	innerPad.Parent = button

	local function tween(transparency, strokeTransparency)
		if not Config.ui.animations then
			button.BackgroundTransparency = transparency
			return
		end
		local info = TweenInfo.new(Config.ui.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goal = { BackgroundTransparency = transparency }
		local tweenObj = TweenService:Create(button, info, goal)
		tweenObj:Play()
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke and strokeTransparency then
			local sInfo = TweenInfo.new(Config.ui.animationSpeed)
			TweenService:Create(stroke, sInfo, { Transparency = strokeTransparency }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.color(o.role == "primary" and "accentHover" or "railActive")
		tween(button.BackgroundTransparency - 0.08)
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.color(role.bg)
		tween(o.role == "nav" and 1 or 0)
	end)

	button.Activated:Connect(function()
		if o.onClick then
			local ok, err = pcall(o.onClick, button)
			if not ok then
				warn(("AFTERBURN buttons: '%s' handler failed: %s"):format(tostring(o.text), tostring(err)))
			end
		end
	end)

	if o.parent then
		button.Parent = o.parent
	end

	return button
end

--- Width helper kept separate so the size expression reads once.
function if_width(width, height, scale, o)
	if width then
		return UDim2.new(0, math.max(Layout.target(scale), width * scale), 0, height)
	end
	if o and o.fill then
		return UDim2.new(1, 0, 0, height)
	end
	return UDim2.new(0, Layout.target(scale, 120), 0, height)
end

--- Repaints a button after a theme change, using its role attribute.
function Buttons.repaint(button)
	local role = ROLES[button:GetAttribute("Role") or "ghost"] or ROLES.ghost
	button.BackgroundColor3 = Theme.color(role.bg)
	button.TextColor3 = Theme.color(role.text)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.color(role.stroke)
	end
end

return Buttons

end

-- >>> Components/Badges
AB.modules["Components/Badges"] = function(AB)
--[[
	Components/Badges.lua — provenance chips and the status dot.

	A chip is the visible half of the simulated/live contract: if a value is on
	screen, something next to it says where it came from. Chips are inert (a
	TextLabel, not a button) so nothing pretends to be clickable.

	Tokens only — no colour literal lives outside Core/Theme.
]]

local AB = AB or _G.AFTERBURN

local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local Badges = {}

-- Label text and the colour token behind it. STALE exists for Stage 7, when a
-- live read can age out; it is wired now so the vocabulary does not grow later.
local KINDS = {
	simulated = { text = "SIMULATED", token = "warning", transparency = 0.86 },
	live = { text = "LIVE", token = "success", transparency = 0.86 },
	stale = { text = "STALE", token = "textDim", transparency = 0.9 },
}

--- A small capsule reading SIMULATED / LIVE / STALE.
function Badges.chip(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local kind = KINDS[o.kind or "simulated"] or KINDS.simulated

	local chip = Instance.new("TextLabel")
	chip.Name = "Badge"
	chip.BackgroundColor3 = Theme.color(kind.token)
	chip.BackgroundTransparency = kind.transparency
	chip.BorderSizePixel = 0
	chip.Text = kind.text
	chip.Font = Enum.Font.GothamBold
	chip.TextColor3 = Theme.color(kind.token)
	chip.TextSize = Layout.target(scale, 9)
	chip.TextXAlignment = Enum.TextXAlignment.Center
	chip.Size = UDim2.fromOffset(math.ceil(Layout.target(scale, 52) * scale), math.ceil(Layout.target(scale, 15) * scale))
	chip.LayoutOrder = o.order or 1
	chip:SetAttribute("Kind", o.kind or "simulated")
	chip:SetAttribute("Badge", true)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = chip

	-- The positional parent wins over opts.parent: callers pass either, and
	-- before this a chip built with only the positional argument was never
	-- parented at all, so it existed but never appeared in the tree.
	local target = o.parent or parent
	if target then
		chip.Parent = target
	end

	return chip
end

--- A chip for a badged value; nil in, nil out so callers can stay terse.
function Badges.forValue(parent, badged, scale, order)
	if type(badged) ~= "table" then
		return nil
	end
	return Badges.chip(parent, { kind = badged.provenance, scale = scale, order = order })
end

local DOTS = {
	idle = "textDim",
	active = "success",
	busy = "accent",
	warn = "warning",
	down = "danger",
}

--- A 8 px status dot; the label beside it carries the meaning.
function Badges.dot(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local size = math.max(6, math.ceil(Layout.target(scale, 8) * scale))

	local dot = Instance.new("Frame")
	dot.Name = "Dot"
	dot.BackgroundColor3 = Theme.color(DOTS[o.state or "idle"] or "textDim")
	dot.BorderSizePixel = 0
	dot.Size = UDim2.fromOffset(size, size)
	dot.LayoutOrder = o.order or 1
	dot:SetAttribute("State", o.state or "idle")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot

	local target = o.parent or parent
	if target then
		dot.Parent = target
	end

	return dot
end

return Badges

end

-- >>> Components/Stats
AB.modules["Components/Stats"] = function(AB)
--[[
	Components/Stats.lua — a headline value with its provenance chip.

	The component takes the *pair* from Core/DataManager ({ value, provenance }),
	not a bare value. That is what makes a badge structurally hard to forget: a
	caller that passes a plain string gets a placeholder, and the suite counts
	unbadged values it finds.

	A missing value is not an error. The tile shows a dash, marks itself
	Placeholder, and the page keeps rendering.
]]

local AB = AB or _G.AFTERBURN

local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Badges = AB.Require("Components.Badges")

local Stats = {}

local PLACEHOLDER = "\u{2014}" -- em dash

--- A tile: label above, large value below, chip in the corner.
function Stats.tile(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local padPx = Layout.target(scale, 9)

	local badged = type(o.value) == "table" and o.value or nil
	local text = badged and tostring(badged.value or PLACEHOLDER) or PLACEHOLDER
	local isPlaceholder = badged == nil or badged.value == nil

	local tile = Instance.new("Frame")
	tile.Name = "Stat"
	tile.BackgroundColor3 = Theme.color("surfaceAlt")
	tile.BackgroundTransparency = 0
	tile.BorderSizePixel = 0
	tile.Size = UDim2.new(1, 0, 0, 0)
	tile.AutomaticSize = Enum.AutomaticSize.Y
	tile.LayoutOrder = o.order or 1
	tile:SetAttribute("Placeholder", isPlaceholder)
	-- Renaming a tile must not hide it from anything that walks tiles.
	tile:SetAttribute("Tile", true)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = tile

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = tile

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, padPx)
	padding.PaddingRight = UDim.new(0, padPx)
	padding.PaddingTop = UDim.new(0, padPx)
	padding.PaddingBottom = UDim.new(0, padPx)
	padding.Parent = tile

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, math.max(2, Layout.gutter(scale) // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tile

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = 1
	head.Parent = tile

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = tostring(o.label or "—")
	label.TextColor3 = Theme.color("textDim")
	label.TextSize = Layout.target(scale, 10)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -56, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = 1
	label.Parent = head

	-- Chip is emitted only when the value actually carries a provenance, in the
	-- same head as the value, so an orphaned badge cannot be written.
	local prov = badged and badged.provenance or o.provenance
	if prov and badged and badged.value ~= nil then
		Badges.chip(head, { kind = prov, scale = scale, order = 2 })
	end

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.Text = text
	value.TextColor3 = Theme.color(isPlaceholder and "textDim" or "text")
	value.TextSize = Layout.target(scale, 20)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextWrapped = true
	value.Size = UDim2.new(1, 0, 0, 0)
	value.AutomaticSize = Enum.AutomaticSize.Y
	value.LayoutOrder = 2
	value:SetAttribute("Value", true)
	value:SetAttribute("Badged", badged ~= nil and badged.value ~= nil)
	value:SetAttribute("Placeholder", isPlaceholder)
	value.Parent = tile

	-- Same bug class as Badges.chip: the positional parent must win, otherwise a
	-- tile built with only the positional argument is created detached.
	local target = o.parent or parent
	if target then
		tile.Parent = target
	end

	return tile, value
end

--- Updates an existing tile in place, so a ticking value does not rebuild DOM.
function Stats.update(tile, badged)
	if tile == nil or tile.Parent == nil and tile.Name ~= "Stat" then
		return false
	end
	local value = tile:FindFirstChild("Value")
	if value == nil then
		return false
	end
	local has = type(badged) == "table" and badged.value ~= nil
	value.Text = has and tostring(badged.value) or PLACEHOLDER
	value.TextColor3 = Theme.color(has and "text" or "textDim")
	value:SetAttribute("Badged", has)
	value:SetAttribute("Placeholder", not has)
	tile:SetAttribute("Placeholder", not has)
	return true
end

return Stats

end

-- >>> Components/ProgressBar
AB.modules["Components/ProgressBar"] = function(AB)
--[[
	Components/ProgressBar.lua — determinate bar with a percentage label.

	Used by the Dashboard's feature overview. The fraction is clamped, so a
	provider handing back 1.4 or -0.2 cannot overdraw the track. A missing
	fraction draws an empty track and marks the row Placeholder instead of
	erroring — same degradation rule as the stat tile.
]]

local AB = AB or _G.AFTERBURN

local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Badges = AB.Require("Components.Badges")

local ProgressBar = {}

local function clamp01(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	if n < 0 then
		return 0
	elseif n > 1 then
		return 1
	end
	return n
end

--- A bar row: label and percent above, track below.
function ProgressBar.bar(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local fraction = clamp01(o.progress)
	local height = math.max(4, math.ceil(Layout.target(scale, 6) * scale))

	local wrap = Instance.new("Frame")
	wrap.Name = "Progress"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.LayoutOrder = o.order or 1
	wrap:SetAttribute("Placeholder", fraction == nil)
	wrap:SetAttribute("Fraction", fraction or 0)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, math.max(2, Layout.gutter(scale) // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = wrap

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = 1
	head.Parent = wrap

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = tostring(o.label or "—")
	label.TextColor3 = Theme.color("text")
	label.TextSize = Layout.target(scale, 11)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -70, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = 1
	label.Parent = head

	local percent = Instance.new("TextLabel")
	percent.Name = "Percent"
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBold
	percent.Text = fraction and ("%d%%"):format(math.floor(fraction * 100 + 0.5)) or "—"
	percent.TextColor3 = Theme.color(fraction and "text" or "textDim")
	percent.TextSize = Layout.target(scale, 10)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.Size = UDim2.fromOffset(math.ceil(Layout.target(scale, 34) * scale), math.ceil(Layout.target(scale, 14) * scale))
	percent.LayoutOrder = 2
	percent.Parent = head

	Badges.forValue(head, o.badge, scale, 3)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.color("track")
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Size = UDim2.new(1, 0, 0, height)
	track.LayoutOrder = 2
	track.Parent = wrap

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.color("accent")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(fraction or 0, 0, 1, 0)
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	if o.parent then
		wrap.Parent = o.parent
	end

	return wrap
end

--- Sets a new fraction without rebuilding the row.
function ProgressBar.set(wrap, progress)
	if wrap == nil then
		return false
	end
	local track = wrap:FindFirstChild("Track")
	local percent = wrap:FindFirstChild("Head") and wrap:FindFirstChild("Head"):FindFirstChild("Percent")
	if track == nil or percent == nil then
		return false
	end
	local fill = track:FindFirstChild("Fill")
	local fraction = clamp01(progress)
	if fill then
		fill.Size = UDim2.new(fraction or 0, 0, 1, 0)
	end
	percent.Text = fraction and ("%d%%"):format(math.floor(fraction * 100 + 0.5)) or "—"
	percent.TextColor3 = Theme.color(fraction and "text" or "textDim")
	wrap:SetAttribute("Placeholder", fraction == nil)
	wrap:SetAttribute("Fraction", fraction or 0)
	return true
end

return ProgressBar

end

-- >>> Components/Toggles
AB.modules["Components/Toggles"] = function(AB)
--[[
	Components/Toggles.lua — animated switch.

	The track is the hit target and is never shorter than the post-scale floor,
	so a thumb on glass has something to land on. The knob tweens; flipping is
	idempotent and the change callback is pcall-guarded.

	Every toggle carries an `Id` attribute so a caller can find it again after a
	rebuild instead of holding a stale reference.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Config = AB.Require("Config")

local Toggles = {}

-- TweenService is a global in Roblox but a service under test; resolve either
-- way once, and snap instead of tweening when neither is available.
local tweenService = TweenService
if not tweenService then
	local ok, service = pcall(function() return game:GetService("TweenService") end)
	if ok then
		tweenService = service
	end
end

--- opts: { label, value, scale, parent, id, onChange, order }
function Toggles.create(opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local height = Layout.target(scale)
	local knobSize = math.max(Layout.target(scale, 18), math.floor(height * 0.62))

	local row = Instance.new("Frame")
	row.Name = o.id or "Toggle"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = o.order or 1

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = o.label or ""
	label.TextColor3 = Theme.color("text")
	label.TextSize = Layout.target(scale, 12)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Size = UDim2.new(1, -Layout.target(scale, 64), 1, 0)
	label.Parent = row

	local trackWidth = math.max(Layout.target(scale, 44), knobSize * 2 + 4)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.AutoButtonColor = false
	track.BackgroundColor3 = Theme.color("track")
	track.BorderSizePixel = 0
	track.Text = ""
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.Size = UDim2.new(0, trackWidth, 0, height)
	track.Parent = row

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = Theme.color("knob")
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.new(0, knobSize, 0, knobSize)
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local state = { value = o.value and true or false, enabled = true, id = o.id }

	local function knobPosition(value)
		local inset = math.floor((track.AbsoluteSize.Y - knobSize) / 2)
		local inPx = Layout.target(scale, 3)
		if value then
			return UDim2.new(1, -(knobSize + inPx), 0.5, 0)
		end
		return UDim2.new(0, inPx, 0.5, 0)
	end

	local function paint(animate)
		local goal = knobPosition(state.value)
		track.BackgroundColor3 = Theme.color(state.value and "accent" or "track")
		if not animate or not Config.ui.animations or not tweenService then
			knob.Position = goal
			return
		end
		local ok = pcall(function()
			local info = TweenInfo.new(Config.ui.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tweenService:Create(knob, info, { Position = goal }):Play()
		end)
		if not ok then
			knob.Position = goal
		end
	end

	function state.set(value, fire)
		local next_value = value and true or false
		if state.value == next_value and fire ~= true then
			return state.value
		end
		state.value = next_value
		track:SetAttribute("On", next_value)
		paint(true)
		if fire and o.onChange then
			local ok, err = pcall(o.onChange, next_value)
			if not ok then
				warn(("AFTERBURN toggles: '%s' handler failed: %s"):format(tostring(o.id), tostring(err)))
			end
		end
		return state.value
	end

	function state.get()
		return state.value
	end

	function state.setEnabled(enabled)
		state.enabled = enabled and true or false
		track.BackgroundTransparency = state.enabled and 0 or 0.5
		label.TextColor3 = Theme.color(state.enabled and "text" or "disabled")
		track.Active = state.enabled
	end

	track.Activated:Connect(function()
		if state.enabled then
			state.set(not state.value, true)
		end
	end)

	paint(false)
	track:SetAttribute("On", state.value)

	if o.parent then
		row.Parent = o.parent
	end

	return row, state
end

return Toggles

end

-- >>> Core/NotificationManager
AB.modules["Core/NotificationManager"] = function(AB)
--[[
	Core/NotificationManager.lua — bounded toast queue.

	Three visible at a time (Config.ui.notifications.max), oldest evicted first,
	auto-dismiss on a timer. Severity changes the accent stripe and the border,
	never the layout, so a toast appearing does not shove the shell around.

	`push` returns the id so a caller can dismiss a toast early; ids are
	monotonic and never reused.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local NotificationManager = {}

local state = {
	host = nil,
	scale = 1,
	live = {},
	seq = 0,
	alive = false,
}

local function later(seconds, fn)
	if type(task) == "table" and task.delay then
		task.delay(seconds, fn)
	elseif type(delay) == "function" then
		delay(seconds, fn)
	else
		fn()
	end
end

--------------------------------------------------------------------- api ----

function NotificationManager.mount(parent, scale)
	state.host = Instance.new("Frame")
	state.host.Name = "Toasts"
	state.host.BackgroundTransparency = 1
	state.host.AnchorPoint = Vector2.new(1, 1)
	state.host.Position = UDim2.new(1, -8, 1, -8)
	state.host.Size = UDim2.new(0, 0, 0, 0)
	state.host.ZIndex = 40
	state.host.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = state.host

	state.scale = scale or 1
	state.alive = true
	return state.host
end

function NotificationManager.dismiss(id)
	for index, record in ipairs(state.live) do
		if record.id == id then
			table.remove(state.live, index)
			if record.frame and record.frame.Parent then
				record.frame:Destroy()
			end
			return true
		end
	end
	return false
end

function NotificationManager.clear()
	for _, record in ipairs(state.live) do
		if record.frame and record.frame.Parent then
			record.frame:Destroy()
		end
	end
	state.live = {}
end

function NotificationManager.count()
	return #state.live
end

--- opts: { title, body, kind ("info"|"success"|"warning"|"danger"), lifetime }
function NotificationManager.push(opts)
	if not state.alive or not state.host then
		return nil
	end

	local o = type(opts) == "table" and opts or { title = tostring(opts) }
	local max = Config.ui.notifications.max

	while #state.live >= max do
		NotificationManager.dismiss(state.live[1].id)
	end

	state.seq = state.seq + 1
	local id = state.seq
	local kind = o.kind or "info"
	local stripeToken = kind == "danger" and "danger" or kind == "warning" and "warning" or kind == "success" and "success" or "accent"

	local frame = Instance.new("Frame")
	frame.Name = "Toast" .. id
	frame.BackgroundColor3 = Theme.color("toast")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0, Layout.target(state.scale, 210), 0, Layout.target(state.scale, 52))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = id
	frame.Parent = state.host

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = frame

	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.BackgroundColor3 = Theme.color(stripeToken)
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(0, Layout.target(state.scale, 3), 1, 0)
	stripe.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, Layout.target(state.scale, 12))
	pad.PaddingRight = UDim.new(0, Layout.target(state.scale, 10))
	pad.PaddingTop = UDim.new(0, Layout.target(state.scale, 8))
	pad.PaddingBottom = UDim.new(0, Layout.target(state.scale, 8))
	pad.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = o.title or "Notice"
	title.TextColor3 = Theme.color("text")
	title.TextSize = Layout.target(state.scale, 11)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Size = UDim2.new(1, 0, 0, Layout.target(state.scale, 14))
	title.LayoutOrder = 1
	title.Parent = frame

	if o.body then
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham
		body.Text = o.body
		body.TextColor3 = Theme.color("textDim")
		body.TextSize = Layout.target(state.scale, 10)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.LayoutOrder = 2
		body.Parent = frame
	end

	table.insert(state.live, { id = id, frame = frame, kind = kind })

	later(o.lifetime or Config.ui.notifications.lifetime, function()
		NotificationManager.dismiss(id)
	end)

	return id
end

function NotificationManager.destroy()
	NotificationManager.clear()
	if state.host then
		state.host:Destroy()
	end
	state.host = nil
	state.alive = false
end

return NotificationManager

end

-- >>> Core/Navigation
AB.modules["Core/Navigation"] = function(AB)
--[[
	Core/Navigation.lua — tab registry and mount/unmount state machine.

	Holds no UI of its own; Shell draws the rail and calls `select`. The module
	guarantees two things the suite checks: exactly one page mounted at a time,
	and teardown that leaves the content host as empty as it found it.

	A page descriptor is:
		{ id, title, glyph, order, blurb, mount(host, ctx) -> Instance, unmount?(instance) }
	mount returning nil is a fault, not a no-op, and is reported through onError.
]]

local AB = AB or _G.AFTERBURN

local Navigation = {}

local function new(ctx)
	local self = {
		tabs = {},
		byId = {},
		ctx = ctx,
		host = ctx.host,
		current = nil,
		mounted = nil,
		history = {},
		listeners = {},
		errors = {},
		destroyed = false,
	}

	local function report(id, stage, err)
		self.errors[#self.errors + 1] = { id = id, stage = stage, message = tostring(err) }
		warn(("AFTERBURN nav: %s of '%s' failed: %s"):format(stage, tostring(id), tostring(err)))
	end

	-- Pages receive this ctx on mount, so it must be usable even when the caller
	-- built the router with only a host. Every page may call ctx.scale().
	if type(self.ctx) ~= "table" then
		self.ctx = {}
	end
	if type(self.ctx.scale) ~= "function" then
		self.ctx.scale = function()
			return 1
		end
	end

	function self.onChange(listener)
		self.listeners[#self.listeners + 1] = listener
		return function()
			for index, candidate in ipairs(self.listeners) do
				if candidate == listener then
					table.remove(self.listeners, index)
					return
				end
			end
		end
	end

	function self.register(descriptor)
		if type(descriptor) ~= "table" or type(descriptor.id) ~= "string" then
			return nil, "descriptor needs an id"
		end
		if type(descriptor.mount) ~= "function" then
			return nil, ("descriptor '%s' has no mount"):format(descriptor.id)
		end
		if self.byId[descriptor.id] then
			return nil, ("duplicate tab id '%s'"):format(descriptor.id)
		end

		local record = {
			id = descriptor.id,
			title = descriptor.title or descriptor.id,
			glyph = descriptor.glyph or "",
			blurb = descriptor.blurb or "",
			order = descriptor.order or (#self.tabs + 1),
			descriptor = descriptor,
		}
		self.tabs[#self.tabs + 1] = record
		self.byId[record.id] = record
		table.sort(self.tabs, function(a, b)
			if a.order == b.order then
				return a.id < b.id
			end
			return a.order < b.order
		end)
		return record
	end

	function self.list()
		return self.tabs
	end

	function self.unmountCurrent()
		if not self.mounted then
			return true
		end
		local record = self.byId[self.current]
		local instance = self.mounted
		self.mounted = nil

		local ok, err = true, nil
		if record and type(record.descriptor.unmount) == "function" then
			ok, err = pcall(record.descriptor.unmount, instance)
		else
			ok, err = pcall(function()
				instance:Destroy()
			end)
		end
		if not ok then
			report(self.current, "unmount", err)
		end
		return ok
	end

	function self.select(id, opts)
		if self.destroyed then
			return false, "destroyed"
		end
		local record = self.byId[id]
		if not record then
			return false, ("no tab '%s'"):format(tostring(id))
		end
		if self.current == id and not (opts and opts.force) then
			return true, nil
		end

		self.unmountCurrent()

		local ok, instance = pcall(record.descriptor.mount, self.host, self.ctx)
		if not ok then
			report(id, "mount", instance)
			self.current = nil
			return false, instance
		end
		if instance == nil then
			report(id, "mount", "mount returned nil")
			self.current = nil
			return false, "mount returned nil"
		end

		self.mounted = instance
		self.current = id
		table.insert(self.history, id)

		for _, listener in ipairs(self.listeners) do
			pcall(listener, record, instance)
		end

		return true, nil
	end

	function self.back()
		if #self.history < 2 then
			return false
		end
		table.remove(self.history)
		local previous = self.history[#self.history]
		table.remove(self.history)
		return self.select(previous)
	end

	function self.destroy()
		self.unmountCurrent()
		self.destroyed = true
		self.listeners = {}
		self.history = {}
	end

	return self
end

Navigation.new = new

return Navigation

end

-- >>> Core/UIManager
AB.modules["Core/UIManager"] = function(AB)
--[[
	Core/UIManager.lua — owns the ScreenGui, the safe inset, the scale and the
	theme broadcast. Nothing else creates a ScreenGui.

	Theme wiring is centralised here on purpose: modules register an instance
	against a token mapping once, and `UIManager.applyTheme()` repaints all of
	them after a switch. That is why no screen module needs a colour literal.

	Privileged parenting is probed, never assumed: getgenv().HIDEUI, then
	gethui, then PlayerGui, then CoreGui. Under Studio all of them are absent
	except PlayerGui, so the shell still appears in the F5 test.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local UIManager = {}

local state = {
	gui = nil,
	root = nil,
	tags = {},
	buttons = {},
	metrics = nil,
	connections = {},
	alive = false,
}

------------------------------------------------------------------ helpers ----

local function guiInset()
	local guiService = game:GetService("GuiService")
	local ok, inset = pcall(function()
		return guiService:GetGuiInset()
	end)
	if ok and typeof(inset) == "Vector2" then
		return inset
	end
	return Vector2.new(0, 0)
end

local function viewport()
	local camera = workspace.CurrentCamera
	if camera then
		local ok, size = pcall(function()
			return camera.ViewportSize
		end)
		if ok and typeof(size) == "Vector2" then
			return size
		end
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui.AbsoluteSize
	end
	return Vector2.new(1024, 768)
end

local function protectedParent()
	local env = (type(getgenv) == "function" and getgenv()) or {}
	if env.HIDEUI then
		return env.HIDEUI
	end
	if type(gethui) == "function" then
		local ok, hidden = pcall(gethui)
		if ok and hidden then
			return hidden
		end
	end
	local player = game:GetService("Players").LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end
	local ok, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok then
		return core
	end
	return nil
end

--------------------------------------------------------------------- api ----

function UIManager.metrics()
	return state.metrics
end

function UIManager.isAlive()
	return state.alive
end

--- Registers a themed instance. `mapping` is { Property = tokenName }.
function UIManager.themed(instance, mapping)
	if instance and mapping then
		state.tags[instance] = mapping
	end
	return instance
end

function UIManager.registerButton(button)
	state.buttons[button] = true
	return button
end

function UIManager.applyTheme()
	local buttons = AB.Require("Components.Buttons")
	Theme.paint(state.tags)

	for button in pairs(state.buttons) do
		if button.Parent then
			pcall(buttons.repaint, button)
		else
			state.buttons[button] = nil
		end
	end

	if state.gui then
		state.gui:SetAttribute("Theme", Theme.current())
	end
end

--- Recomputes scale/geometry from the live viewport and re-styles the chrome.
function UIManager.refresh()
	if not state.alive or not state.root then
		return nil
	end

	local size = viewport()
	local metrics = Layout.metrics(size.X, size.Y)
	state.metrics = metrics

	state.root.Size = UDim2.new(0, metrics.windowWidth, 0, metrics.windowHeight)
	state.root.Position = UDim2.new(0.5, 0, 0.5, 0)
	state.root.UIScale.Scale = metrics.scale
	state.gui:SetAttribute("Compact", metrics.compact)
	state.gui:SetAttribute("Scale", metrics.scale)

	local shell = AB.Require("Core.Shell")
	if shell.isMounted() then
		shell.reflow(metrics)
	end

	return metrics
end

--- Mounts the ScreenGui and root frame. Returns the context other modules use.
function UIManager.mount()
	if state.alive then
		return nil, "already mounted"
	end

	local parent = protectedParent()
	if not parent then
		return nil, "no Gui parent available"
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AfterburnUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 64
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("Theme", Theme.current())
	gui:SetAttribute("Version", Config.brand.version)

	-- A UIScale on the root keeps every child in pre-scale units, so Layout's
	-- post-scale floor stays true no matter how small the viewport gets.
	local root = Instance.new("Frame")
	root.Name = "Window"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = Theme.color("bg")
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Name = "UIScale"
	scale.Scale = 1
	scale.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = root

	local shadow = Instance.new("UIStroke")
	shadow.Color = Theme.color("border")
	shadow.Thickness = 1
	shadow.Parent = root

	local inset = guiInset()
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, math.max(8, math.floor(inset.Y)))
	pad.PaddingLeft = UDim.new(0, math.max(8, math.floor(inset.X)))
	pad.Parent = root

	local tainted = Instance.new("Frame")
	tainted.Name = "Tint"
	tainted.BackgroundColor3 = Theme.color("bgElevated")
	tainted.BackgroundTransparency = 1
	tainted.BorderSizePixel = 0
	tainted.Size = UDim2.new(1, 0, 1, 0)
	tainted.Parent = root

	UIManager.themed(root, { BackgroundColor3 = "bg" })
	UIManager.themed(shadow, { Color = "border" })

	state.gui = gui
	state.root = root
	state.alive = true
	state.tags = {}
	state.buttons = {}
	UIManager.themed(root, { BackgroundColor3 = "bg" })
	UIManager.themed(shadow, { Color = "border" })
	UIManager.themed(tainted, { BackgroundColor3 = "bgElevated" })

	gui.Parent = parent

	-- Viewport changes: reflow, never just shrink.
	local camera = workspace.CurrentCamera
	if camera then
		local ok, signal = pcall(function()
			return camera:GetPropertyChangedSignal("ViewportSize")
		end)
		if ok and signal then
			state.connections[#state.connections + 1] = signal:Connect(function()
				UIManager.refresh()
			end)
		end
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local ok, signal = pcall(function()
			return playerGui:GetPropertyChangedSignal("AbsoluteSize")
		end)
		if ok and signal then
			state.connections[#state.connections + 1] = signal:Connect(function()
				UIManager.refresh()
			end)
		end
	end

	UIManager.refresh()

	local ctx = {
		gui = gui,
		root = root,
		content = nil,
		scale = function()
			return state.metrics and state.metrics.scale or 1
		end,
		theme = Theme.current,
	}

	return ctx
end

function UIManager.destroy()
	if not state.alive then
		return
	end
	state.alive = false

	for _, connection in ipairs(state.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	state.connections = {}
	state.tags = {}
	state.buttons = {}

	if state.gui then
		state.gui:Destroy()
	end
	state.gui = nil
	state.root = nil
	state.metrics = nil
end

return UIManager

end

-- >>> Core/Shell
AB.modules["Core/Shell"] = function(AB)
--[[
	Core/Shell.lua — the chrome: header, navigation rail, drawer, content host,
	status bar. One mount, one teardown, no page knowledge beyond descriptors.

	Layout policy, per the spec's "reflow, not shrink":
	  * compact  -> rail shows glyphs only, drawer overlays the content column
	  * medium   -> full rail, drawer still overlays
	  * wide     -> drawer docks beside the rail, content shares the row

	Dropping to a hidden rail and overlaying is what keeps every label readable at
	0.7 scale on a 412 px screen, where a nine-item labelled rail could not fit.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Buttons = AB.Require("Components.Buttons")
local Cards = AB.Require("Components.Cards")

local Shell = {}

local state = {
	mounted = false,
	ctx = nil,
	nav = nil,
	metrics = nil,
	parts = {},
	railButtons = {},
	drawerOpen = false,
	drag = nil,
	connections = {},
}

local function pad(px)
	return UDim.new(0, px)
end

local function connect(signal, fn)
	local connection = signal:Connect(fn)
	state.connections[#state.connections + 1] = connection
	return connection
end

------------------------------------------------------------------- pieces ----

local function buildHeader(parent, scale)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.color("header")
	header.BackgroundTransparency = 0
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Layout.target(scale, 46))
	header.LayoutOrder = 1
	header.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = pad(Layout.gutter(scale))
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = header

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(Layout.target(scale, 8))
	inner.PaddingRight = pad(Layout.target(scale, 8))
	inner.Parent = header

	local hamburger = Buttons.create({
		text = "☰",
		role = "icon",
		scale = scale,
		width = 44,
		parent = header,
		order = 1,
		name = "Hamburger",
		onClick = function()
			Shell.toggleDrawer()
		end,
	})

	local brand = Instance.new("Frame")
	brand.Name = "Brand"
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.new(1, -(Layout.target(scale, 150)), 1, 0)
	brand.LayoutOrder = 2
	brand.Parent = header

	local brandList = Instance.new("UIListLayout")
	brandList.Padding = pad(0)
	brandList.VerticalAlignment = Enum.VerticalAlignment.Center
	brandList.SortOrder = Enum.SortOrder.LayoutOrder
	brandList.Parent = brand

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = Config.brand.name
	title.TextColor3 = Theme.color("accent")
	title.TextSize = Layout.target(scale, 15)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, 0, 0, Layout.target(scale, 17))
	title.LayoutOrder = 1
	title.Parent = brand

	local tagline = Instance.new("TextLabel")
	tagline.Name = "Tagline"
	tagline.BackgroundTransparency = 1
	tagline.Font = Enum.Font.Gotham
	tagline.Text = Config.brand.tagline
	tagline.TextColor3 = Theme.color("textDim")
	tagline.TextSize = Layout.target(scale, 9)
	tagline.TextXAlignment = Enum.TextXAlignment.Left
	tagline.TextTruncate = Enum.TextTruncate.AtEnd
	tagline.Size = UDim2.new(1, 0, 0, Layout.target(scale, 11))
	tagline.LayoutOrder = 2
	tagline.Parent = brand

	local themeButton = Buttons.create({
		text = "◐",
		role = "icon",
		scale = scale,
		width = 44,
		parent = header,
		order = 3,
		name = "ThemeButton",
		onClick = function()
			local ok, err = Theme.toggle()
			if not ok then
				AB.Notify({ title = "Theme", body = tostring(err), kind = "danger" })
				return
			end
			AB.Require("Core.UIManager").applyTheme()
		end,
	})

	local close = Buttons.create({
		text = "✕",
		role = "icon",
		scale = scale,
		width = 44,
		parent = header,
		order = 4,
		name = "Close",
		onClick = function()
			AB.stop()
		end,
	})

	header.BackgroundColor3 = Theme.color("header")
	state.parts.header = header
	state.parts.themeButton = themeButton
	state.parts.close = close
	state.parts.hamburger = hamburger
	state.parts.title = title

	AB.Require("Core.UIManager").themed(header, { BackgroundColor3 = "header" })
	AB.Require("Core.UIManager").themed(title, { TextColor3 = "accent" })
	AB.Require("Core.UIManager").themed(tagline, { TextColor3 = "textDim" })
	for _, button in ipairs({ hamburger, themeButton, close }) do
		AB.Require("Core.UIManager").registerButton(button)
	end

	return header
end

local function buildRail(parent, metrics)
	local rail = Instance.new("ScrollingFrame")
	rail.Name = "Rail"
	rail.BackgroundColor3 = Theme.color("rail")
	rail.BorderSizePixel = 0
	rail.ScrollBarThickness = 0
	rail.CanvasSize = UDim2.new(0, 0, 0, 0)
	rail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rail.Size = UDim2.new(0, metrics.railWidth, 1, -Layout.target(metrics.scale, 46))
	rail.LayoutOrder = 2
	rail.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(math.max(2, metrics.gutter // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rail

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(math.max(2, metrics.gutter // 2))
	inner.PaddingRight = pad(math.max(2, metrics.gutter // 2))
	inner.PaddingTop = pad(metrics.gutter)
	inner.Parent = rail

	AB.Require("Core.UIManager").themed(rail, { BackgroundColor3 = "rail" })
	state.parts.rail = rail
	return rail
end

local function buildDrawer(parent, metrics)
	local drawer = Instance.new("Frame")
	drawer.Name = "Drawer"
	drawer.BackgroundColor3 = Theme.color("bgElevated")
	drawer.BorderSizePixel = 0
	drawer.ClipsDescendants = true
	drawer.Visible = false
	drawer.ZIndex = 20
	drawer.Size = UDim2.new(0, math.floor(230 * metrics.scale), 1, 0)
	drawer.Position = UDim2.new(0, -300, 0, 0)
	drawer.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(metrics.gutter)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Parent = drawer

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(metrics.gutter)
	inner.PaddingRight = pad(metrics.gutter)
	inner.PaddingTop = pad(metrics.gutter)
	inner.Parent = drawer

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = drawer

	AB.Require("Core.UIManager").themed(drawer, { BackgroundColor3 = "bgElevated" })
	AB.Require("Core.UIManager").themed(stroke, { Color = "border" })
	state.parts.drawer = drawer
	return drawer
end

local function buildContent(parent, metrics)
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Theme.color("border")
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 1, -Layout.target(metrics.scale, 46 + 18))
	content.LayoutOrder = 3
	content.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(metrics.gutter)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(metrics.gutter)
	inner.PaddingRight = pad(metrics.gutter)
	inner.PaddingTop = pad(metrics.gutter)
	inner.PaddingBottom = pad(metrics.gutter)
	inner.Parent = content

	AB.Require("Core.UIManager").themed(content, { ScrollBarImageColor3 = "border" })
	state.parts.content = content
	return content
end

local function buildStatusBar(parent, metrics)
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.BackgroundColor3 = Theme.color("header")
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 18))
	bar.LayoutOrder = 4
	bar.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Left"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = ""
	label.TextColor3 = Theme.color("textDim")
	label.TextSize = Layout.target(metrics.scale, 9)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -Layout.target(metrics.scale, 16), 1, 0)
	label.Position = UDim2.new(0, Layout.target(metrics.scale, 8), 0, 0)
	label.Parent = bar

	AB.Require("Core.UIManager").themed(bar, { BackgroundColor3 = "header" })
	AB.Require("Core.UIManager").themed(label, { TextColor3 = "textDim" })
	state.parts.statusBar = bar
	state.parts.statusLabel = label
	return bar
end

------------------------------------------------------------------- drawer ----

local function setDrawer(open)
	if not state.mounted then
		return
	end
	state.drawerOpen = open and true or false
	local drawer = state.parts.drawer
	local scrim = state.parts.scrim
	if not drawer then
		return
	end

	if state.metrics and state.metrics.sidebarMode == "docked" then
		drawer.Visible = true
		drawer.Position = UDim2.new(0, state.metrics.railWidth, 0, 0)
		if scrim then
			scrim.Visible = false
		end
		return
	end

	drawer.Visible = true
	local target = state.drawerOpen and UDim2.new(0, 0, 0, 0) or UDim2.new(0, -320, 0, 0)
	if Config.ui.animations then
		TweenService:Create(drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
	else
		drawer.Position = target
	end
	if scrim then
		scrim.Visible = state.drawerOpen
	end
	if not state.drawerOpen then
		task.delay(0.2, function()
			if not state.drawerOpen and drawer.Parent then
				drawer.Visible = false
			end
		end)
	end
end

--------------------------------------------------------------------- drag ----

local function beginDrag(input, header)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local root = state.ctx.root
	state.drag = {
		start = input.Position,
		origin = root.Position,
	}
end

local function moveDrag(input)
	local drag = state.drag
	if not drag then
		return
	end
	local root = state.ctx.root
	local delta = input.Position - drag.start
	root.Position = UDim2.new(drag.origin.X.Scale, drag.origin.X.Offset + delta.X, drag.origin.Y.Scale, drag.origin.Y.Offset + delta.Y)
end

local function endDrag()
	state.drag = nil
end

---------------------------------------------------------------------- api ----

function Shell.isMounted()
	return state.mounted
end

function Shell.toggleDrawer(open)
	setDrawer(open == nil and not state.drawerOpen or open)
end

function Shell.select(id)
	if not state.nav then
		return false
	end
	local ok = state.nav.select(id)
	if ok then
		for tabId, button in pairs(state.railButtons) do
			button.BackgroundColor3 = Theme.color(tabId == id and "railActive" or "rail")
			button.BackgroundTransparency = tabId == id and 0 or 1
		end
		if state.metrics and state.metrics.sidebarMode ~= "docked" then
			setDrawer(false)
		end
	end
	return ok
end

--- Applies metrics to the chrome. Called on mount and on every reflow.
function Shell.reflow(metrics)
	if not state.mounted then
		return
	end
	state.metrics = metrics

	local header = state.parts.header
	local rail = state.parts.rail
	local content = state.parts.content
	local drawer = state.parts.drawer
	local bar = state.parts.statusBar

	if header then
		header.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 46))
	end
	if rail then
		rail.Size = UDim2.new(0, metrics.railWidth, 1, -(Layout.target(metrics.scale, 46) + Layout.target(metrics.scale, 18)))
		rail.Visible = #state.nav.tabs > 0
	end
	if content then
		content.Size = UDim2.new(1, metrics.wide and -(metrics.railWidth + metrics.gutter) or 0, 1, -Layout.target(metrics.scale, 46 + 18))
		content.Position = UDim2.new(0, metrics.wide and (metrics.railWidth + metrics.gutter) or 0, 0, Layout.target(metrics.scale, 46))
	end

	-- Labels disappear on compact instead of shrinking into ellipses.
	for tabId, button in pairs(state.railButtons) do
		local record = state.nav.byId[tabId]
		local navLabel = record and record.glyph or ""
		if record and metrics.railMode == "full" then
			navLabel = record.glyph .. "  " .. record.title
		end
		button.Text = navLabel
		button.TextSize = Layout.target(metrics.scale, 11)
		button.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale))
	end

	if drawer then
		drawer.Size = UDim2.new(0, math.floor(230 * metrics.scale), 1, 0)
	end
	if bar then
		bar.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 18))
		bar.Visible = Config.ui.showStatusBar
	end
	if state.parts.statusLabel then
		local label = state.parts.statusLabel
		label.Text = ("%s · scale %.2f · %s · %d tabs"):format(
			Config.brand.version,
			metrics.scale,
			Theme.current(),
			#state.nav.tabs
		)
		label.TextSize = Layout.target(metrics.scale, 9)
	end

	setDrawer(state.drawerOpen)
end

function Shell.mount(ctx, metrics)
	if state.mounted then
		return Shell
	end

	local UIManager = AB.Require("Core.UIManager")
	local root = ctx.root
	local scale = metrics.scale

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(1, 0, 1, 0)
	column.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column
	state.parts.column = column

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, 0)
	body.LayoutOrder = 2
	body.Parent = column
	state.parts.body = body

	buildHeader(column, scale)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 1, -(Layout.target(scale, 46) + Layout.target(scale, 18)))
	row.Parent = body
	state.parts.row = row

	local rail = buildRail(row, metrics)
	local content = buildContent(row, metrics)

	-- Scrim sits above content, below the drawer, so a tap outside closes it.
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.BackgroundColor3 = Theme.color("scrim")
	scrim.BackgroundTransparency = 0.5
	scrim.BorderSizePixel = 0
	scrim.Text = ""
	scrim.Visible = false
	scrim.ZIndex = 15
	scrim.Size = UDim2.new(1, 0, 1, 0)
	scrim.Parent = row
	scrim.Activated:Connect(function()
		setDrawer(false)
	end)
	UIManager.themed(scrim, { BackgroundColor3 = "scrim" })
	state.parts.scrim = scrim

	local drawer = buildDrawer(row, metrics)
	buildStatusBar(column, metrics)

	ctx.host = content
	ctx.metrics = metrics
	state.ctx = ctx
	state.metrics = metrics
	state.mounted = true
	state.nav = AB.Require("Core.Navigation").new(ctx)

	-- Header drag: mouse and touch both feed the same handler.
	local header = state.parts.header
	connect(header.InputBegan, function(input)
		beginDrag(input, header)
	end)
	connect(header.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endDrag()
		end
	end)
	local userInput = game:GetService("UserInputService")
	connect(userInput.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			moveDrag(input)
		end
	end)
	connect(userInput.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endDrag()
		end
	end)

	-- Rail buttons and drawer rows both come from the same registry.
	function state.nav.rebuildNavSurfaces()
		local railList = rail
		local drawerList = drawer

		for _, record in ipairs(state.nav.tabs) do
			if not state.railButtons[record.id] then
				local railButton = Buttons.create({
					text = metrics.railMode == "full" and (record.glyph .. "  " .. record.title) or record.glyph,
					role = "nav",
					scale = scale,
					parent = railList,
					order = record.order,
					name = "Nav_" .. record.id,
					fill = true,
					onClick = function()
						Shell.select(record.id)
					end,
				})
				UIManager.registerButton(railButton)
				state.railButtons[record.id] = railButton
			end

			local rowButton = Buttons.create({
				text = record.glyph .. "  " .. record.title,
				role = "ghost",
				scale = scale,
				parent = drawerList,
				order = record.order,
				name = "Drawer_" .. record.id,
				fill = true,
				onClick = function()
					Shell.select(record.id)
				end,
			})
			UIManager.registerButton(rowButton)
		end
	end

	return Shell
end

function Shell.register(descriptor)
	if not state.mounted then
		return nil, "shell not mounted"
	end
	local record, err = state.nav.register(descriptor)
	if not record then
		return nil, err
	end
	return record
end

function Shell.finish()
	if not state.mounted then
		return
	end
	state.nav.rebuildNavSurfaces()
	Shell.reflow(state.metrics)
	if #state.nav.tabs > 0 then
		Shell.select(state.nav.tabs[1].id)
	end
end

function Shell.destroy()
	if not state.mounted then
		return
	end
	state.mounted = false

	for _, connection in ipairs(state.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	state.connections = {}

	if state.nav then
		state.nav.destroy()
		state.nav = nil
	end

	if state.parts.column then
		state.parts.column:Destroy()
	end

	state.parts = {}
	state.railButtons = {}
	state.ctx = nil
	state.metrics = nil
	state.drawerOpen = false
	state.drag = nil
end

return Shell

end

-- >>> Pages/Dashboard
AB.modules["Pages/Dashboard"] = function(AB)
--[[
	Pages/Dashboard.lua — the real Stage 2 page.

	Every value here arrives from Core/DataManager as { value, provenance } and
	is rendered with a SIMULATED chip beside it. Nothing on this page claims to
	be live: Config.live.enabled is false, no provider can read a real path yet,
	and the one line that says so is generated from that flag, not hardcoded.

	Quick-access controls carry their effect as data (`effect = {...}`) and are
	resolved by Dashboard.resolve, so a control whose target stopped existing
	fails a check instead of sitting there looking clickable.
]]

local AB = AB or _G.AFTERBURN

local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Session = AB.Require("Core.Session")
local DataManager = AB.Require("Core.DataManager")
local Cards = AB.Require("Components.Cards")
local Buttons = AB.Require("Components.Buttons")
local Badges = AB.Require("Components.Badges")
local Stats = AB.Require("Components.Stats")
local ProgressBar = AB.Require("Components.ProgressBar")

local Dashboard = {}

-- root -> stop(), so unmount can halt the tick chain without a returned handle.
local SESSIONS = setmetatable({}, { __mode = "k" })

Dashboard.id = "dashboard"
Dashboard.title = "Dashboard"
Dashboard.glyph = "◎"
Dashboard.order = 1
Dashboard.blurb = "Branding, session and status"

--- Controls and what each one actually does. Resolved by resolve() and by the suite.
Dashboard.effects = {
	{ id = "qa-farming", text = "Farming", effect = { kind = "navigate", page = "farming" } },
	{ id = "qa-mastery", text = "Mastery", effect = { kind = "navigate", page = "mastery" } },
	{ id = "qa-servers", text = "Servers", effect = { kind = "navigate", page = "servers" } },
	{ id = "qa-settings", text = "Settings", effect = { kind = "navigate", page = "settings" } },
	{ id = "qa-animations", text = "Toggle motion", effect = { kind = "setting", path = "ui.animations", flip = true } },
}

--- Applies an effect. Returns true when the target was real and the call landed.
function Dashboard.resolve(effect, ctx)
	if type(effect) ~= "table" then
		return false, "effect missing"
	end
	if effect.kind == "navigate" then
		local nav = ctx and ctx.nav
		if not nav or nav.byId[effect.page] == nil then
			return false, "no route " .. tostring(effect.page)
		end
		local selected, reason = nav.select(effect.page)
		return selected == true, reason
	elseif effect.kind == "setting" then
		local head, leaf = tostring(effect.path):match("^(%w+)%.(%w+)$")
		if not head or not leaf or Config[head] == nil or Config[head][leaf] == nil then
			return false, "no setting " .. tostring(effect.path)
		end
		if effect.flip then
			Config[head][leaf] = not Config[head][leaf]
		end
		return true
	end
	return false, "unknown effect " .. tostring(effect.kind)
end

-------------------------------------------------------------- fragments ----

-- A labelled value that always ships with its chip.
local function valueRow(body, label, badged, scale, order)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.LayoutOrder = order
	holder.Parent = body

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = holder

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Gotham
	text.Text = label
	text.TextColor3 = Theme.color("textDim")
	text.TextSize = Layout.target(scale, 10)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Size = UDim2.new(1, -60, 0, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.LayoutOrder = 1
	text.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.Text = badged and tostring(badged.value or "—") or "—"
	value.TextColor3 = Theme.color(badged and badged.value and "text" or "textDim")
	value.TextSize = Layout.target(scale, 12)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Size = UDim2.new(1, -60, 0, 0)
	value.AutomaticSize = Enum.AutomaticSize.Y
	value.LayoutOrder = 2
	value:SetAttribute("Value", true)
	value:SetAttribute("Badged", badged ~= nil and badged.value ~= nil)
	value:SetAttribute("Placeholder", badged == nil or badged.value == nil)
	value.Parent = holder

	-- Same rule as Stats.tile: no provenance, no chip, so a badge can never be
	-- written without the value it belongs to.
	if badged and badged.value ~= nil and badged.provenance then
		Badges.chip(holder, { kind = badged.provenance, scale = scale, order = 3 })
	end
	return holder
end

local function section(host, title, subtitle, scale, order)
	local card, body = Cards.create({
		title = title,
		subtitle = subtitle,
		scale = scale,
		parent = host,
		name = title,
		order = order,
	})
	return card, body
end

------------------------------------------------------------------ mount ----

function Dashboard.mount(host, ctx)
	local scale = Layout.clampScale(ctx.scale())
	local session = Session.new()
	local provider = ctx.provider or DataManager.new({ session = session })
	local provenance = provider._provenance

	-- Tick chain: a delay re-arms itself, so nothing busy-waits under Studio.
	local alive = true
	local elapsed = 0
	local timerLabel

	local root = Instance.new("Frame")
	root.Name = "DashboardPage"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = host

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Layout.gutter(scale))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local brand, brandBody = section(root, Config.brand.name, Config.brand.tagline, scale, 1)
	brandBody:SetAttribute("Brand", true)
	valueRow(brandBody, "Product", DataManager.badged(Config.brand.product, provenance), scale, 1)
	valueRow(brandBody, "Version", DataManager.badged(Config.brand.version, provenance), scale, 2)

	local welcome, welcomeBody = section(root, "Welcome", nil, scale, 2)
	welcomeBody:SetAttribute("Welcome", true)
	valueRow(welcomeBody, "Greeting", provider:welcome(), scale, 1)

	local identity, identityBody = section(root, "Operator", nil, scale, 3)
	identityBody:SetAttribute("Operator", true)
	local who = provider:identity()
	Stats.tile(identityBody, {
		label = "Name",
		value = who and who.value and DataManager.badged(who.value.name, provenance) or nil,
		provenance = provenance,
		scale = scale,
		order = 1,
	})
	Stats.tile(identityBody, {
		label = "Role",
		value = who and who.value and DataManager.badged(who.value.role, provenance) or nil,
		provenance = provenance,
		scale = scale,
		order = 2,
	})

	-- Session duration: the one row that moves on its own.
	local clock, clockBody = section(root, "Session", "Running since mount", scale, 4)
	clockBody:SetAttribute("Session", true)
	-- Uptime is measured rather than simulated, so its badge is built from a real
	-- badged pair instead of a hardcoded literal, and the tile applies the same
	-- chip rule as every other value.
	do
		local tile, value = Stats.tile(clockBody, {
			label = "Uptime",
			value = DataManager.badged(Session.format(0), provenance),
			provenance = provenance,
			scale = scale,
			order = 1,
		})
		tile.Name = "Uptime"
		timerLabel = value
	end

	local function tick()
		if not alive then
			return
		end
		elapsed = elapsed + 1
		if timerLabel and timerLabel.Parent then
			timerLabel.Text = Session.format(elapsed)
		end
		task.delay(1, tick)
	end
	task.delay(1, tick)

	local overview, overviewBody = section(root, "Feature overview", "Simulated progress", scale, 5)
	overviewBody:SetAttribute("Overview", true)
	for index, row in ipairs(provider:overview()) do
		ProgressBar.bar(overviewBody, {
			label = row.label,
			progress = row.progress,
			badge = DataManager.badged(row.progress, provenance),
			scale = scale,
			order = index,
		})
	end

	local activity, activityBody = section(root, "Activity", nil, scale, 6)
	local state = provider:activity()
	activityBody:SetAttribute("Activity", true)
	if state then
		local tile, value = Stats.tile(activityBody, {
			label = "Routine",
			value = state.value and DataManager.badged(state.value.text, provenance) or nil,
			provenance = provenance,
			scale = scale,
			order = 1,
		})
		tile.Name = "State"
		Badges.dot(tile, { state = state.value and state.value.state or "idle", scale = scale, order = 0 })
		value.Font = Enum.Font.GothamMedium
		value.TextSize = Layout.target(scale, 11)
	end

	local quick, quickBody = section(root, "Quick access", "Every control has a target", scale, 7)
	quickBody:SetAttribute("QuickAccess", true)
	for index, control in ipairs(Dashboard.effects) do
		local button = Buttons.create({
			text = control.text,
			role = index == 1 and "primary" or "ghost",
			scale = scale,
			fill = true,
			order = index,
			name = control.id,
			parent = quickBody,
			onClick = function()
				Dashboard.resolve(control.effect, ctx)
			end,
		})
		button:SetAttribute("Effect", control.effect.kind)
		button:SetAttribute("Target", control.effect.page or control.effect.path)
	end

	local feed, feedBody = section(root, "Notifications", ("Live data: %s"):format(Config.live.enabled and "on" or "off"), scale, 8)
	feedBody:SetAttribute("Feed", true)
	for index, item in ipairs(provider:feed()) do
		local line = Instance.new("Frame")
		line.Name = item.id
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.LayoutOrder = index
		line.Parent = feedBody

		local lineRow = Instance.new("UIListLayout")
		lineRow.FillDirection = Enum.FillDirection.Horizontal
		lineRow.VerticalAlignment = Enum.VerticalAlignment.Center
		lineRow.Padding = UDim.new(0, 6)
		lineRow.SortOrder = Enum.SortOrder.LayoutOrder
		lineRow.Parent = line

		Badges.dot(line, { state = item.kind == "warning" and "warn" or "idle", scale = scale, order = 1 })
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Gotham
		text.Text = item.text
		text.TextColor3 = Theme.color("textDim")
		text.TextSize = Layout.target(scale, 10)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		text.Size = UDim2.new(1, -30, 0, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.LayoutOrder = 2
		text.Parent = line
	end

	SESSIONS[root] = function()
		alive = false
		session:stop()
	end

	root:SetAttribute("Mounted", true)
	root:SetAttribute("Provenance", provenance)
	return root, {
		session = session,
		stop = function()
			alive = false
			session:stop()
		end,
	}
end

function Dashboard.unmount(root)
	local stop = root and SESSIONS[root]
	if stop then
		stop()
		SESSIONS[root] = nil
	end
	if root then
		root:Destroy()
	end
end

return Dashboard

end

-- >>> Pages/Farming
AB.modules["Pages/Farming"] = function(AB)
--[[
	Pages/Farming.lua — Farming tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Farming = {}

Farming.id = "farming"
Farming.title = "Farming"
Farming.glyph = "⌁"
Farming.order = 2
Farming.blurb = "Route and area configuration"

local PLANNED = {
	"Route profile selection",
	"Area picker with confirmation",
	"Run status indicator",
	"Progress bar with counts",
	"Stop / resume controls",
}

function Farming.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Farming",
		subtitle = "Route and area configuration",
		scale = scale,
		parent = host,
		name = "FarmingPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "3", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Farming.unmount(card)
	if card then
		card:Destroy()
	end
end

return Farming

end

-- >>> Pages/Mastery
AB.modules["Pages/Mastery"] = function(AB)
--[[
	Pages/Mastery.lua — Mastery tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Mastery = {}

Mastery.id = "mastery"
Mastery.title = "Mastery"
Mastery.glyph = "✦"
Mastery.order = 3
Mastery.blurb = "Weapon and fruit mastery targets"

local PLANNED = {
	"Weapon selector",
	"Fruit selector",
	"Current mastery display",
	"Target slider",
	"Progress to next tier",
}

function Mastery.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Mastery",
		subtitle = "Weapon and fruit mastery targets",
		scale = scale,
		parent = host,
		name = "MasteryPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "3", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Mastery.unmount(card)
	if card then
		card:Destroy()
	end
end

return Mastery

end

-- >>> Pages/Bosses
AB.modules["Pages/Bosses"] = function(AB)
--[[
	Pages/Bosses.lua — Bosses tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Bosses = {}

Bosses.id = "bosses"
Bosses.title = "Bosses"
Bosses.glyph = "☠"
Bosses.order = 4
Bosses.blurb = "Catalogue with location data"

local PLANNED = {
	"Searchable boss catalogue",
	"Spawn location column",
	"Respawn status tracking",
	"Filter by availability",
	"Detail panel",
}

function Bosses.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Bosses",
		subtitle = "Catalogue with location data",
		scale = scale,
		parent = host,
		name = "BossesPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "4", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Bosses.unmount(card)
	if card then
		card:Destroy()
	end
end

return Bosses

end

-- >>> Pages/Raids
AB.modules["Pages/Raids"] = function(AB)
--[[
	Pages/Raids.lua — Raids tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Raids = {}

Raids.id = "raids"
Raids.title = "Raids"
Raids.glyph = "◈"
Raids.order = 5
Raids.blurb = "Raid selection and timing"

local PLANNED = {
	"Raid type selection",
	"Chip and cost display",
	"Run progress steps",
	"Countdown timer",
	"Cooldown state",
}

function Raids.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Raids",
		subtitle = "Raid selection and timing",
		scale = scale,
		parent = host,
		name = "RaidsPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "4", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Raids.unmount(card)
	if card then
		card:Destroy()
	end
end

return Raids

end

-- >>> Pages/Fruits
AB.modules["Pages/Fruits"] = function(AB)
--[[
	Pages/Fruits.lua — Fruits tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Fruits = {}

Fruits.id = "fruits"
Fruits.title = "Fruits"
Fruits.glyph = "❖"
Fruits.order = 6
Fruits.blurb = "Catalogue, rarity and spawn log"

local PLANNED = {
	"Fruit catalogue grid",
	"Rarity colour key",
	"Spawn history list",
	"Search field",
	"Rarity filter chips",
	"Location column",
}

function Fruits.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Fruits",
		subtitle = "Catalogue, rarity and spawn log",
		scale = scale,
		parent = host,
		name = "FruitsPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "5", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Fruits.unmount(card)
	if card then
		card:Destroy()
	end
end

return Fruits

end

-- >>> Pages/Inventory
AB.modules["Pages/Inventory"] = function(AB)
--[[
	Pages/Inventory.lua — Inventory tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Inventory = {}

Inventory.id = "inventory"
Inventory.title = "Inventory"
Inventory.glyph = "▤"
Inventory.order = 7
Inventory.blurb = "Items, categories and equipment"

local PLANNED = {
	"Item catalogue by category",
	"Category tabs",
	"Equipped markers",
	"Sort control",
	"Search field",
}

function Inventory.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Inventory",
		subtitle = "Items, categories and equipment",
		scale = scale,
		parent = host,
		name = "InventoryPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "5", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Inventory.unmount(card)
	if card then
		card:Destroy()
	end
end

return Inventory

end

-- >>> Pages/Servers
AB.modules["Pages/Servers"] = function(AB)
--[[
	Pages/Servers.lua — Servers tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Servers = {}

Servers.id = "servers"
Servers.title = "Servers"
Servers.glyph = "▦"
Servers.order = 8
Servers.blurb = "Server metadata and history"

local PLANNED = {
	"Server identity block",
	"Player count readout",
	"Join history",
	"Region and ping column",
	"Refresh control",
}

function Servers.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Servers",
		subtitle = "Server metadata and history",
		scale = scale,
		parent = host,
		name = "ServersPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "6", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Servers.unmount(card)
	if card then
		card:Destroy()
	end
end

return Servers

end

-- >>> Pages/Settings
AB.modules["Pages/Settings"] = function(AB)
--[[
	Pages/Settings.lua — Settings tab.

	Still a partial page on purpose: the theme picker, scale slider and reset
	belong to their own stage. What is here is real — the switch is bound to
	Config.ui.animations, so flipping it changes behaviour that Toggles and the
	notification manager actually read, and a remount reflects the stored value.

	Every control on this page does something; nothing is a placeholder button.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")
local Toggles = AB.Require("Components.Toggles")
local Config = AB.Require("Config")

local Settings = {}

Settings.id = "settings"
Settings.title = "Settings"
Settings.glyph = "⚙"
Settings.order = 9
Settings.blurb = "Theme, scale and behaviour"

local PLANNED = {
	"Theme picker — stage 5",
	"UI scale slider — stage 5",
	"Reset to defaults — stage 6",
}

--- The trailing label of a Cards.row, which is created second.
local function trailing(row)
	local kids = row:GetChildren()
	return kids[#kids]
end

function Settings.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Settings",
		subtitle = "Theme, scale and behaviour",
		scale = scale,
		parent = host,
		name = "SettingsPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "2", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	local behaviour = Cards.row(body, "Behaviour", nil, scale, 4)
	behaviour.Name = "Behaviour"

	local readoutRow = Cards.row(body, "Animations", Config.ui.animations and "on" or "off", scale, 5)
	readoutRow.Name = "AnimationsRow"
	local readout = trailing(readoutRow)

	Toggles.create({
		id = "Animations",
		label = "Animate transitions",
		value = Config.ui.animations,
		scale = scale,
		parent = body,
		order = 6,
		onChange = function(value)
			Config.ui.animations = value and true or false
			if readout then
				readout.Text = value and "on" or "off"
			end
		end,
	})

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Settings.unmount(card)
	if card then
		card:Destroy()
	end
end

return Settings

end

-- >>> main
AB.modules["main"] = function(AB)
--[[
	src/main.lua — boot, containment, fault surface.

	The whole boot runs inside xpcall. A failure paints a red-bordered banner in
	the middle of the screen with the message and the failing stage, plus the
	version, so a broken paste in Studio never looks like "nothing happened".

	`_G.AFTERBURN` is the module host: Require, Notify, stop, plus the live
	context. Modules reach each other only through it, which is also what makes
	the single-file bundle possible.
]]

local AB = _G.AFTERBURN

if type(AB) ~= "table" then
	AB = {}
	_G.AFTERBURN = AB
end

AB.started = false
AB.stage = "idle"
AB.faults = {}

local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local UIManager = AB.Require("Core.UIManager")

local PAGES = {
	"Pages.Dashboard",
	"Pages.Farming",
	"Pages.Mastery",
	"Pages.Bosses",
	"Pages.Raids",
	"Pages.Fruits",
	"Pages.Inventory",
	"Pages.Servers",
	"Pages.Settings",
}

------------------------------------------------------------------- faults ----

local function faultBanner(message, stage)
	local parent = AB.context and AB.context.root
	if not parent then
		return nil
	end

	local UIManagerModule = AB.Require("Core.UIManager")
	local banner = Instance.new("Frame")
	banner.Name = "FaultBanner"
	banner.BackgroundColor3 = Theme.color("surface")
	banner.BorderSizePixel = 0
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0.5, 0)
	banner.Size = UDim2.new(0.86, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.ZIndex = 50
	banner.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("danger")
	stroke.Thickness = 2
	stroke.Parent = banner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = banner

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = banner

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Text = ("AFTERBURN failed at stage '%s'"):format(tostring(stage))
	heading.TextColor3 = Theme.color("danger")
	heading.TextSize = 13
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextWrapped = true
	heading.Size = UDim2.new(1, 0, 0, 0)
	heading.AutomaticSize = Enum.AutomaticSize.Y
	heading.LayoutOrder = 1
	heading.Parent = banner

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Code
	body.Text = tostring(message)
	body.TextColor3 = Theme.color("text")
	body.TextSize = 11
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 2
	body.Parent = banner

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.Gotham
	footer.Text = ("%s · theme %s · scale %.2f"):format(Config.brand.version, Theme.current(), AB.context.scale())
	footer.TextColor3 = Theme.color("textDim")
	footer.TextSize = 10
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextWrapped = true
	footer.Size = UDim2.new(1, 0, 0, 0)
	footer.AutomaticSize = Enum.AutoSize and Enum.AutomaticSize.Y or Enum.AutomaticSize.Y
	footer.LayoutOrder = 3
	footer.Parent = banner

	UIManagerModule.themed(banner, { BackgroundColor3 = "surface" })
	UIManagerModule.themed(stroke, { Color = "danger" })
	UIManagerModule.themed(heading, { TextColor3 = "danger" })
	UIManagerModule.themed(body, { TextColor3 = "text" })
	UIManagerModule.themed(footer, { TextColor3 = "textDim" })

	AB.faults[#AB.faults + 1] = { stage = stage, message = tostring(message) }
	return banner
end

AB.fault = faultBanner

-------------------------------------------------------------------- notify ----

function AB.Notify(opts)
	local manager = AB.Require("Core.NotificationManager")
	if manager and manager.count and AB.started then
		manager.push(opts)
	end
end

--------------------------------------------------------------- privileged ----

local function probe()
	return {
		getgenv = type(getgenv) == "function",
		gethui = type(gethui) == "function",
		writefile = type(writefile) == "function",
		identifyexecutor = type(identifyexecutor) == "function",
		task = type(task) == "table",
	}
end

AB.privileged = probe()

---------------------------------------------------------------------- boot ----

local function stage(name, fn)
	AB.stage = name
	local ok, result = xpcall(fn, function(err)
		return tostring(err) .. "\n" .. debug.traceback("", 2)
	end)
	if not ok then
		faultBanner(result, name)
		error(result, 0)
	end
	AB.stage = "idle"
	return result
end

function AB.start()
	if AB.started then
		return
	end

	stage("theme", function()
		assert(Theme.set(Config.theme.default), "default theme is not defined")
		local complete, problems = Theme.assertComplete()
		if not complete then
			warn("AFTERBURN theme: incomplete token set — " .. table.concat(problems, "; "))
		end
	end)

	local ctx = stage("mount", function()
		local mounted, err = UIManager.mount()
		assert(mounted, err or "mount failed")
		return mounted
	end)
	AB.context = ctx

	stage("notifications", function()
		local scale = ctx.scale()
		AB.Require("Core.NotificationManager").mount(ctx.root, scale)
	end)

	stage("shell", function()
		local shell = AB.Require("Core.Shell")
		shell.mount(ctx, Layout.metrics(ctx.gui.AbsoluteSize.X, ctx.gui.AbsoluteSize.Y))
	end)

	stage("pages", function()
		local shell = AB.Require("Core.Shell")
		for _, path in ipairs(PAGES) do
			local ok, page = pcall(AB.Require, path)
			if not ok then
				warn(("AFTERBURN boot: page module '%s' failed: %s"):format(path, tostring(page)))
			else
				local record, err = shell.register(page)
				if not record then
					warn(("AFTERBURN boot: page '%s' rejected: %s"):format(path, tostring(err)))
				end
			end
		end
	end)

	stage("finish", function()
		AB.Require("Core.Shell").finish()
	end)

	AB.started = true
	AB.Notify({
		title = "AFTERBURN online",
		body = Config.brand.tagline .. " · simulated data",
		kind = "success",
	})
end

function AB.stop()
	if not AB.started then
		return
	end
	AB.started = false

	pcall(function()
		AB.Require("Core.Shell").destroy()
	end)
	pcall(function()
		AB.Require("Core.NotificationManager").destroy()
	end)
	pcall(function()
		UIManager.destroy()
	end)

	AB.context = nil
end

-- Run when executed directly. Inside the bundle, Build.lua strips this guard
-- and calls AB.start() from the tail, so the bundle stays a single chunk.
if AB.autorun ~= false then
	AB.start()
end

return AB

end

-- Entry: load main, then start explicitly so a paste never half-runs.
AB.Require('main')
AB.autorun = true
AB.start()
