--[[
	suite_dashboard.lua — the Stage 2 page, its badges, its timer, its controls.

	The badge check is the important one: it walks everything the page mounted
	and fails on any *materialised* value with no chip beside it. Placeholders
	are allowed to lack one; a value that claims to exist is not.
]]

local harness = require("tests.harness")

local world = harness.newWorld()
local AB = world.AB

harness.suite("dashboard")

local function walk(instance, out)
	for _, child in ipairs(instance.__children or {}) do
		out[#out + 1] = child
		walk(child, out)
	end
	return out
end

local function surface()
	local host = world.env.Instance.new("ScrollingFrame")
	local nav = AB.Require("Core.Navigation").new({ host = host })
	for _, path in ipairs({
		"Pages.Dashboard", "Pages.Farming", "Pages.Mastery", "Pages.Bosses", "Pages.Raids",
		"Pages.Fruits", "Pages.Inventory", "Pages.Servers", "Pages.Settings",
	}) do
		nav.register(AB.Require(path))
	end
	local ctx = { host = host, root = host, nav = nav, scale = function() return 1 end }
	return host, ctx, nav
end

harness.test("every named section mounts", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	for _, text in ipairs({ "Brand", "Welcome", "Operator", "Session", "Overview", "Activity", "QuickAccess", "Feed" }) do
		local hits = 0
		for _, node in ipairs(walk(root, {})) do
			if node:GetAttribute(text) == true then
				hits = hits + 1
			end
		end
		harness.equal(hits, 1, "section " .. text .. " not mounted exactly once")
	end
	page.unmount(root)
end)

harness.test("every materialised value carries a SIMULATED chip", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)

	local values, badged, chips = 0, 0, 0
	for _, node in ipairs(walk(root, {})) do
		if node:GetAttribute("Value") == true then
			values = values + 1
			if node:GetAttribute("Badged") == true then
				badged = badged + 1
			end
		end
		if node:GetAttribute("Badge") == true then
			chips = chips + 1
			if node:GetAttribute("Kind") ~= "simulated" then
				harness.equal(node:GetAttribute("Kind"), "simulated")
			end
		end
	end

	harness.expect(values > 0, "no values rendered at all")
	harness.equal(badged, values, "unbadged values present")
	harness.expect(chips >= values, "fewer chips than values")
	harness.equal(root:GetAttribute("Provenance"), "simulated")
	page.unmount(root)
end)

