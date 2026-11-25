--[[
	Components/Toggles.lua — animated switch.

	The track is the hit target and is never shorter than the post-scale floor,
	so a thumb on glass has something to land on. The knob tweens; flipping is
	idempotent and the change callback is pcall-guarded.

	Every toggle carries an `Id` attribute so a caller can find it again after a
	rebuild instead of holding a stale reference.
]]

local AB = AB or _G.AFTERBURN
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")
local Config = AB.Require("Config")

local Toggles = {}

-- TweenService is a global in Roblox but a service under test; resolve either
-- way once, and snap instead of tweening when neither is available.
local tweenService = TweenService
if not tweenService then
	local ok, service = pcall(function() return game:GetService("TweenService") end)
	if ok then
		tweenService = service
	end
end

--- opts: { label, value, scale, parent, id, onChange, order }
function Toggles.create(opts)
	local o = opts or {}
	local scale = Layout.clampScale(o.scale or 1)
	local height = Layout.target(scale)
	local knobSize = math.max(Layout.target(scale, 18), math.floor(height * 0.62))

	local row = Instance.new("Frame")
	row.Name = o.id or "Toggle"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = o.order or 1

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Gotham
	label.Text = o.label or ""
	label.TextColor3 = Theme.color("text")
	label.TextSize = Layout.target(scale, 12)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Size = UDim2.new(1, -Layout.target(scale, 64), 1, 0)
	label.Parent = row

	local trackWidth = math.max(Layout.target(scale, 44), knobSize * 2 + 4)

	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.AutoButtonColor = false
	track.BackgroundColor3 = Theme.color("track")
	track.BorderSizePixel = 0
	track.Text = ""
	track.AnchorPoint = Vector2.new(1, 0.5)
	track.Position = UDim2.new(1, 0, 0.5, 0)
	track.Size = UDim2.new(0, trackWidth, 0, height)
	track.Parent = row

	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track

	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = Theme.color("knob")
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Size = UDim2.new(0, knobSize, 0, knobSize)
	knob.Parent = track

	local knobCorner = Instance.new("UICorner")
	knobCorner.CornerRadius = UDim.new(1, 0)
	knobCorner.Parent = knob

	local state = { value = o.value and true or false, enabled = true, id = o.id }

	local function knobPosition(value)
		local inset = math.floor((track.AbsoluteSize.Y - knobSize) / 2)
		local inPx = Layout.target(scale, 3)
		if value then
			return UDim2.new(1, -(knobSize + inPx), 0.5, 0)
		end
		return UDim2.new(0, inPx, 0.5, 0)
	end

	local function paint(animate)
		local goal = knobPosition(state.value)
		track.BackgroundColor3 = Theme.color(state.value and "accent" or "track")
		if not animate or not Config.ui.animations or not tweenService then
			knob.Position = goal
			return
		end
		local ok = pcall(function()
			local info = TweenInfo.new(Config.ui.animationSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tweenService:Create(knob, info, { Position = goal }):Play()
		end)
		if not ok then
			knob.Position = goal
		end
	end

	function state.set(value, fire)
		local next_value = value and true or false
		if state.value == next_value and fire ~= true then
			return state.value
		end
		state.value = next_value
		track:SetAttribute("On", next_value)
		paint(true)
		if fire and o.onChange then
			local ok, err = pcall(o.onChange, next_value)
			if not ok then
				warn(("AFTERBURN toggles: '%s' handler failed: %s"):format(tostring(o.id), tostring(err)))
			end
		end
		return state.value
	end

	function state.get()
		return state.value
	end

	function state.setEnabled(enabled)
		state.enabled = enabled and true or false
		track.BackgroundTransparency = state.enabled and 0 or 0.5
		label.TextColor3 = Theme.color(state.enabled and "text" or "disabled")
		track.Active = state.enabled
	end

	track.Activated:Connect(function()
		if state.enabled then
			state.set(not state.value, true)
		end
	end)

	paint(false)
	track:SetAttribute("On", state.value)

	if o.parent then
		row.Parent = o.parent
	end

	return row, state
end

return Toggles
