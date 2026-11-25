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
