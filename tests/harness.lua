--[[
	tests/harness.lua — Roblox API mock, assertion library, suite runner.

	The mock is deliberately small but strict: it counts every instance created
	and still alive, so a page that never unmounts shows up as a leak rather than
	as a passing test. Events are real connectable objects; `world.step()` flushes
	queued timers deterministically instead of sleeping.

	Nothing here is smart about rendering — it cannot be. It verifies structure,
	arithmetic and lifecycle, which is exactly what this workspace can prove.
]]

local harness = {}

local Pass, Fail = 0, 0
local failures = {}
local current = ""
local tests = {}

--------------------------------------------------------------- assertions ----

local function render(value)
	if type(value) == "string" then
		return ("%q"):format(value)
	end
	return tostring(value)
end

function harness.expect(condition, message)
	if not condition then
		error(message or "expectation failed", 2)
	end
end

function harness.equal(actual, expected, message)
	if actual ~= expected then
		error(("%sexpected %s, got %s"):format(message and (message .. ": ") or "", render(expected), render(actual)), 2)
	end
end

function harness.notEqual(actual, unexpected, message)
	if actual == unexpected then
		error(("%sexpected a value other than %s"):format(message and (message .. ": ") or "", render(unexpected)), 2)
	end
end

function harness.near(actual, expected, tolerance, message)
	if math.abs(actual - expected) > (tolerance or 0.001) then
		error(("%sexpected %s ± %s, got %s"):format(message and (message .. ": ") or "", expected, tolerance, actual), 2)
	end
end

function harness.matches(value, pattern, message)
	if type(value) ~= "string" or not value:match(pattern) then
		error(("%sexpected %s to match %s"):format(message and (message .. ": ") or "", render(value), pattern), 2)
	end
end

function harness.errors(fn, ...)
	local ok, err = pcall(fn, ...)
	harness.expect(not ok, "expected an error, got success")
	return err
end

-------------------------------------------------------------- deep proxy ----

-- Enum.FillDirection.Horizontal, Enum.Font.Gotham, Enum.AutomaticSize.Y — every
-- level resolves to its own name, memoised so identity is stable.
local function proxy(path)
	return setmetatable({}, {
		__index = function(self, key)
			local value = proxy(path and (path .. "." .. key) or key)
			rawset(self, key, value)
			return value
		end,
		__tostring = function()
			return path and ("Enum." .. path) or "Enum"
		end,
	})
end

--------------------------------------------------------------- instance mock ----

