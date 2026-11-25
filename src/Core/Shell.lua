--[[
	Core/Shell.lua — the chrome: header, navigation rail, drawer, content host,
	status bar. One mount, one teardown, no page knowledge beyond descriptors.

	Layout policy, per the spec's "reflow, not shrink":
	  * compact  -> rail shows glyphs only, drawer overlays the content column
	  * medium   -> full rail, drawer still overlays
	  * wide     -> drawer docks beside the rail, content shares the row

	Dropping to a hidden rail and overlaying is what keeps every label readable at
	0.7 scale on a 412 px screen, where a nine-item labelled rail could not fit.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Buttons = AB.Require("Components.Buttons")
local Cards = AB.Require("Components.Cards")

local Shell = {}

local state = {
	mounted = false,
	ctx = nil,
	nav = nil,
	metrics = nil,
	parts = {},
	railButtons = {},
	tabButtons = {},
	drawerOpen = false,
	drag = nil,
	connections = {},
}

local function pad(px)
	return UDim.new(0, px)
end

local function connect(signal, fn)
	local connection = signal:Connect(fn)
	state.connections[#state.connections + 1] = connection
	return connection
end

------------------------------------------------------------------- pieces ----

local function buildHeader(parent, scale)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = Theme.color("header")
	header.BackgroundTransparency = 0
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Layout.target(scale, 46))
	header.LayoutOrder = 1
	header.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = pad(Layout.gutter(scale))
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = header

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(Layout.target(scale, 8))
	inner.PaddingRight = pad(Layout.target(scale, 8))
	inner.Parent = header

	local hamburger = Buttons.create({
		-- ASCII only: executor fonts often lack the box-drawing glyphs.
		text = "MENU",
		role = "icon",
		scale = scale,
		width = 56,
		parent = header,
		order = 1,
		name = "Hamburger",
		onClick = function()
			Shell.toggleDrawer()
		end,
	})

	local brand = Instance.new("Frame")
	brand.Name = "Brand"
	brand.BackgroundTransparency = 1
	brand.Size = UDim2.new(1, -(Layout.target(scale, 200)), 1, 0)
	brand.LayoutOrder = 2
	brand.Parent = header

	local brandList = Instance.new("UIListLayout")
	brandList.Padding = pad(0)
	brandList.VerticalAlignment = Enum.VerticalAlignment.Center
	brandList.SortOrder = Enum.SortOrder.LayoutOrder
	brandList.Parent = brand

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBlack
	title.Text = Config.brand.name
	title.TextColor3 = Theme.color("accent")
	title.TextSize = Layout.target(scale, 15)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Size = UDim2.new(1, 0, 0, Layout.target(scale, 17))
	title.LayoutOrder = 1
	title.Parent = brand

	local tagline = Instance.new("TextLabel")
	tagline.Name = "Tagline"
	tagline.BackgroundTransparency = 1
	tagline.Font = Enum.Font.Gotham
	tagline.Text = Config.brand.tagline
	tagline.TextColor3 = Theme.color("textDim")
	tagline.TextSize = Layout.target(scale, 9)
	tagline.TextXAlignment = Enum.TextXAlignment.Left
	tagline.TextTruncate = Enum.TextTruncate.AtEnd
	tagline.Size = UDim2.new(1, 0, 0, Layout.target(scale, 11))
	tagline.LayoutOrder = 2
	tagline.Parent = brand

	local themeButton = Buttons.create({
		text = "THEME",
		role = "icon",
		scale = scale,
		width = 56,
		parent = header,
		order = 3,
		name = "ThemeButton",
		onClick = function()
			local ok, err = Theme.toggle()
			if not ok then
				AB.Notify({ title = "Theme", body = tostring(err), kind = "danger" })
				return
			end
			AB.Require("Core.UIManager").applyTheme()
		end,
	})

	local close = Buttons.create({
		text = "X",
		role = "icon",
		scale = scale,
		width = 44,
		parent = header,
		order = 4,
		name = "Close",
		onClick = function()
			AB.stop()
		end,
	})

	header.BackgroundColor3 = Theme.color("header")
	state.parts.header = header
	state.parts.themeButton = themeButton
	state.parts.close = close
	state.parts.hamburger = hamburger
	state.parts.title = title

	AB.Require("Core.UIManager").themed(header, { BackgroundColor3 = "header" })
	AB.Require("Core.UIManager").themed(title, { TextColor3 = "accent" })
	AB.Require("Core.UIManager").themed(tagline, { TextColor3 = "textDim" })
	for _, button in ipairs({ hamburger, themeButton, close }) do
		AB.Require("Core.UIManager").registerButton(button)
	end

	return header
end

local function buildRail(parent, metrics)
	local rail = Instance.new("ScrollingFrame")
	rail.Name = "Rail"
	rail.BackgroundColor3 = Theme.color("rail")
	rail.BorderSizePixel = 0
	rail.ScrollBarThickness = 2
	rail.CanvasSize = UDim2.new(0, 0, 0, 0)
	rail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rail.Size = UDim2.new(0, metrics.railWidth, 1, -Layout.target(metrics.scale, 46))
	rail.ClipsDescendants = true
	rail.LayoutOrder = 2
	rail.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(math.max(2, metrics.gutter // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = rail

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(math.max(2, metrics.gutter // 2))
	inner.PaddingRight = pad(math.max(2, metrics.gutter // 2))
	inner.PaddingTop = pad(metrics.gutter)
	inner.Parent = rail

	AB.Require("Core.UIManager").themed(rail, { BackgroundColor3 = "rail" })
	state.parts.rail = rail
	return rail
end

local function buildDrawer(parent, metrics)
	local drawer = Instance.new("Frame")
	drawer.Name = "Drawer"
	drawer.BackgroundColor3 = Theme.color("bgElevated")
	drawer.BorderSizePixel = 0
	drawer.ClipsDescendants = true
	drawer.Visible = false
	drawer.ZIndex = 20
	drawer.Size = UDim2.new(0, math.min(math.floor(230 * metrics.scale), math.floor(metrics.windowWidth * 0.8)), 1, 0)
	drawer.Position = UDim2.new(0, -300, 0, 0)
	drawer.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(metrics.gutter)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	list.Parent = drawer

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(metrics.gutter)
	inner.PaddingRight = pad(metrics.gutter)
	inner.PaddingTop = pad(metrics.gutter)
	inner.Parent = drawer

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = drawer

	AB.Require("Core.UIManager").themed(drawer, { BackgroundColor3 = "bgElevated" })
	AB.Require("Core.UIManager").themed(stroke, { Color = "border" })
	state.parts.drawer = drawer
	return drawer
end

local function buildContent(parent, metrics)
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 3
	content.ScrollBarImageColor3 = Theme.color("border")
	content.CanvasSize = UDim2.new(0, 0, 0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.Size = UDim2.new(1, 0, 1, -Layout.target(metrics.scale, 46 + 18))
	content.LayoutOrder = 3
	content.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = pad(metrics.gutter)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = content

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(metrics.gutter)
	inner.PaddingRight = pad(metrics.gutter)
	inner.PaddingTop = pad(metrics.gutter)
	inner.PaddingBottom = pad(metrics.gutter)
	inner.Parent = content

	AB.Require("Core.UIManager").themed(content, { ScrollBarImageColor3 = "border" })
	state.parts.content = content
	return content
end

local function buildTabStrip(parent, metrics)
	local strip = Instance.new("ScrollingFrame")
	strip.Name = "TabStrip"
	strip.BackgroundColor3 = Theme.color("header")
	strip.BackgroundTransparency = 0
	strip.BorderSizePixel = 0
	strip.ScrollBarThickness = 2
	strip.ScrollBarImageColor3 = Theme.color("border")
	strip.ScrollingDirection = Enum.ScrollingDirection.X
	strip.CanvasSize = UDim2.new(0, 0, 0, 0)
	strip.ClipsDescendants = true
	strip.Visible = false
	strip.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 52))
	strip.Position = UDim2.new(0, 0, 0, 0)
	strip.Parent = parent

	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.Padding = pad(math.max(2, metrics.gutter // 2))
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = strip

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(metrics.gutter)
	inner.PaddingRight = pad(metrics.gutter)
	inner.Parent = strip

	AB.Require("Core.UIManager").themed(strip, { BackgroundColor3 = "header" })
	state.parts.tabStrip = strip
	return strip
end

local function buildStatusBar(parent, metrics)
	local bar = Instance.new("Frame")
	bar.Name = "StatusBar"
	bar.BackgroundColor3 = Theme.color("header")
	bar.BackgroundTransparency = 0.35
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 18))
	bar.LayoutOrder = 4
	bar.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Left"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = ""
	label.TextColor3 = Theme.color("textDim")
	label.TextSize = Layout.target(metrics.scale, 9)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -Layout.target(metrics.scale, 16), 1, 0)
	label.Position = UDim2.new(0, Layout.target(metrics.scale, 8), 0, 0)
	label.Parent = bar

	AB.Require("Core.UIManager").themed(bar, { BackgroundColor3 = "header" })
	AB.Require("Core.UIManager").themed(label, { TextColor3 = "textDim" })
	state.parts.statusBar = bar
	state.parts.statusLabel = label
	return bar
end

------------------------------------------------------------------- drawer ----

local function setDrawer(open)
	if not state.mounted then
		return
	end
	state.drawerOpen = open and true or false
	local drawer = state.parts.drawer
	local scrim = state.parts.scrim
	if not drawer then
		return
	end

	-- Compact has no rail and no drawer: the top strip is the navigation.
	if state.metrics and state.metrics.navMode == "tabs" then
		drawer.Visible = false
		if scrim then
			scrim.Visible = false
		end
		return
	end

	if state.metrics and state.metrics.sidebarMode == "docked" then
		drawer.Visible = true
		drawer.Position = UDim2.new(0, state.metrics.railWidth, 0, 0)
		if scrim then
			scrim.Visible = false
		end
		return
	end

	drawer.Visible = true
	local target = state.drawerOpen and UDim2.new(0, 0, 0, 0) or UDim2.new(0, -320, 0, 0)
	local animated = false
	if Config.ui.animations then
		animated = pcall(function()
			TweenService:Create(drawer, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = target }):Play()
		end)
	end
	if not animated then
		drawer.Position = target
	end
	if scrim then
		scrim.Visible = state.drawerOpen
	end
	if not state.drawerOpen then
		task.delay(0.2, function()
			if not state.drawerOpen and drawer.Parent then
				drawer.Visible = false
			end
		end)
	end
end

--------------------------------------------------------------------- drag ----

local function beginDrag(input, header)
	if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
		return
	end
	local root = state.ctx.root
	state.drag = {
		start = input.Position,
		origin = root.Position,
	}
end

local function moveDrag(input)
	local drag = state.drag
	if not drag then
		return
	end
	local root = state.ctx.root
	local delta = input.Position - drag.start
	root.Position = UDim2.new(drag.origin.X.Scale, drag.origin.X.Offset + delta.X, drag.origin.Y.Scale, drag.origin.Y.Offset + delta.Y)
end

local function endDrag()
	state.drag = nil
end

---------------------------------------------------------------------- api ----

function Shell.isMounted()
	return state.mounted
end

function Shell.toggleDrawer(open)
	setDrawer(open == nil and not state.drawerOpen or open)
end

function Shell.select(id)
	if not state.nav then
		return false
	end
	local ok = state.nav.select(id)
	if ok then
		for tabId, button in pairs(state.railButtons) do
			button.BackgroundColor3 = Theme.color(tabId == id and "railActive" or "rail")
			button.BackgroundTransparency = tabId == id and 0 or 1
		end
		for tabId, button in pairs(state.tabButtons) do
			button.BackgroundColor3 = Theme.color(tabId == id and "accent" or "bgElevated")
			button.BackgroundTransparency = tabId == id and 0 or 1
		end
		if state.metrics and state.metrics.sidebarMode ~= "docked" then
			setDrawer(false)
		end
	end
	return ok
end

--- Applies metrics to the chrome. Called on mount and on every reflow.
function Shell.reflow(metrics)
	if not state.mounted then
		return
	end
	state.metrics = metrics

	local header = state.parts.header
	local rail = state.parts.rail
	local strip = state.parts.tabStrip
	local content = state.parts.content
	local drawer = state.parts.drawer
	local bar = state.parts.statusBar

	if header then
		header.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 46))
	end
	local tabs = metrics.navMode == "tabs"
	local stripH = if_else(tabs, Layout.target(metrics.scale, 52), 0)

	-- MENU only drives the drawer, which does not exist at compact.
	if state.parts.hamburger then
		state.parts.hamburger.Visible = not tabs
	end

	if strip then
		strip.Visible = tabs and #state.nav.tabs > 0
		strip.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 52))
		strip.Position = UDim2.new(0, 0, 0, 0)
		-- Wide enough canvas that the last tabs sit off the edge: the strip
		-- scrolls rather than shrinking its targets.
		strip.CanvasSize = UDim2.new(0, #state.nav.tabs * (Layout.target(metrics.scale, 74) + metrics.gutter) + metrics.gutter, 0, 0)
	end
	if rail then
		rail.Size = UDim2.new(0, metrics.railWidth, 1, -(Layout.target(metrics.scale, 46) + Layout.target(metrics.scale, 18)))
		rail.Visible = (not tabs) and #state.nav.tabs > 0
	end
	if content then
		-- Compact: no rail beside it, so the full body width and no offset.
		local offset = if_else(tabs, 0, (metrics.wide and (metrics.railWidth + metrics.gutter)) or 0)
		content.Size = UDim2.new(1, -offset, 1, -(Layout.target(metrics.scale, 46 + 18) + stripH))
		content.Position = UDim2.new(0, offset, 0, stripH)
		content.ClipsDescendants = true
	end
	for tabId, button in pairs(state.tabButtons) do
		local tabRecord = state.nav.byId[tabId]
		button.Text = tabRecord and tabRecord.title or tabId
		button.TextSize = Layout.target(metrics.scale, 11)
		button.Size = UDim2.new(0, Layout.target(metrics.scale, 74), 0, Layout.target(metrics.scale))
	end

	-- Labels disappear on compact instead of shrinking into ellipses.
	for tabId, button in pairs(state.railButtons) do
		local record = state.nav.byId[tabId]
		local navLabel = record and record.glyph or ""
		if record and metrics.railMode == "full" then
			navLabel = record.glyph .. "  " .. record.title
		end
		button.Text = navLabel
		button.TextSize = Layout.target(metrics.scale, 11)
		button.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale))
	end

	if drawer then
		drawer.Size = UDim2.new(0, math.min(math.floor(230 * metrics.scale), math.floor(metrics.windowWidth * 0.8)), 1, 0)
	end
	if bar then
		bar.Size = UDim2.new(1, 0, 0, Layout.target(metrics.scale, 18))
		bar.Visible = Config.ui.showStatusBar
	end
	if state.parts.statusLabel then
		local label = state.parts.statusLabel
		label.Text = ("%s · scale %.2f · %s · %d tabs"):format(
			Config.brand.version,
			metrics.scale,
			Theme.current(),
			#state.nav.tabs
		)
		label.TextSize = Layout.target(metrics.scale, 9)
	end

	setDrawer(state.drawerOpen)
