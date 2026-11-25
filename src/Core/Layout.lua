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

-- Roblox GUI pixels are physical. A 1080 px phone would otherwise read as a
-- desktop and never reach the compact branch. Portrait-ish viewports are divided
-- by a density derived from their short side so the breakpoints stay in
-- device-independent units; landscape viewports stay 1:1.
function Layout.density(width, height)
	local w = tonumber(width) or 0
	local h = tonumber(height) or 0
	-- Only clearly portrait viewports are treated as phones; a 600x900 tablet
	-- and every landscape desktop stay 1:1.
	if w <= 0 or h <= w * 1.6 then
		return 1
	end
	return clamp(math.min(w, h) / 420, 1, 3)
end

-- Everything a view needs in one table, derived from the viewport.
function Layout.metrics(width, height)
	local w = tonumber(width) or 0
	local h = tonumber(height) or 0
	-- Breakpoints read the normalised width, geometry keeps physical pixels.
	local logical = w / Layout.density(w, h)
	local scale = Layout.scaleFor(logical)
	local compact = logical < Config.layout.compactBelow
	local medium = logical >= Config.layout.compactBelow and logical < Config.layout.mediumBelow
	local wide = logical >= Config.layout.wideAt

	local railWidth = if_else(compact, 56, 168)
	local target = Layout.target(scale)

	return {
		width = w,
		height = h,
		logicalWidth = math.floor(logical),
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
		-- Content must keep real width; at compact the drawer overlays it, so
		-- nothing is subtracted for the rail.
		contentWidth = math.max(Config.layout.contentMin, math.floor(w - (if_else(wide, railWidth * scale, 0) + 2 * Layout.gutter(scale)))),
		windowWidth = clamp(math.floor(w * (if_else(compact, 0.94, 0.82))), Config.layout.windowMin, Config.layout.windowMax),
		windowHeightCap = math.floor(h * 0.9),
		-- Height also capped at 90% of the viewport so the window never runs off
		-- the bottom of a phone screen.
		windowHeight = math.floor(math.min(h * (if_else(compact, 0.86, 0.8)), h * 0.9)),
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
