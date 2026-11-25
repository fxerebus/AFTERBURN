--[[
	Components/Stats.lua — a headline value with its provenance chip.

	The component takes the *pair* from Core/DataManager ({ value, provenance }),
	not a bare value. That is what makes a badge structurally hard to forget: a
	caller that passes a plain string gets a placeholder, and the suite counts
	unbadged values it finds.

	A missing value is not an error. The tile shows a dash, marks itself
	Placeholder, and the page keeps rendering.
]]

local AB = AB or _G.AFTERBURN

local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Badges = AB.Require("Components.Badges")

local Stats = {}

local PLACEHOLDER = "\u{2014}" -- em dash

--- A tile: label above, large value below, chip in the corner.
function Stats.tile(parent, opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local padPx = Layout.target(scale, 9)

	local badged = type(o.value) == "table" and o.value or nil
	local text = badged and tostring(badged.value or PLACEHOLDER) or PLACEHOLDER
	local isPlaceholder = badged == nil or badged.value == nil

	local tile = Instance.new("Frame")
	tile.Name = "Stat"
	tile.BackgroundColor3 = Theme.color("surfaceAlt")
	tile.BackgroundTransparency = 0
	tile.BorderSizePixel = 0
	tile.Size = UDim2.new(1, 0, 0, 0)
	tile.AutomaticSize = Enum.AutomaticSize.Y
	tile.LayoutOrder = o.order or 1
	tile:SetAttribute("Placeholder", isPlaceholder)
	-- Renaming a tile must not hide it from anything that walks tiles.
	tile:SetAttribute("Tile", true)

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = tile

	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.color("border")
	stroke.Thickness = 1
	stroke.Parent = tile

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, padPx)
	padding.PaddingRight = UDim.new(0, padPx)
	padding.PaddingTop = UDim.new(0, padPx)
	padding.PaddingBottom = UDim.new(0, padPx)
	padding.Parent = tile

	local list = Instance.new("UIListLayout")
	list.Padding = UDim.new(0, math.max(2, Layout.gutter(scale) // 2))
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = tile

	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 0)
	head.AutomaticSize = Enum.AutomaticSize.Y
	head.LayoutOrder = 1
	head.Parent = tile

	local row = Instance.new("UIListLayout")
	row.FillDirection = Enum.FillDirection.Horizontal
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	row.Padding = UDim.new(0, 4)
	row.SortOrder = Enum.SortOrder.LayoutOrder
	row.Parent = head

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = tostring(o.label or "—")
	label.TextColor3 = Theme.color("textDim")
	label.TextSize = Layout.target(scale, 10)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Size = UDim2.new(1, -56, 0, 0)
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = 1
	label.Parent = head

	-- Chip is emitted only when the value actually carries a provenance, in the
	-- same head as the value, so an orphaned badge cannot be written.
	local prov = badged and badged.provenance or o.provenance
	if prov and badged and badged.value ~= nil then
		Badges.chip(head, { kind = prov, scale = scale, order = 2 })
	end

	local value = Instance.new("TextLabel")
	value.Name = "Value"
	value.BackgroundTransparency = 1
	value.Font = Enum.Font.GothamBold
	value.Text = text
	value.TextColor3 = Theme.color(isPlaceholder and "textDim" or "text")
	value.TextSize = Layout.target(scale, 20)
	value.TextXAlignment = Enum.TextXAlignment.Left
	value.TextWrapped = true
	value.Size = UDim2.new(1, 0, 0, 0)
	value.AutomaticSize = Enum.AutomaticSize.Y
	value.LayoutOrder = 2
	value:SetAttribute("Value", true)
	value:SetAttribute("Badged", badged ~= nil and badged.value ~= nil)
	value:SetAttribute("Placeholder", isPlaceholder)
	value.Parent = tile

	-- Same bug class as Badges.chip: the positional parent must win, otherwise a
	-- tile built with only the positional argument is created detached.
	local target = o.parent or parent
	if target then
		tile.Parent = target
	end

	return tile, value
end

--- Updates an existing tile in place, so a ticking value does not rebuild DOM.
function Stats.update(tile, badged)
	if tile == nil or tile.Parent == nil and tile.Name ~= "Stat" then
		return false
	end
	local value = tile:FindFirstChild("Value")
	if value == nil then
		return false
	end
	local has = type(badged) == "table" and badged.value ~= nil
	value.Text = has and tostring(badged.value) or PLACEHOLDER
	value.TextColor3 = Theme.color(has and "text" or "textDim")
	value:SetAttribute("Badged", has)
	value:SetAttribute("Placeholder", not has)
	tile:SetAttribute("Placeholder", not has)
	return true
end

return Stats
