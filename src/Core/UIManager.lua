--[[
	Core/UIManager.lua — owns the ScreenGui, the safe inset, the scale and the
	theme broadcast. Nothing else creates a ScreenGui.

	Theme wiring is centralised here on purpose: modules register an instance
	against a token mapping once, and `UIManager.applyTheme()` repaints all of
	them after a switch. That is why no screen module needs a colour literal.

	Privileged parenting is probed, never assumed: getgenv().HIDEUI, then
	gethui, then PlayerGui, then CoreGui. Under Studio all of them are absent
	except PlayerGui, so the shell still appears in the F5 test.
]]

local AB = AB or _G.AFTERBURN
local Config = AB.Require("Config")
local Theme = AB.Require("Core.Theme")
local Layout = AB.Require("Core.Layout")

local UIManager = {}

local state = {
	gui = nil,
	root = nil,
	tags = {},
	buttons = {},
	metrics = nil,
	connections = {},
	alive = false,
}

------------------------------------------------------------------ helpers ----

local function guiInset()
	local guiService = game:GetService("GuiService")
	local ok, inset = pcall(function()
		return guiService:GetGuiInset()
	end)
	if ok and typeof(inset) == "Vector2" then
		return inset
	end
	return Vector2.new(0, 0)
end

local function viewport()
	local camera = workspace.CurrentCamera
	if camera then
		local ok, size = pcall(function()
			return camera.ViewportSize
		end)
		if ok and typeof(size) == "Vector2" then
			return size
		end
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui.AbsoluteSize
	end
	return Vector2.new(1024, 768)
end

local function protectedParent()
	local env = (type(getgenv) == "function" and getgenv()) or {}
	if env.HIDEUI then
		return env.HIDEUI
	end
	if type(gethui) == "function" then
		local ok, hidden = pcall(gethui)
		if ok and hidden then
			return hidden
		end
	end
	local player = game:GetService("Players").LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		return playerGui
	end
	local ok, core = pcall(function()
		return game:GetService("CoreGui")
	end)
	if ok then
		return core
	end
	return nil
end

--------------------------------------------------------------------- api ----

function UIManager.metrics()
	return state.metrics
end

function UIManager.isAlive()
	return state.alive
end

--- Registers a themed instance. `mapping` is { Property = tokenName }.
function UIManager.themed(instance, mapping)
	if instance and mapping then
		state.tags[instance] = mapping
	end
	return instance
end

function UIManager.registerButton(button)
	state.buttons[button] = true
	return button
end

function UIManager.applyTheme()
	local buttons = AB.Require("Components.Buttons")
	Theme.paint(state.tags)

	for button in pairs(state.buttons) do
		if button.Parent then
			pcall(buttons.repaint, button)
		else
			state.buttons[button] = nil
		end
	end

	if state.gui then
		state.gui:SetAttribute("Theme", Theme.current())
	end
end

--- Recomputes scale/geometry from the live viewport and re-styles the chrome.
function UIManager.refresh()
	if not state.alive or not state.root then
		return nil
	end

	local size = viewport()
	local metrics = Layout.metrics(size.X, size.Y)
	state.metrics = metrics

	state.root.Size = UDim2.new(0, metrics.windowWidth, 0, metrics.windowHeight)
	state.root.Position = UDim2.new(0.5, 0, 0.5, 0)
	state.root.UIScale.Scale = metrics.scale
	state.gui:SetAttribute("Compact", metrics.compact)
	state.gui:SetAttribute("Scale", metrics.scale)

	local shell = AB.Require("Core.Shell")
	if shell.isMounted() then
		shell.reflow(metrics)
	end

	return metrics
end

--- Mounts the ScreenGui and root frame. Returns the context other modules use.
function UIManager.mount()
	if state.alive then
		return nil, "already mounted"
	end

	local parent = protectedParent()
	if not parent then
		return nil, "no Gui parent available"
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "AfterburnUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.DisplayOrder = 64
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui:SetAttribute("Theme", Theme.current())
	gui:SetAttribute("Version", Config.brand.version)

	-- A UIScale on the root keeps every child in pre-scale units, so Layout's
	-- post-scale floor stays true no matter how small the viewport gets.
	local root = Instance.new("Frame")
	root.Name = "Window"
	root.AnchorPoint = Vector2.new(0.5, 0.5)
	root.BackgroundColor3 = Theme.color("bg")
	root.BorderSizePixel = 0
	root.ClipsDescendants = true
	root.Position = UDim2.new(0.5, 0, 0.5, 0)
	root.Parent = gui

	local scale = Instance.new("UIScale")
	scale.Name = "UIScale"
	scale.Scale = 1
	scale.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent = root

	local shadow = Instance.new("UIStroke")
	shadow.Color = Theme.color("border")
	shadow.Thickness = 1
	shadow.Parent = root

	local inset = guiInset()
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, math.max(8, math.floor(inset.Y)))
	pad.PaddingLeft = UDim.new(0, math.max(8, math.floor(inset.X)))
	pad.Parent = root

	local tainted = Instance.new("Frame")
	tainted.Name = "Tint"
	tainted.BackgroundColor3 = Theme.color("bgElevated")
	tainted.BackgroundTransparency = 1
	tainted.BorderSizePixel = 0
	tainted.Size = UDim2.new(1, 0, 1, 0)
	tainted.Parent = root

	UIManager.themed(root, { BackgroundColor3 = "bg" })
	UIManager.themed(shadow, { Color = "border" })

	state.gui = gui
	state.root = root
	state.alive = true
	state.tags = {}
	state.buttons = {}
	UIManager.themed(root, { BackgroundColor3 = "bg" })
	UIManager.themed(shadow, { Color = "border" })
	UIManager.themed(tainted, { BackgroundColor3 = "bgElevated" })

	gui.Parent = parent

	-- Viewport changes: reflow, never just shrink.
	local camera = workspace.CurrentCamera
	if camera then
		local ok, signal = pcall(function()
			return camera:GetPropertyChangedSignal("ViewportSize")
		end)
		if ok and signal then
			state.connections[#state.connections + 1] = signal:Connect(function()
				UIManager.refresh()
			end)
		end
	end
	local playerGui = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		local ok, signal = pcall(function()
			return playerGui:GetPropertyChangedSignal("AbsoluteSize")
		end)
		if ok and signal then
			state.connections[#state.connections + 1] = signal:Connect(function()
				UIManager.refresh()
			end)
		end
	end

	UIManager.refresh()

	local ctx = {
		gui = gui,
		root = root,
		content = nil,
		scale = function()
			return state.metrics and state.metrics.scale or 1
		end,
		theme = Theme.current,
	}

	return ctx
end

function UIManager.destroy()
	if not state.alive then
		return
	end
	state.alive = false

	for _, connection in ipairs(state.connections) do
		pcall(function()
			connection:Disconnect()
		end)
	end
	state.connections = {}
	state.tags = {}
	state.buttons = {}

	if state.gui then
		state.gui:Destroy()
	end
	state.gui = nil
	state.root = nil
	state.metrics = nil
end

return UIManager
