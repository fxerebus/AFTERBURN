--[[
	suite_toggles.lua — the Settings switch.

	Two things are asserted that a screenshot cannot: the post-scale hit floor on
	the track itself (not on the row around it), and that a flipped value survives
	an unmount/remount because it is read back from Config rather than held in a
	closure. Config.ui.animations is restored afterwards.
]]

local harness = require("tests.harness")

local world = harness.newWorld()
local AB = world.AB
local Layout = AB.Require("Core.Layout")
local Config = AB.Require("Config")

harness.suite("toggles")

local Settings = AB.Require("Pages.Settings")

--- The mock's FindFirstChild does not take a recursive flag, so walk instead.
local function find(node, name)
	if node.Name == name then
		return node
	end
	for _, child in ipairs(node.__children or {}) do
		local hit = find(child, name)
		if hit then
			return hit
		end
	end
	return nil
end

local function mount(scale)
	local host = world.env.Instance.new("ScrollingFrame")
	local card = Settings.mount(host, { host = host, root = host, scale = function() return scale or 1 end })
	local body = find(card, "Body") or card
	local row = find(body, "Animations")
	harness.expect(row ~= nil, "settings mounted no Animations switch")
	local track = find(row, "Track")
	harness.expect(track ~= nil, "switch has no track")
	return host, card, row, track
end

harness.test("the switch exists and is bound to the config key", function()
	local before = Config.ui.animations
	Config.ui.animations = true
	local _, card = mount(1)
	local track = find(card, "Track")
	harness.equal(track:GetAttribute("On"), true, "switch did not adopt the stored value")
	card:Destroy()
	Config.ui.animations = before
end)

harness.test("the track holds the hit floor after scale", function()
	for _, scale in ipairs({ 1, 0.85, 0.7 }) do
		local host, card, _, track = mount(scale)
		local floor = Layout.target(scale)
		local offset = track.Size.Y.Offset
		harness.expect(offset >= floor, ("track %dpx under the %dpx floor at scale %.2f"):format(offset, floor, scale))
		card:Destroy()
		host:Destroy()
	end
end)

harness.test("activating flips the config key and the readout", function()
	Config.ui.animations = true
	local _, card, _, track = mount(1)
	track.Activated:Fire()
	harness.equal(Config.ui.animations, false, "activation did not write the config key")
	local readout = find(card, "AnimationsRow")
	harness.expect(readout ~= nil, "readout row is missing")
	local tail = readout:GetChildren()
	harness.equal(tail[#tail].Text, "off", "readout did not follow the switch")
	track.Activated:Fire()
	harness.equal(Config.ui.animations, true, "second activation did not restore the key")
	card:Destroy()
end)

harness.test("a flipped value survives a remount", function()
	Config.ui.animations = false
	local _, card = mount(1)
	local track = find(card, "Track")
	harness.equal(track:GetAttribute("On"), false, "remount lost the stored value")
	card:Destroy()
	Config.ui.animations = true
end)
