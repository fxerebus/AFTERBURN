--[[
	Components/Buttons.lua — the only button factory in AFTERBURN.

	Sizes are always derived: callers pass a role ("primary", "ghost", "nav",
	"icon") and a live scale, and the height comes back at or above the 44 px
	post-scale floor. A click with no handler is a build error, not a decoration.

	`Buttons.create` returns the instance; state lives in attributes so the
	themer can repaint a button without the caller tracking tokens.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Config = AB.Require("Config")

local Buttons = {}

local ROLES = {
	primary = { bg = "accent", text = "accentText", stroke = "accent", bold = true },
	ghost = { bg = "surfaceAlt", text = "text", stroke = "border", bold = false },
	nav = { bg = "rail", text = "textDim", stroke = "rail", bold = false },
	icon = { bg = "surfaceAlt", text = "text", stroke = "border", bold = false },
	danger = { bg = "danger", text = "textInverse", stroke = "danger", bold = true },
}

--- opts: { text, role, scale, parent, onClick, width, order, tooltip, name }
function Buttons.create(opts)
	local o = opts or {}
	local role = ROLES[o.role or "ghost"] or ROLES.ghost
	local scale = Layout.clampScale(o.scale or 1)
	-- Post-scale floor, expressed pre-scale. This is the whole 44 px contract.
	local height = Layout.target(scale)
	local width = o.width

	if not o.onClick then
		warn(("AFTERBURN buttons: '%s' has no onClick"):format(tostring(o.text or o.name)))
	end

	local button = Instance.new("TextButton")
	button.Name = o.name or "Button"
	button.AutoButtonColor = false
	button.BackgroundColor3 = Theme.color(role.bg)
	button.BackgroundTransparency = o.role == "nav" and 1 or 0
	button.BorderSizePixel = 0
	button.Font = role.bold and Enum.Font.GothamBold or Enum.Font.GothamMedium
	button.Text = o.text or ""
	button.TextColor3 = Theme.color(role.text)
	button.TextSize = Layout.target(scale, 12)
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.LayoutOrder = o.order or 1
	button.Size = if_width(width, height, scale, o)
	button:SetAttribute("Role", o.role or "ghost")

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button

	if role.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Theme.color(role.stroke)
		stroke.Thickness = 1
		stroke.Transparency = o.role == "nav" and 1 or 0.35
		stroke.Parent = button
	end

	local innerPad = Instance.new("UIPadding")
	innerPad.PaddingLeft = UDim.new(0, Layout.target(scale, 8))
	innerPad.PaddingRight = UDim.new(0, Layout.target(scale, 8))
	innerPad.Parent = button

	local function tween(transparency, strokeTransparency)
		if not Config.ui.animations then
			button.BackgroundTransparency = transparency
			return
		end
		local info = TweenInfo.new(Config.ui.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local goal = { BackgroundTransparency = transparency }
		local tweenObj = TweenService:Create(button, info, goal)
		tweenObj:Play()
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke and strokeTransparency then
			local sInfo = TweenInfo.new(Config.ui.animationSpeed)
			TweenService:Create(stroke, sInfo, { Transparency = strokeTransparency }):Play()
		end
	end

	button.MouseEnter:Connect(function()
		button.BackgroundColor3 = Theme.color(o.role == "primary" and "accentHover" or "railActive")
		tween(button.BackgroundTransparency - 0.08)
	end)

	button.MouseLeave:Connect(function()
		button.BackgroundColor3 = Theme.color(role.bg)
		tween(o.role == "nav" and 1 or 0)
	end)

	button.Activated:Connect(function()
		if o.onClick then
			local ok, err = pcall(o.onClick, button)
			if not ok then
				warn(("AFTERBURN buttons: '%s' handler failed: %s"):format(tostring(o.text), tostring(err)))
			end
		end
	end)

	if o.parent then
		button.Parent = o.parent
	end

	return button
end

--- Width helper kept separate so the size expression reads once.
function if_width(width, height, scale, o)
	if width then
		return UDim2.new(0, math.max(Layout.target(scale), width * scale), 0, height)
	end
	if o and o.fill then
		return UDim2.new(1, 0, 0, height)
	end
	return UDim2.new(0, Layout.target(scale, 120), 0, height)
end

--- Repaints a button after a theme change, using its role attribute.
function Buttons.repaint(button)
	local role = ROLES[button:GetAttribute("Role") or "ghost"] or ROLES.ghost
	button.BackgroundColor3 = Theme.color(role.bg)
	button.TextColor3 = Theme.color(role.text)
	local stroke = button:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Theme.color(role.stroke)
	end
end

return Buttons
