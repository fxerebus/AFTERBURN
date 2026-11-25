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