local function newEvent()
	local listeners = {}
	local event = {}
	function event:Connect(fn)
		listeners[#listeners + 1] = fn
		local connection = { Connected = true }
		function connection:Disconnect()
			for index, candidate in ipairs(listeners) do
				if candidate == fn then
					table.remove(listeners, index)
					break
				end
			end
			connection.Connected = false
		end
		return connection
	end
	function event:Fire(...)
		for _, fn in ipairs(listeners) do
			fn(...)
		end
	end
	function event:listenerCount()
		return #listeners
	end
	return event
end

local function newInstance(world, className)
	local instance = {}
	local properties = {
		Name = className,
		ClassName = className,
		Parent = nil,
		Visible = true,
		AbsoluteSize = { X = 0, Y = 0, __vector = true },
		AbsolutePosition = { X = 0, Y = 0, __vector = true },
		Text = "",
		BackgroundTransparency = 0,
		BackgroundColor3 = nil,
		TextColor3 = nil,
		Size = nil,
		Position = nil,
		Active = true,
	}
	local children = {}
	local events = {}
	local attributes = {}

	instance.__children = children
	instance.__props = properties
	instance.__world = world

	local eventNames = {
		"Activated", "MouseEnter", "MouseLeave", "MouseButton1Click", "InputBegan", "InputEnded",
		"InputChanged", "Changed", "ChildAdded", "ChildRemoved", "DescendantAdded",
	}

	local function getEvent(name)
		events[name] = events[name] or newEvent()
		return events[name]
	end

	local mt

	mt = {
		__index = function(_, key)
			if key == "Destroy" then
				return function(self)
					if self.__destroyed then
						return
					end
					self.__destroyed = true
					for _, child in ipairs(children) do
						child:Destroy()
					end
					if properties.Parent then
						properties.Parent:RemoveChild(self)
					end
					if world.alive > 0 then
						world.alive = world.alive - 1
					end
				end
			elseif key == "SetAttribute" then
				return function(self, name, value)
					attributes[name] = value
				end
			elseif key == "GetAttribute" then
				return function(self, name)
					return attributes[name]
				end
			elseif key == "GetChildren" then
				return function(self)
					local copy = {}
					for index, child in ipairs(children) do
						copy[index] = child
					end
					return copy
				end
			elseif key == "FindFirstChildOfClass" then
				return function(self, class)
					for _, child in ipairs(children) do
						if child.ClassName == class then
							return child
						end
					end
					return nil
				end
			elseif key == "FindFirstChild" then
				return function(self, name)
					for _, child in ipairs(children) do
						if child.Name == name then
							return child
						end
					end
					return nil
				end
			elseif key == "AddChild" then
				return function(self, child)
					children[#children + 1] = child
				end
			elseif key == "RemoveChild" then
				return function(self, child)
					for index, candidate in ipairs(children) do
						if candidate == child then
							table.remove(children, index)
							return
						end
					end
				end
			elseif key == "GetPropertyChangedSignal" then
				return function(self, property)
					return getEvent("Changed:" .. property)
				end
			elseif key == "IsA" then
				return function(self, class)
					return self.ClassName == class
				end
			elseif key == "GetDescendants" then
				return function()
					return {}
				end
			end

			if events[key] ~= nil or key:match("^[A-Z]") and false then
				-- fall through to the checks below anyway
			end

			for _, name in ipairs(eventNames) do
				if name == key then
					return getEvent(name)
				end
			end

			if properties[key] ~= nil then
				return properties[key]
			end

			-- Real instances resolve a child by name on plain property access;
			-- UIManager depends on that (root.UIScale.Scale).
			for _, child in ipairs(children) do
				if child.Name == key then
					return child
				end
			end

			return nil
		end,

		__newindex = function(_, key, value)
			if key == "Parent" then
				local previous = properties.Parent
				properties.Parent = value
				if previous and previous ~= value then
					previous:RemoveChild(instance)
				end
				if value then
					value:AddChild(instance)
					world.alive = world.alive + 1
				end
				return
			end
			properties[key] = value
		end,

		__tostring = function()
			return ("%s(%s)"):format(className, tostring(properties.Name))
		end,
	}

	local proxyInstance = setmetatable(instance, mt)
	world.created = world.created + 1
	return proxyInstance
end

------------------------------------------------------------------- world ----

function harness.newWorld(options)
	local opts = options or {}
	local world = {
		created = 0,
		alive = 0,
		warns = {},
		errors = {},
		now = 0,
		timers = {},
		env = nil,
		AB = nil,
		cache = {},
		worldView = nil,
		viewport = { X = 1024, Y = 768, __vector = true },
		executor = opts.executor or false,
	}

	local env = setmetatable({}, { __index = _G })
	world.env = env

	local function vector(x, y)
		return { X = x, Y = y, __vector = true }
	end

	env._G = env
	env.Vector2 = { new = function(x, y) return vector(x, y) end }
	env.UDim = { new = function(scale, offset) return { Scale = scale, Offset = offset } end }
	env.UDim2 = {
		new = function(xs, xo, ys, yo)
			return { X = { Scale = xs, Offset = xo }, Y = { Scale = ys, Offset = yo } }
		end,
		fromOffset = function(x, y)
			return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y } }
		end,
		fromScale = function(x, y)
			return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 } }
		end,
	}
	env.Color3 = {
		new = function(r, g, b) return { R = r, G = g, B = b } end,
		fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end,
		fromHex = function(hex) return { hex = hex } end,
	}
	env.Enum = proxy(nil)
	env.Instance = {
		new = function(class)
			return newInstance(world, class)
		end,
	}
	env.typeof = function(value)
		if type(value) == "table" and rawget(value, "__vector") then
			return "Vector2"
		end
		return type(value)
	end
	env.warn = function(...)
		local parts = {}
		for index = 1, select("#", ...) do
			parts[index] = tostring(select(index, ...))
		end
		world.warns[#world.warns + 1] = table.concat(parts, " ")
	end
	env.print = function() end
	env.task = {
		delay = function(seconds, fn)
			world.timers[#world.timers + 1] = { at = world.now + (seconds or 0), fn = fn }
		end,
		spawn = function(fn) fn() end,
		wait = function() end,
	}
	env.delay = env.task.delay

	-- getgenv / gethui exist only when the test asks for an executor world.
	if opts.executor then
		local genv = {}
		env.getgenv = function() return genv end
		env.gethui = function() return nil end
	end

	local playerGui = newInstance(world, "PlayerGui")
	world.playerGui = playerGui

	local player = newInstance(world, "Player")
	player.Name = "Tester"
	player.Parent = world.playerGui

	local guiService = {
		GetGuiInset = function()
			return vector(0, 36)
		end,
	}
	local userInput = {
		InputChanged = newEvent(),
		InputBegan = newEvent(),
		InputEnded = newEvent(),
	}
	local players = {
		LocalPlayer = player,
	}
	world.player = player

	local camera = newInstance(world, "Camera")
	camera.ViewportSize = vector(1024, 768)
	world.camera = camera
	playerGui.AbsoluteSize = vector(1024, 768)

	env.game = {
		GetService = function(_, name)
			if name == "Players" then
				return players
			elseif name == "GuiService" then
				return guiService
			elseif name == "UserInputService" then
				return userInput
			elseif name == "TweenService" then
				return {
					Create = function(_, instance, info, goal)
						return {
							Play = function() world.tweens = (world.tweens or 0) + 1 end,
							Cancel = function() end,
							Completed = newEvent(),
						}
					end,
				}
			elseif name == "CoreGui" then
				return newInstance(world, "CoreGui")
			elseif name == "RunService" then
				return { Heartbeat = newEvent(), RenderStepped = newEvent() }
			end
			return newInstance(world, name .. "Service")
		end,
	}
	env.workspace = {
		CurrentCamera = camera,
	}
	env.game.Workspace = env.workspace

	-- Module loader against the real src/ tree, cached per world.
	local AB = { modules = {}, cache = {}, faults = {} }
	world.AB = AB

	function AB.Require(path)
		local key = tostring(path):gsub("%.", "/")
		local cached = AB.cache[key]
		if cached ~= nil then
			return cached
		end
		local file = "src/" .. key .. ".lua"
		if not io.open(file, "r") then
			file = key .. ".lua" -- root-level modules such as Build.lua
		end
		local chunk, err = loadfile(file, "t", env)
		if not chunk then
			error(("module '%s' failed to compile: %s"):format(key, tostring(err)), 2)
		end
		local value = chunk()
		AB.cache[key] = value
		return value
	end

	env.AFTERBURN = AB

	function world.step(seconds)
		world.now = world.now + (seconds or 0)
		local due = {}
		local remaining = {}
		for _, timer in ipairs(world.timers) do
			if timer.at <= world.now then
				due[#due + 1] = timer
			else
				remaining[#remaining + 1] = timer
			end
		end
		world.timers = remaining
		for _, timer in ipairs(due) do
			pcall(timer.fn)
		end
	end

	function world.setViewport(width, height)
		world.viewport = vector(width, height)
		camera.ViewportSize = vector(width, height)
		playerGui.AbsoluteSize = vector(width, height)
	end

	function world.countWarnings(pattern)
		local hits = 0
		for _, message in ipairs(world.warns) do
			if not pattern or message:match(pattern) then
				hits = hits + 1
			end
		end
		return hits
	end

	function world.clear()
		world.warns = {}
	end

	return world
end

-------------------------------------------------------------------- runner ----

function harness.test(name, fn)
	tests[#tests + 1] = { name = name, fn = fn }
end

function harness.suite(name)
	current = name
	print(("\n== %s =="):format(name))
end

function harness.run()
	for _, case in ipairs(tests) do
		local ok, err = xpcall(case.fn, debug.traceback)
		if ok then
			Pass = Pass + 1
			print(("PASS  [%s] %s"):format(current, case.name))
		else
			Fail = Fail + 1
			failures[#failures + 1] = { suite = current, name = case.name, err = err }
			print(("FAIL  [%s] %s\n      %s"):format(current, case.name, tostring(err):gsub("\n", "\n      ")))
		end
	end
end

function harness.summary()
	local total = Pass + Fail
	print(("\n%d checks · %d passed · %d failed"):format(total, Pass, Fail))
	if Fail > 0 then
		print("\nFailures:")
		for _, failure in ipairs(failures) do
			print(("  [%s] %s"):format(failure.suite, failure.name))
			print("    " .. tostring(failure.err):gsub("\n", "\n    "))
		end
	end
	return Fail == 0
end

function harness.counts()
	return Pass, Fail
end

harness.proxy = proxy
harness.newEvent = newEvent

return harness
