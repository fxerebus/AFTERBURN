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
	contentMin = 168, -- content column never narrows past this
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
