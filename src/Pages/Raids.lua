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
