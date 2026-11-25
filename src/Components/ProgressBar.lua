--[[
	Components/ProgressBar.lua — determinate bar with a percentage label.

	Used by the Dashboard's feature overview. The fraction is clamped, so a
	provider handing back 1.4 or -0.2 cannot overdraw the track. A missing
	fraction draws an empty track and marks the row Placeholder instead of
	erroring — same degradation rule as the stat tile.
]]

local AB = AB or _G.AFTERBURN

local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Badges = AB.Require("Components.Badges")

local ProgressBar = {}

local function clamp01(value)
	local n = tonumber(value)
	if n == nil then
		return nil
	end
	if n < 0 then
		return 0
	elseif n > 1 then
		return 1
	end
	return n
end

--- A bar row: label and percent above, track below.
function ProgressBar.bar(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local fraction = clamp01(o.progress)
	local height = math.max(4, math.ceil(Layout.target(scale, 6) * scale))

	local wrap = Instance.new("Frame")
	wrap.Name = "Progress"
	wrap.BackgroundTransparency = 1
	wrap.Size = UDim2.new(1, 0, 0, 0)
	wrap.AutomaticSize = Enum.AutomaticSize.Y
	wrap.LayoutOrder = o.order or 1
	wrap:SetAttribute("Placeholder", fraction == nil)
	wrap:SetAttribute("Fraction", fraction or 0)

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, math.max(2, Layout.gutter(scale) // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = wrap

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = 1
	head.Parent = wrap

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.Text = tostring(o.label or "—")
	label.TextColor3 = Theme.color("text")
	label.TextSize = Layout.target(scale, 11)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -70, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = 1
	label.Parent = head

	local percent = Instance.new("TextLabel")
	percent.Name = "Percent"
	percent.BackgroundTransparency = 1
	percent.Font = Enum.Font.GothamBold
	percent.Text = fraction and ("%d%%"):format(math.floor(fraction * 100 + 0.5)) or "—"
	percent.TextColor3 = Theme.color(fraction and "text" or "textDim")
	percent.TextSize = Layout.target(scale, 10)
	percent.TextXAlignment = Enum.TextXAlignment.Right
	percent.Size = UDim2.fromOffset(math.ceil(Layout.target(scale, 34) * scale), math.ceil(Layout.target(scale, 14) * scale))
	percent.LayoutOrder = 2
	percent.Parent = head

	Badges.forValue(head, o.badge, scale, 3)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Theme.color("track")
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Size = UDim2.new(1, 0, 0, height)
	track.LayoutOrder = 2
	track.Parent = wrap

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.color("accent")
	fill.BorderSizePixel = 0
	fill.Size = UDim2.new(fraction or 0, 0, 1, 0)
	fill.Parent = track

	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill

	if o.parent then
		wrap.Parent = o.parent
	end

	return wrap
end

--- Sets a new fraction without rebuilding the row.
function ProgressBar.set(wrap, progress)
	if wrap == nil then
		return false
	end
	local track = wrap:FindFirstChild("Track")
	local percent = wrap:FindFirstChild("Head") and wrap:FindFirstChild("Head"):FindFirstChild("Percent")
	if track == nil or percent == nil then
		return false
	end
	local fill = track:FindFirstChild("Fill")
	local fraction = clamp01(progress)
	if fill then
		fill.Size = UDim2.new(fraction or 0, 0, 1, 0)
	end
	percent.Text = fraction and ("%d%%"):format(math.floor(fraction * 100 + 0.5)) or "—"
	percent.TextColor3 = Theme.color(fraction and "text" or "textDim")
	wrap:SetAttribute("Placeholder", fraction == nil)
	wrap:SetAttribute("Fraction", fraction or 0)
	return true
end

return ProgressBar