harness.test("identity, session and activity render as badged tiles", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)

	local tiles = {}
	for _, node in ipairs(walk(root, {})) do
		if node:GetAttribute("Tile") == true then
			tiles[#tiles + 1] = node
		end
	end
	harness.expect(#tiles >= 3, "expected tiles for name, role, uptime and routine")

	local checked = 0
	for _, tile in ipairs(tiles) do
		local value
		for _, child in ipairs(walk(tile, {})) do
			if child:GetAttribute("Value") == true then
				value = child
			end
		end
		harness.expect(value ~= nil, "tile has no value node")
		if value:GetAttribute("Badged") == true then
			-- The chip lives in the tile's Head, the value in the tile body, so the
			-- pairing is asserted across the whole tile rather than between siblings.
			local chips = 0
			for _, child in ipairs(walk(tile, {})) do
				if child:GetAttribute("Badge") == true then
					chips = chips + 1
				end
			end
			harness.equal(chips, 1, "badged tile value without exactly one chip")
			checked = checked + 1
		end
	end
	harness.expect(checked >= 3, "no badged tile values were actually checked")
	page.unmount(root)
end)

harness.test("timer advances under a stubbed clock", function()
	local Session = AB.Require("Core.Session")
	local now = 100
	local session = Session.new({ clock = function() return now end, at = 100 })
	harness.equal(session:ticks(), 0)
	now = 145
	harness.equal(session:ticks(), 45)
	now = 100 + 3722
	harness.equal(Session.format(session:ticks()), "1:02:02")
	session:stop()
	now = 99999
	harness.equal(session:ticks(), 3722, "stopped session kept running")
end)

harness.test("hour rollover formats without wrapping", function()
	local Session = AB.Require("Core.Session")
	harness.equal(Session.format(0), "0:00:00")
	harness.equal(Session.format(59), "0:00:59")
	harness.equal(Session.format(3599), "0:59:59")
	harness.equal(Session.format(3600), "1:00:00")
	harness.equal(Session.format(86399), "23:59:59")
	harness.equal(Session.format(-5), "0:00:00")
end)

harness.test("the page timer ticks", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	local before
	for _, node in ipairs(walk(root, {})) do
		if node.Name == "Value" and node.Parent and node.Parent.Name == "Uptime" then
			before = node.Text
		end
	end
	harness.expect(before ~= nil, "no timer label")
	world.step(2)
	local after
	for _, node in ipairs(walk(root, {})) do
		if node.Name == "Value" and node.Parent and node.Parent.Name == "Uptime" then
			after = node.Text
		end
	end
	harness.expect(after ~= before, "timer did not move after stepping the clock")
	page.unmount(root)
end)

harness.test("every quick-access control resolves to a real target", function()
	local host, ctx, nav = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)

	for _, node in ipairs(walk(root, {})) do
		if node:GetAttribute("Effect") then
			local kind = node:GetAttribute("Effect")
			local target = node:GetAttribute("Target")
			if kind == "navigate" then
				harness.expect(nav.byId[target] ~= nil, "dead route " .. tostring(target))
			elseif kind == "setting" then
				local head, leaf = tostring(target):match("^(%w+)%.(%w+)$")
				harness.expect(head and leaf and AB.Require("Config")[head] and AB.Require("Config")[head][leaf] ~= nil,
					"dead setting " .. tostring(target))
			else
				error("unknown effect kind " .. tostring(kind))
			end
		end
	end
	page.unmount(root)
end)

harness.test("the motion control actually flips its setting", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	local Config = AB.Require("Config")
	local before = Config.ui.animations
	local ok = page.resolve({ kind = "setting", path = "ui.animations", flip = true }, ctx)
	harness.expect(ok, "resolve refused a real setting")
	harness.equal(Config.ui.animations, not before)
	Config.ui.animations = before
	page.unmount(root)
end)

harness.test("a navigation control selects its page", function()
	local host, ctx, nav = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	local ok = page.resolve({ kind = "navigate", page = "servers" }, ctx)
	harness.expect(ok, "resolve refused a real route")
	harness.equal(nav.current, "servers")
	page.unmount(root)
end)

harness.test("an empty provider degrades to placeholders", function()
	local host, ctx = surface()
	ctx.provider = AB.Require("tests.fixtures.provider_blank") or loadfile("tests/fixtures/provider_blank.lua", "t", world.env)()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	local root_ok = root ~= nil
	harness.expect(root_ok, "blank provider broke the mount")
	local placeholders = 0
	for _, node in ipairs(walk(root, {})) do
		if node:GetAttribute("Placeholder") == true then
			placeholders = placeholders + 1
		end
	end
	harness.expect(placeholders > 0, "nothing marked as a placeholder")
	page.unmount(root)
	ctx.provider = nil
end)

harness.test("a provider missing a field still renders", function()
	local host, ctx = surface()
	ctx.provider = AB.Require("Core.DataManager").new({ mode = "partial" })
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	harness.expect(root ~= nil, "partial provider broke the mount")
	local unbadged = 0
	for _, node in ipairs(walk(root, {})) do
		if node:GetAttribute("Value") == true and node:GetAttribute("Badged") == false then
			unbadged = unbadged + 1
		end
	end
	harness.expect(unbadged > 0, "partial mode produced no missing values to degrade")
	page.unmount(root)
end)

harness.test("unmount stops the tick chain and clears the host", function()
	local host, ctx = surface()
	local page = AB.Require("Pages.Dashboard")
	local root = page.mount(host, ctx)
	page.unmount(root)
	harness.equal(#host.__children, 0, "page left instances behind")
	local before = #world.timers
	world.step(3)
	harness.expect(#world.timers <= before + 1, "tick chain kept re-arming after unmount")
end)

return true
