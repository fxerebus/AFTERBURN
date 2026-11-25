--[[
	Pages/Dashboard.lua — the real Stage 2 page.

	Every value here arrives from Core/DataManager as { value, provenance } and
	is rendered with a SIMULATED chip beside it. Nothing on this page claims to
	be live: Config.live.enabled is false, no provider can read a real path yet,
	and the one line that says so is generated from that flag, not hardcoded.

	Quick-access controls carry their effect as data (`effect = {...}`) and are
	resolved by Dashboard.resolve, so a control whose target stopped existing
	fails a check instead of sitting there looking clickable.
]]

local AB = AB or _G.AFTERBURN

local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Session = AB.Require("Core.Session")
local DataManager = AB.Require("Core.DataManager")
local Cards = AB.Require("Components.Cards")
local Buttons = AB.Require("Components.Buttons")
local Badges = AB.Require("Components.Badges")
local Stats = AB.Require("Components.Stats")
local ProgressBar = AB.Require("Components.ProgressBar")

local Dashboard = {}

-- root -> stop(), so unmount can halt the tick chain without a returned handle.
local SESSIONS = setmetatable({}, { __mode = "k" })

Dashboard.id = "dashboard"
Dashboard.title = "Dashboard"
Dashboard.glyph = "◎"
Dashboard.order = 1
Dashboard.blurb = "Branding, session and status"

--- Controls and what each one actually does. Resolved by resolve() and by the suite.
Dashboard.effects = {
	{ id = "qa-farming", text = "Farming", effect = { kind = "navigate", page = "farming" } },
	{ id = "qa-mastery", text = "Mastery", effect = { kind = "navigate", page = "mastery" } },
	{ id = "qa-servers", text = "Servers", effect = { kind = "navigate", page = "servers" } },
	{ id = "qa-settings", text = "Settings", effect = { kind = "navigate", page = "settings" } },
	{ id = "qa-animations", text = "Toggle motion", effect = { kind = "setting", path = "ui.animations", flip = true } },
}

--- Applies an effect. Returns true when the target was real and the call landed.
function Dashboard.resolve(effect, ctx)
	if type(effect) ~= "table" then
		return false, "effect missing"
	end
	if effect.kind == "navigate" then
		local nav = ctx and ctx.nav
		if not nav or nav.byId[effect.page] == nil then
			return false, "no route " .. tostring(effect.page)
		end
		local selected, reason = nav.select(effect.page)
		return selected == true, reason
	elseif effect.kind == "setting" then
		local head, leaf = tostring(effect.path):match("^(%w+)%.(%w+)$")
		if not head or not leaf or Config[head] == nil or Config[head][leaf] == nil then
			return false, "no setting " .. tostring(effect.path)
		end
		if effect.flip then
			Config[head][leaf] = not Config[head][leaf]
		end
		return true
	end
	return false, "unknown effect " .. tostring(effect.kind)
end

-------------------------------------------------------------- fragments ----

-- A labelled value that always ships with its chip.
local function valueRow(body, label, badged, scale, order)
	local holder = Instance.new("Frame")
	holder.Name = label
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.LayoutOrder = order
	holder.Parent = body

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = holder

	local text = Instance.new("TextLabel")
	text.Name = "Label"
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.Gotham
	text.Text = label
	text.TextColor3 = Theme.color("textDim")
	text.TextSize = Layout.target(scale, 10)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.Size = UDim2.new(1, -60, 0, 0)
	text.AutomaticSize = Enum.AutomaticSize.Y
	text.LayoutOrder = 1
	text.Parent = holder

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.Text = badged and tostring(badged.value or "—") or "—"
	value.TextColor3 = Theme.color(badged and badged.value and "text" or "textDim")
	value.TextSize = Layout.target(scale, 12)
	value.TextXAlignment = Enum.TextXAlignment.Right
	value.Size = UDim2.new(1, -60, 0, 0)
	value.AutomaticSize = Enum.AutomaticSize.Y
	value.LayoutOrder = 2
	value:SetAttribute("Value", true)
	value:SetAttribute("Badged", badged ~= nil and badged.value ~= nil)
	value:SetAttribute("Placeholder", badged == nil or badged.value == nil)
	value.Parent = holder

	-- Same rule as Stats.tile: no provenance, no chip, so a badge can never be
	-- written without the value it belongs to.
	if badged and badged.value ~= nil and badged.provenance then
		Badges.chip(holder, { kind = badged.provenance, scale = scale, order = 3 })
	end
	return holder
end

local function section(host, title, subtitle, scale, order)
	local card, body = Cards.create({
		title = title,
		subtitle = subtitle,
		scale = scale,
		parent = host,
		name = title,
		order = order,
	})
	return card, body
end

------------------------------------------------------------------ mount ----

