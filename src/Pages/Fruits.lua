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
