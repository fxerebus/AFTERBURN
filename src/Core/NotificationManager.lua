--[[
	Core/NotificationManager.lua — bounded toast queue.

	Three visible at a time (Config.ui.notifications.max), oldest evicted first,
	auto-dismiss on a timer. Severity changes the accent stripe and the border,
	never the layout, so a toast appearing does not shove the shell around.

	`push` returns the id so a caller can dismiss a toast early; ids are
	monotonic and never reused.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local NotificationManager = {}

local state = {
	host = nil,
	scale = 1,
	live = {},
	seq = 0,
	alive = false,
}

local function later(seconds, fn)
	if type(task) == "table" and task.delay then
		task.delay(seconds, fn)
	elseif type(delay) == "function" then
		delay(seconds, fn)
	else
		fn()
	end
end

--------------------------------------------------------------------- api ----

function NotificationManager.mount(parent, scale)
	state.host = Instance.new("Frame")
	state.host.Name = "Toasts"
	state.host.BackgroundTransparency = 1
	state.host.AnchorPoint = Vector2.new(1, 1)
	state.host.Position = UDim2.new(1, -8, 1, -8)
	state.host.Size = UDim2.new(0, 0, 0, 0)
	state.host.ZIndex = 40
	state.host.Parent = parent

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 6)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.VerticalAlignment = Enum.VerticalAlignment.Bottom
	list.HorizontalAlignment = Enum.HorizontalAlignment.Right
	list.Parent = state.host

	state.scale = scale or 1
	state.alive = true
	return state.host
end

function NotificationManager.dismiss(id)
	for index, record in ipairs(state.live) do
		if record.id == id then
			table.remove(state.live, index)
			if record.frame and record.frame.Parent then
				record.frame:Destroy()
			end
			return true
		end
	end
	return false
end

function NotificationManager.clear()
	for _, record in ipairs(state.live) do
		if record.frame and record.frame.Parent then
			record.frame:Destroy()
		end
	end
	state.live = {}
end

function NotificationManager.count()
	return #state.live
end

--- opts: { title, body, kind ("info"|"success"|"warning"|"danger"), lifetime }
function NotificationManager.push(opts)
	if not state.alive or not state.host then
		return nil
	end

	local o = type(opts) == "table" and opts or { title = tostring(opts) }
	local max = Config.ui.notifications.max

	while #state.live >= max do
		NotificationManager.dismiss(state.live[1].id)
	end

	state.seq = state.seq + 1
	local id = state.seq
	local kind = o.kind or "info"
	local stripeToken = kind == "danger" and "danger" or kind == "warning" and "warning" or kind == "success" and "success" or "accent"

	local frame = Instance.new("Frame")
	frame.Name = "Toast" .. id
	frame.BackgroundColor3 = Theme.color("toast")
	frame.BorderSizePixel = 0
	frame.Size = UDim2.new(0, Layout.target(state.scale, 210), 0, Layout.target(state.scale, 52))
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.LayoutOrder = id
	frame.Parent = state.host

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = frame

	local stripe = Instance.new("Frame")
	stripe.Name = "Stripe"
	stripe.BackgroundColor3 = Theme.color(stripeToken)
	stripe.BorderSizePixel = 0
	stripe.Size = UDim2.new(0, Layout.target(state.scale, 3), 1, 0)
	stripe.Parent = frame

	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, Layout.target(state.scale, 12))
	pad.PaddingRight = UDim.new(0, Layout.target(state.scale, 10))
	pad.PaddingTop = UDim.new(0, Layout.target(state.scale, 8))
	pad.PaddingBottom = UDim.new(0, Layout.target(state.scale, 8))
	pad.Parent = frame

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, 2)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = frame

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = o.title or "Notice"
	title.TextColor3 = Theme.color("text")
	title.TextSize = Layout.target(state.scale, 11)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.TextTruncate = Enum.TextTruncate.AtEnd
	title.Size = UDim2.new(1, 0, 0, Layout.target(state.scale, 14))
	title.LayoutOrder = 1
	title.Parent = frame

	if o.body then
		local body = Instance.new("TextLabel")
		body.BackgroundTransparency = 1
		body.Font = Enum.Font.Gotham
		body.Text = o.body
		body.TextColor3 = Theme.color("textDim")
		body.TextSize = Layout.target(state.scale, 10)
		body.TextXAlignment = Enum.TextXAlignment.Left
		body.TextYAlignment = Enum.TextYAlignment.Top
		body.TextWrapped = true
		body.Size = UDim2.new(1, 0, 0, 0)
		body.AutomaticSize = Enum.AutomaticSize.Y
		body.LayoutOrder = 2
		body.Parent = frame
	end

	table.insert(state.live, { id = id, frame = frame, kind = kind })

	later(o.lifetime or Config.ui.notifications.lifetime, function()
		NotificationManager.dismiss(id)
	end)

	return id
end

function NotificationManager.destroy()
	NotificationManager.clear()
	if state.host then
		state.host:Destroy()
	end
	state.host = nil
	state.alive = false
end

return NotificationManager
