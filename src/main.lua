--[[
	src/main.lua — boot, containment, fault surface.

	The whole boot runs inside xpcall. A failure paints a red-bordered banner in
	the middle of the screen with the message and the failing stage, plus the
	version, so a broken paste in Studio never looks like "nothing happened".

	`_G.AFTERBURN` is the module host: Require, Notify, stop, plus the live
	context. Modules reach each other only through it, which is also what makes
	the single-file bundle possible.
]]

local AB = _G.AFTERBURN

if type(AB) ~= "table" then
	AB = {}
	_G.AFTERBURN = AB
end

AB.started = false
AB.stage = "idle"
AB.faults = {}

local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local UIManager = AB.Require("Core.UIManager")

local PAGES = {
	"Pages.Dashboard",
	"Pages.Farming",
	"Pages.Mastery",
	"Pages.Bosses",
	"Pages.Raids",
	"Pages.Fruits",
	"Pages.Inventory",
	"Pages.Servers",
	"Pages.Settings",
}

------------------------------------------------------------------- faults ----

local function faultBanner(message, stage)
	local parent = AB.context and AB.context.root
	if not parent then
		return nil
	end

	local UIManagerModule = AB.Require("Core.UIManager")
	local banner = Instance.new("Frame")
	banner.Name = "FaultBanner"
	banner.BackgroundColor3 = Theme.color("surface")
	banner.BorderSizePixel = 0
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0.5, 0)
	banner.Size = UDim2.new(0.86, 0, 0, 0)
	banner.AutomaticSize = Enum.AutomaticSize.Y
	banner.ZIndex = 50
	banner.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("danger")
	stroke.Thickness = 2
	stroke.Parent = banner

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = banner

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.PaddingTop = UDim.new(0, 12)
	pad.PaddingBottom = UDim.new(0, 12)
	pad.Parent = banner

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = banner

	local heading = Instance.new("TextLabel")
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.Text = ("AFTERBURN failed at stage '%s'"):format(tostring(stage))
	heading.TextColor3 = Theme.color("danger")
	heading.TextSize = 13
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextWrapped = true
	heading.Size = UDim2.new(1, 0, 0, 0)
	heading.AutomaticSize = Enum.AutomaticSize.Y
	heading.LayoutOrder = 1
	heading.Parent = banner

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Code
	body.Text = tostring(message)
	body.TextColor3 = Theme.color("text")
	body.TextSize = 11
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 2
	body.Parent = banner

	local footer = Instance.new("TextLabel")
	footer.BackgroundTransparency = 1
	footer.Font = Enum.Font.Gotham
	footer.Text = ("%s · theme %s · scale %.2f"):format(Config.brand.version, Theme.current(), AB.context.scale())
	footer.TextColor3 = Theme.color("textDim")
	footer.TextSize = 10
	footer.TextXAlignment = Enum.TextXAlignment.Left
	footer.TextWrapped = true
	footer.Size = UDim2.new(1, 0, 0, 0)
	footer.AutomaticSize = Enum.AutoSize and Enum.AutomaticSize.Y or Enum.AutomaticSize.Y
	footer.LayoutOrder = 3
	footer.Parent = banner

	UIManagerModule.themed(banner, { BackgroundColor3 = "surface" })
	UIManagerModule.themed(stroke, { Color = "danger" })
	UIManagerModule.themed(heading, { TextColor3 = "danger" })
	UIManagerModule.themed(body, { TextColor3 = "text" })
	UIManagerModule.themed(footer, { TextColor3 = "textDim" })

	AB.faults[#AB.faults + 1] = { stage = stage, message = tostring(message) }
	return banner
end

AB.fault = faultBanner

-------------------------------------------------------------------- notify ----

function AB.Notify(opts)
	local manager = AB.Require("Core.NotificationManager")
	if manager and manager.count and AB.started then
		manager.push(opts)
	end
end

--------------------------------------------------------------- privileged ----

local function probe()
	return {
		getgenv = type(getgenv) == "function",
		gethui = type(gethui) == "function",
		writefile = type(writefile) == "function",
		identifyexecutor = type(identifyexecutor) == "function",
		task = type(task) == "table",
	}
end

AB.privileged = probe()

---------------------------------------------------------------------- boot ----

local function stage(name, fn)
	AB.stage = name
	local ok, result = xpcall(fn, function(err)
		return tostring(err) .. "\n" .. debug.traceback("", 2)
	end)
	if not ok then
		faultBanner(result, name)
		error(result, 0)
	end
	AB.stage = "idle"
	return result
end

function AB.start()
	if AB.started then
		return
	end

	stage("theme", function()
		assert(Theme.set(Config.theme.default), "default theme is not defined")
		local complete, problems = Theme.assertComplete()
		if not complete then
			warn("AFTERBURN theme: incomplete token set — " .. table.concat(problems, "; "))
		end
	end)

	local ctx = stage("mount", function()
		local mounted, err = UIManager.mount()
		assert(mounted, err or "mount failed")
		return mounted
	end)
	AB.context = ctx

	stage("notifications", function()
		local scale = ctx.scale()
		AB.Require("Core.NotificationManager").mount(ctx.root, scale)
	end)

	stage("shell", function()
		local shell = AB.Require("Core.Shell")
		shell.mount(ctx, Layout.metrics(ctx.gui.AbsoluteSize.X, ctx.gui.AbsoluteSize.Y))
	end)

	stage("pages", function()
		local shell = AB.Require("Core.Shell")
		for _, path in ipairs(PAGES) do
			local ok, page = pcall(AB.Require, path)
			if not ok then
				warn(("AFTERBURN boot: page module '%s' failed: %s"):format(path, tostring(page)))
			else
				local record, err = shell.register(page)
				if not record then
					warn(("AFTERBURN boot: page '%s' rejected: %s"):format(path, tostring(err)))
				end
			end
		end
	end)

	stage("finish", function()
		AB.Require("Core.Shell").finish()
	end)

	AB.started = true
	AB.Notify({
		title = "AFTERBURN online",
		body = Config.brand.tagline .. " · simulated data",
		kind = "success",
	})
end

function AB.stop()
	if not AB.started then
		return
	end
	AB.started = false

	pcall(function()
		AB.Require("Core.Shell").destroy()
	end)
	pcall(function()
		AB.Require("Core.NotificationManager").destroy()
	end)
	pcall(function()
		UIManager.destroy()
	end)

	AB.context = nil
end

-- Run when executed directly. Inside the bundle, Build.lua strips this guard
-- and calls AB.start() from the tail, so the bundle stays a single chunk.
if AB.autorun ~= false then
	AB.start()
end

return AB
