-- Geometry: the 44 px post-scale floor and the reflow policy.
local harness = require("tests.harness")

local world = harness.newWorld()
local Config = world.AB.Require("Config")
local Layout = world.AB.Require("Core.Layout")

harness.suite("layout")

harness.test("every width from 320 to 1920 keeps 44px after scale", function()
	for width = 320, 1920, 8 do
		local metrics = Layout.metrics(width, 800)
		harness.expect(metrics.target * metrics.scale >= Config.layout.targetPx - 0.001, ("floor broken at width %d"):format(width))
		harness.expect(Layout.meetsTarget(metrics), "meetsTarget disagrees at width " .. width)
	end
end)

harness.test("target grows as scale falls", function()
	local small = Layout.target(0.7)
	local full = Layout.target(1)
	harness.expect(small > full, "0.7 scale did not enlarge the target")
end)

harness.test("scale stays inside the configured band", function()
	for width = 100, 3000, 7 do
		local scale = Layout.scaleFor(width)
		harness.expect(scale >= Config.layout.minScale and scale <= Config.layout.maxScale, "scale escaped at " .. width)
	end
end)

harness.test("compact navigates from a top strip and drops the rail", function()
	local metrics = Layout.metrics(412, 892)
	harness.expect(metrics.compact)
	harness.equal(metrics.navMode, "tabs")
	harness.equal(metrics.railMode, "icons")
	harness.equal(metrics.sidebarMode, "overlay")
	harness.expect(Layout.reflects(metrics))
end)

harness.test("wide docks the drawer beside a full rail", function()
	local metrics = Layout.metrics(1280, 900)
	harness.expect(metrics.wide)
	harness.equal(metrics.navMode, "rail")
	harness.equal(metrics.railMode, "full")
	harness.equal(metrics.sidebarMode, "docked")
	harness.expect(Layout.reflects(metrics))
end)

harness.test("medium keeps a full rail but still overlays", function()
	local metrics = Layout.metrics(600, 900)
	harness.expect(metrics.medium, "600px should be medium")
	harness.equal(metrics.navMode, "rail")
	harness.equal(metrics.railMode, "full")
	harness.equal(metrics.sidebarMode, "overlay")
	harness.expect(Layout.reflects(metrics))
end)

harness.test("window width respects the configured bounds", function()
	for width = 320, 1920, 16 do
		local metrics = Layout.metrics(width, 800)
		harness.expect(metrics.windowWidth >= Config.layout.windowMin)
		harness.expect(metrics.windowWidth <= Config.layout.windowMax)
	end
end)


harness.test("compact draws exactly one nav surface, never a rail beside it", function()
	for _, width in ipairs({360, 390, 412}) do
		local metrics = Layout.metrics(width, 800)
		harness.expect(metrics.compact, "width " .. width .. " should be compact")
		harness.equal(metrics.navMode, "tabs", "navMode at " .. width)
		harness.equal(metrics.sidebarMode, "overlay", "sidebarMode at " .. width)
		harness.expect(metrics.tabStripHeight > 0, "no strip height at " .. width)
		harness.expect(Layout.reflects(metrics), "reflects failed at " .. width)
	end
end)

harness.test("compact content is full body width with no left offset", function()
	for _, width in ipairs({360, 390, 412}) do
		local metrics = Layout.metrics(width, 800)
		harness.equal(metrics.contentOffset, 0, "offset at " .. width)
		-- The body is the window; at compact nothing is subtracted from it.
		harness.equal(metrics.contentWidth, width, "contentWidth at " .. width)
	end
end)

harness.test("compact strip canvas is wider than the window, so it scrolls", function()
	for _, width in ipairs({360, 390, 412}) do
		local metrics = Layout.metrics(width, 800)
		local canvas = 9 * (Layout.target(metrics.scale, 74) + metrics.gutter) + metrics.gutter
		harness.expect(canvas > metrics.windowWidth, ("canvas %d not wider than window %d at %d"):format(canvas, metrics.windowWidth, width))
	end
end)

harness.test("wide keeps the rail and subtracts it from the content", function()
	local metrics = Layout.metrics(1280, 900)
	harness.equal(metrics.navMode, "rail")
	harness.equal(metrics.tabStripHeight, 0)
	harness.expect(metrics.contentOffset > 0)
end)

harness.test("content column never drops below the configured floor", function()
	for width = 320, 1920, 16 do
		local metrics = Layout.metrics(width, 800)
		harness.expect(metrics.contentWidth >= Config.layout.contentMin, ("contentWidth %d below floor %d at width %d"):format(metrics.contentWidth, Config.layout.contentMin, width))
	end
end)

harness.test("window height stays under 90% of viewport", function()
	for width = 320, 1920, 16 do
		for height = 600, 1200, 32 do
			local metrics = Layout.metrics(width, height)
			harness.expect(metrics.windowHeight <= metrics.windowHeightCap, ("windowHeight %d > cap %d at %dx%d"):format(metrics.windowHeight, metrics.windowHeightCap, width, height))
		end
	end
end)

harness.test("strip still fits inside the window height at compact", function()
	for _, width in ipairs({360, 390, 412}) do
		local metrics = Layout.metrics(width, 800)
		harness.expect(metrics.compact)
		-- Nine items plus gutters; the rail is a scroll surface, so it only needs
		-- to show one target at a time, but it must be tall enough for at least two
		-- so the user knows it scrolls.
		local needed = metrics.target * 2 + metrics.gutter
		harness.expect(metrics.windowHeight > needed, ("window %d too short for rail content %d at %d"):format(metrics.windowHeight, needed, width))
	end
end)
