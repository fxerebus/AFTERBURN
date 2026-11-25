--[[
	Pages/Servers.lua — Servers tab descriptor (Stage 1 stub).

	Holds no logic yet: it mounts the header, the "simulated" marker and the
	planned surface list, so navigation and reflow can be exercised for real.
	Every line below becomes a working control in the stage named after it.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")

local Servers = {}

Servers.id = "servers"
Servers.title = "Servers"
Servers.glyph = "▦"
Servers.order = 8
Servers.blurb = "Server metadata and history"

local PLANNED = {
	"Server identity block",
	"Player count readout",
	"Join history",
	"Region and ping column",
	"Refresh control",
}

function Servers.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Servers",
		subtitle = "Server metadata and history",
		scale = scale,
		parent = host,
		name = "ServersPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "6", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Servers.unmount(card)
	if card then
		card:Destroy()
	end
end

return Servers
