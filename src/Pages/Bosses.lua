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
