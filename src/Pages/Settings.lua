--[[
	Pages/Settings.lua — Settings tab.

	Still a partial page on purpose: the theme picker, scale slider and reset
	belong to their own stage. What is here is real — the switch is bound to
	Config.ui.animations, so flipping it changes behaviour that Toggles and the
	notification manager actually read, and a remount reflects the stored value.

	Every control on this page does something; nothing is a placeholder button.
]]

local AB = AB or _G.AFTERBURN
local Cards = AB.Require("Components.Cards")
local Layout = AB.Require("Core.Layout")
local Toggles = AB.Require("Components.Toggles")
local Config = AB.Require("Config")

local Settings = {}

Settings.id = "settings"
Settings.title = "Settings"
Settings.glyph = "⚙"
Settings.order = 9
Settings.blurb = "Theme, scale and behaviour"

local PLANNED = {
	"Theme picker — stage 5",
	"UI scale slider — stage 5",
	"Reset to defaults — stage 6",
}

--- The trailing label of a Cards.row, which is created second.
local function trailing(row)
	local kids = row:GetChildren()
	return kids[#kids]
end

function Settings.mount(host, ctx)
	local scale = ctx.scale()
	local card, body = Cards.create({
		title = "Settings",
		subtitle = "Theme, scale and behaviour",
		scale = scale,
		parent = host,
		name = "SettingsPage",
		order = 1,
	})

	Cards.row(body, "Status", "stub · simulated", scale, 1)
	Cards.row(body, "Build stage", "2", scale, 2)
	Cards.row(body, "Touch target", ("%d px @ %.2f"):format(Layout.target(scale), scale), scale, 3)

	local behaviour = Cards.row(body, "Behaviour", nil, scale, 4)
	behaviour.Name = "Behaviour"

	local readoutRow = Cards.row(body, "Animations", Config.ui.animations and "on" or "off", scale, 5)
	readoutRow.Name = "AnimationsRow"
	local readout = trailing(readoutRow)

	Toggles.create({
		id = "Animations",
		label = "Animate transitions",
		value = Config.ui.animations,
		scale = scale,
		parent = body,
		order = 6,
		onChange = function(value)
			Config.ui.animations = value and true or false
			if readout then
				readout.Text = value and "on" or "off"
			end
		end,
	})

	for index, line in ipairs(PLANNED) do
		Cards.row(body, line, nil, scale, 10 + index)
	end

	return card
end

function Settings.unmount(card)
	if card then
		card:Destroy()
	end
end

return Settings
