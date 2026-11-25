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