function Dashboard.mount(host, ctx)
	local scale = Layout.clampScale(ctx.scale())
	local session = Session.new()
	local provider = ctx.provider or DataManager.new({ session = session })
	local provenance = provider._provenance

	-- Tick chain: a delay re-arms itself, so nothing busy-waits under Studio.
	local alive = true
	local elapsed = 0
	local timerLabel

	local root = Instance.new("Frame")
	root.Name = "DashboardPage"
	root.BackgroundTransparency = 1
	root.Size = UDim2.new(1, 0, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = host

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, Layout.gutter(scale))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = root

	local brand, brandBody = section(root, Config.brand.name, Config.brand.tagline, scale, 1)
	brandBody:SetAttribute("Brand", true)
	valueRow(brandBody, "Product", DataManager.badged(Config.brand.product, provenance), scale, 1)
	valueRow(brandBody, "Version", DataManager.badged(Config.brand.version, provenance), scale, 2)

	local welcome, welcomeBody = section(root, "Welcome", nil, scale, 2)
	welcomeBody:SetAttribute("Welcome", true)
	valueRow(welcomeBody, "Greeting", provider:welcome(), scale, 1)

	local identity, identityBody = section(root, "Operator", nil, scale, 3)
	identityBody:SetAttribute("Operator", true)
	local who = provider:identity()
	Stats.tile(identityBody, {
		label = "Name",
		value = who and who.value and DataManager.badged(who.value.name, provenance) or nil,
		provenance = provenance,
		scale = scale,
		order = 1,
	})
	Stats.tile(identityBody, {
		label = "Role",
		value = who and who.value and DataManager.badged(who.value.role, provenance) or nil,
		provenance = provenance,
		scale = scale,
		order = 2,
	})

	-- Session duration: the one row that moves on its own.
	local clock, clockBody = section(root, "Session", "Running since mount", scale, 4)
	clockBody:SetAttribute("Session", true)
	-- Uptime is measured rather than simulated, so its badge is built from a real
	-- badged pair instead of a hardcoded literal, and the tile applies the same
	-- chip rule as every other value.
	do
		local tile, value = Stats.tile(clockBody, {
			label = "Uptime",
			value = DataManager.badged(Session.format(0), provenance),
			provenance = provenance,
			scale = scale,
			order = 1,
		})
		tile.Name = "Uptime"
		timerLabel = value
	end

	local function tick()
		if not alive then
			return
		end
		elapsed = elapsed + 1
		if timerLabel and timerLabel.Parent then
			timerLabel.Text = Session.format(elapsed)
		end
		task.delay(1, tick)
	end
	task.delay(1, tick)

	local overview, overviewBody = section(root, "Feature overview", "Simulated progress", scale, 5)
	overviewBody:SetAttribute("Overview", true)
	for index, row in ipairs(provider:overview()) do
		ProgressBar.bar(overviewBody, {
			label = row.label,
			progress = row.progress,
			badge = DataManager.badged(row.progress, provenance),
			scale = scale,
			order = index,
		})
	end

	local activity, activityBody = section(root, "Activity", nil, scale, 6)
	local state = provider:activity()
	activityBody:SetAttribute("Activity", true)
	if state then
		local tile, value = Stats.tile(activityBody, {
			label = "Routine",
			value = state.value and DataManager.badged(state.value.text, provenance) or nil,
			provenance = provenance,
			scale = scale,
			order = 1,
		})
		tile.Name = "State"
		Badges.dot(tile, { state = state.value and state.value.state or "idle", scale = scale, order = 0 })
		value.Font = Enum.Font.GothamMedium
		value.TextSize = Layout.target(scale, 11)
	end

	local quick, quickBody = section(root, "Quick access", "Every control has a target", scale, 7)
	quickBody:SetAttribute("QuickAccess", true)
	for index, control in ipairs(Dashboard.effects) do
		local button = Buttons.create({
			text = control.text,
			role = index == 1 and "primary" or "ghost",
			scale = scale,
			fill = true,
			order = index,
			name = control.id,
			parent = quickBody,
			onClick = function()
				Dashboard.resolve(control.effect, ctx)
			end,
		})
		button:SetAttribute("Effect", control.effect.kind)
		button:SetAttribute("Target", control.effect.page or control.effect.path)
	end

	local feed, feedBody = section(root, "Notifications", ("Live data: %s"):format(Config.live.enabled and "on" or "off"), scale, 8)
	feedBody:SetAttribute("Feed", true)
	for index, item in ipairs(provider:feed()) do
		local line = Instance.new("Frame")
		line.Name = item.id
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, 0)
		line.AutomaticSize = Enum.AutomaticSize.Y
		line.LayoutOrder = index
		line.Parent = feedBody

		local lineRow = Instance.new("UIListLayout")
		lineRow.FillDirection = Enum.FillDirection.Horizontal
		lineRow.VerticalAlignment = Enum.VerticalAlignment.Center
		lineRow.Padding = UDim.new(0, 6)
		lineRow.SortOrder = Enum.SortOrder.LayoutOrder
		lineRow.Parent = line

		Badges.dot(line, { state = item.kind == "warning" and "warn" or "idle", scale = scale, order = 1 })
		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.Gotham
		text.Text = item.text
		text.TextColor3 = Theme.color("textDim")
		text.TextSize = Layout.target(scale, 10)
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.TextWrapped = true
		text.Size = UDim2.new(1, -30, 0, 0)
		text.AutomaticSize = Enum.AutomaticSize.Y
		text.LayoutOrder = 2
		text.Parent = line
	end

	SESSIONS[root] = function()
		alive = false
		session:stop()
	end

	root:SetAttribute("Mounted", true)
	root:SetAttribute("Provenance", provenance)
	return root, {
		session = session,
		stop = function()
			alive = false
			session:stop()
		end,
	}
end

function Dashboard.unmount(root)
	local stop = root and SESSIONS[root]
	if stop then
		stop()
		SESSIONS[root] = nil
	end
	if root then
		root:Destroy()
	end
end

return Dashboard