end

function Shell.mount(ctx, metrics)
	if state.mounted then
		return Shell
	end

	local UIManager = AB.Require("Core.UIManager")
	local root = ctx.root
	local scale = metrics.scale

	local column = Instance.new("Frame")
	column.Name = "Column"
	column.BackgroundTransparency = 1
	column.Size = UDim2.new(1, 0, 1, 0)
	column.Parent = root

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = column
	state.parts.column = column

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, 0, 1, 0)
	body.LayoutOrder = 2
	body.Parent = column
	state.parts.body = body

	buildHeader(column, scale)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 1, -(Layout.target(scale, 46) + Layout.target(scale, 18)))
	row.Parent = body
	state.parts.row = row

	local rail = buildRail(row, metrics)
	local content = buildContent(row, metrics)
	local strip = buildTabStrip(row, metrics)

	-- Scrim sits above content, below the drawer, so a tap outside closes it.
	local scrim = Instance.new("TextButton")
	scrim.Name = "Scrim"
	scrim.BackgroundColor3 = Theme.color("scrim")
	scrim.BackgroundTransparency = 0.5
	scrim.BorderSizePixel = 0
	scrim.Text = ""
	scrim.Visible = false
	scrim.ZIndex = 15
	scrim.Size = UDim2.new(1, 0, 1, 0)
	scrim.Parent = row
	scrim.Activated:Connect(function()
		setDrawer(false)
	end)
	UIManager.themed(scrim, { BackgroundColor3 = "scrim" })
	state.parts.scrim = scrim

	local drawer = buildDrawer(row, metrics)
	buildStatusBar(column, metrics)

	ctx.host = content
	ctx.metrics = metrics
	state.ctx = ctx
	state.metrics = metrics
	state.mounted = true
	state.nav = AB.Require("Core.Navigation").new(ctx)

	-- Header drag: mouse and touch both feed the same handler.
	local header = state.parts.header
	connect(header.InputBegan, function(input)
		beginDrag(input, header)
	end)
	connect(header.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endDrag()
		end
	end)
	local userInput = game:GetService("UserInputService")
	connect(userInput.InputChanged, function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			moveDrag(input)
		end
	end)
	connect(userInput.InputEnded, function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			endDrag()
		end
	end)

	-- Rail buttons and drawer rows both come from the same registry.
	function state.nav.rebuildNavSurfaces()
		local railList = rail
		local drawerList = drawer

		for _, record in ipairs(state.nav.tabs) do
			if not state.railButtons[record.id] then
				local railButton = Buttons.create({
					text = metrics.railMode == "full" and (record.glyph .. "  " .. record.title) or record.glyph,
					role = "nav",
					scale = scale,
					parent = railList,
					order = record.order,
					name = "Nav_" .. record.id,
					fill = true,
					onClick = function()
						Shell.select(record.id)
						if state.metrics and not state.metrics.wide then
							setDrawer(false)
						end
					end,
				})
				UIManager.registerButton(railButton)
				state.railButtons[record.id] = railButton
			end

			local rowButton = Buttons.create({
				text = record.glyph .. "  " .. record.title,
				role = "ghost",
				scale = scale,
				parent = drawerList,
				order = record.order,
				name = "Drawer_" .. record.id,
				fill = true,
				onClick = function()
					Shell.select(record.id)
				end,
			})
			UIManager.registerButton(rowButton)

			local tabButton = Buttons.create({
				text = record.title,
				role = "icon",
				scale = scale,
				width = 74,
				parent = strip,
				order = record.order,
				name = "Tab_" .. record.id,
				onClick = function()
					Shell.select(record.id)
				end,
			})
			UIManager.registerButton(tabButton)
			state.tabButtons[record.id] = tabButton
		end
	end

	return Shell
end

function Shell.register(descriptor)
	if not state.mounted then
		return nil, "shell not mounted"
	end
	local record, err = state.nav.register(descriptor)
	if not record then
		return nil, err
	end
	return record
end

function Shell.finish()
	if not state.mounted then
		return
	end
	state.nav.rebuildNavSurfaces()
	Shell.reflow(state.metrics)
	if #state.nav.tabs > 0 then
		Shell.select(state.nav.tabs[1].id)
	end
end

function Shell.destroy()
	if not state.mounted then
		return
	end
	state.mounted = false

	for _, connection in ipairs(state.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	state.connections = {}

	if state.nav then
		state.nav.destroy()
		state.nav = nil
	end

	if state.parts.column then
		state.parts.column:Destroy()
	end

	state.parts = {}
	state.railButtons = {}
	state.tabButtons = {}
	state.ctx = nil
	state.metrics = nil
	state.drawerOpen = false
	state.drag = nil
end

return Shell
