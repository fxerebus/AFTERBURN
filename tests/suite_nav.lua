-- Router lifecycle: one page at a time, isolation, and no leaked instances.
local harness = require("tests.harness")

local world = harness.newWorld()
local AB = world.AB

harness.suite("navigation")

local PAGES = {
	"Pages.Dashboard", "Pages.Farming", "Pages.Mastery", "Pages.Bosses", "Pages.Raids",
	"Pages.Fruits", "Pages.Inventory", "Pages.Servers", "Pages.Settings",
}

local function build()
	local host = world.env.Instance.new("ScrollingFrame")
	local ctx = { host = host, root = host, scale = function() return 1 end }
	local nav = AB.Require("Core.Navigation").new(ctx)
	for _, path in ipairs(PAGES) do
		local page = AB.Require(path)
		local record, err = nav.register(page)
		harness.expect(record, "register failed for " .. path .. ": " .. tostring(err))
	end
	return nav, host
end

harness.test("all nine descriptors register in order", function()
	local nav = build()
	harness.equal(#nav.list(), 9)
	harness.equal(nav.list()[1].id, "dashboard")
	harness.equal(nav.list()[9].id, "settings")
	nav.destroy()
end)

harness.test("each page loads in isolation and mounts one instance", function()
	for _, path in ipairs(PAGES) do
		local page = AB.Require(path)
		local host = world.env.Instance.new("Frame")
		local instance = page.mount(host, { host = host, root = host, scale = function() return 1 end })
		harness.expect(instance ~= nil, path .. " mounted nothing")
		harness.equal(#instance.__children > 0, true, path .. " mounted an empty page")
		page.unmount(instance)
		harness.equal(#host.__children, 0, path .. " left a child behind")
	end
end)

harness.test("round-trips every tab with exactly one mounted", function()
	local nav, host = build()
	for _, path in ipairs(PAGES) do
		local id = AB.Require(path).id
		local ok = nav.select(id)
		harness.expect(ok, "select failed for " .. id)
		harness.equal(nav.current, id)
		harness.equal(#host.__children, 1, "more than one page mounted at " .. id)
	end
	nav.destroy()
	harness.equal(#host.__children, 0, "destroy left instances behind")
end)

harness.test("duplicate ids are rejected", function()
	local nav = build()
	local record, err = nav.register(AB.Require("Pages.Dashboard"))
	harness.equal(record, nil)
	harness.matches(err, "duplicate")
	nav.destroy()
end)

harness.test("a descriptor without mount is rejected", function()
	local nav = build()
	local record, err = nav.register({ id = "broken" })
	harness.equal(record, nil)
	harness.matches(err, "mount")
	nav.destroy()
end)

harness.test("history returns to the previous tab", function()
	local nav = build()
	nav.select("dashboard")
	nav.select("fruits")
	local ok = nav.back()
	harness.expect(ok)
	harness.equal(nav.current, "dashboard")
	nav.destroy()
end)

harness.test("selecting after destroy reports the state", function()
	local nav = build()
	nav.destroy()
	local ok, err = nav.select("dashboard")
	harness.equal(ok, false)
	harness.matches(err, "destroyed")
end)
