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
