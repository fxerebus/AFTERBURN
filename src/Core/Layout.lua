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
