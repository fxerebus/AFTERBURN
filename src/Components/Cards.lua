--[[
	Components/Cards.lua — panel and card surfaces.

	A card is a header strip plus a body frame. Callers get the body and the
	header, never a bare Frame, so padding and token wiring stay consistent.

	All geometry comes from Layout, so a card that fits at scale 1 still fits at
	0.7 — the paddings grow while the viewport shrinks, and the card reflows its
	header to a stacked block when `compact` is set.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local Cards = {}

local function pad(size)
	return UDim.new(0, size)
end

--- Creates a card. opts: { title, subtitle, compact, scale, parent, tone }
-- tone: "surface" (default) | "accent" | "warning"
function Cards.create(opts)
	local o = opts or {}
	local scale = o.scale or 1
	local gap = Layout.gutter(scale)
	local padPx = Layout.target(scale, 10)

	local card = Instance.new("Frame")
	card.Name = o.name or "Card"
	card.BackgroundColor3 = Theme.color(o.tone == "accent" and "accent" or o.tone == "warning" and "warning" or "surface")
	card.BackgroundTransparency = o.tone and 0.86 or 0
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.Size = UDim2.new(1, 0, 0, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.LayoutOrder = o.order or 1

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = card

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color(o.tone and "accent" or "border")
	stroke.Thickness = 1
	stroke.Transparency = o.tone and 0.5 or 0
	stroke.Parent = card

	local list = Instance.new("UIListLayout")
	list.Padding = pad(gap)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = card

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.Size = UDim2.new(1, -padPx * 2, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.LayoutOrder = 10
	body.Parent = card

	local inner = Instance.new("UIPadding")
	inner.PaddingLeft = pad(padPx)
	inner.PaddingRight = pad(padPx)
	inner.PaddingBottom = pad(padPx)
	inner.PaddingTop = pad(padPx)
	inner.Parent = body

	if o.title or o.subtitle then
		local header = Instance.new("Frame")
		header.Name = "Header"
		header.BackgroundTransparency = 1
		header.Size = UDim2.new(1, 0, 0, 0)
		header.AutomaticSize = Enum.AutomaticSize.Y
		header.LayoutOrder = 1
		header.Parent = card

		local headerPad = Instance.new("UIPadding")
		headerPad.PaddingLeft = pad(padPx)
		headerPad.PaddingRight = pad(padPx)
		headerPad.PaddingTop = pad(padPx)
		headerPad.Parent = header

		local headerList = Instance.new("UIListLayout")
		headerList.Padding = pad(math.max(2, gap // 2))
		headerList.SortOrder = Enum.SortOrder.LayoutOrder
		headerList.Parent = header

		if o.title then
			local title = Instance.new("TextLabel")
			title.Name = "Title"
			title.BackgroundTransparency = 1
			title.Font = Enum.Font.GothamBold
			title.Text = o.title
			title.TextColor3 = Theme.color("text")
			title.TextSize = Layout.target(scale, 14)
			title.TextXAlignment = Enum.TextXAlignment.Left
			title.TextWrapped = true
			title.Size = UDim2.new(1, 0, 0, 0)
			title.AutomaticSize = Enum.AutomaticSize.Y
			title.LayoutOrder = 1
			title.Parent = header
		end

		if o.subtitle then
			local sub = Instance.new("TextLabel")
			sub.Name = "Subtitle"
			sub.BackgroundTransparency = 1
			sub.Font = Enum.Font.Gotham
			sub.Text = o.subtitle
			sub.TextColor3 = Theme.color("textDim")
			sub.TextSize = Layout.target(scale, 11)
			sub.TextXAlignment = Enum.TextXAlignment.Left
			sub.TextWrapped = true
			sub.Size = UDim2.new(1, 0, 0, 0)
			sub.AutomaticSize = Enum.AutomaticSize.Y
			sub.LayoutOrder = 2
			sub.Parent = header
		end

		card:SetAttribute("HasHeader", true)
	end

	if o.parent then
		card.Parent = o.parent
	end

	return card, body
end

--- Compact single-line row: label left, optional trailing text right.
function Cards.row(parent, label, trailing, scale, order)
	local s = scale or 1
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, Layout.target(s))
	row.LayoutOrder = order or 1
	row.Parent = parent

	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.Gotham
	name.Text = label
	name.TextColor3 = Theme.color("textDim")
	name.TextSize = Layout.target(s, 11)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.Size = UDim2.new(1, trailing and -Layout.target(s, 96) or 0, 1, 0)
	name.Parent = row

	if trailing then
		local tail = Instance.new("TextLabel")
		tail.BackgroundTransparency = 1
		tail.Font = Enum.Font.GothamMedium
		tail.Text = trailing
		tail.TextColor3 = Theme.color("text")
		tail.TextSize = Layout.target(s, 11)
		tail.TextXAlignment = Enum.TextXAlignment.Right
		tail.Size = UDim2.new(0, Layout.target(s, 92), 1, 0)
		tail.Position = UDim2.new(1, -Layout.target(s, 92), 0, 0)
		tail.Parent = row
	end

	return row
end

return Cards
