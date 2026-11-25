--[[
	Core/Navigation.lua — tab registry and mount/unmount state machine.

	Holds no UI of its own; Shell draws the rail and calls `select`. The module
	guarantees two things the suite checks: exactly one page mounted at a time,
	and teardown that leaves the content host as empty as it found it.

	A page descriptor is:
		{ id, title, glyph, order, blurb, mount(host, ctx) -> Instance, unmount?(instance) }
	mount returning nil is a fault, not a no-op, and is reported through onError.
]]

local AB = AB or _G.AFTERBURN

local Navigation = {}

local function new(ctx)
	local self = {
		tabs = {},
		byId = {},
		ctx = ctx,
		host = ctx.host,
		current = nil,
		mounted = nil,
		history = {},
		listeners = {},
		errors = {},
		destroyed = false,
	}

	local function report(id, stage, err)
		self.errors[#self.errors + 1] = { id = id, stage = stage, message = tostring(err) }
		warn(("AFTERBURN nav: %s of '%s' failed: %s"):format(stage, tostring(id), tostring(err)))
	end

	-- Pages receive this ctx on mount, so it must be usable even when the caller
	-- built the router with only a host. Every page may call ctx.scale().
	if type(self.ctx) ~= "table" then
		self.ctx = {}
	end
	if type(self.ctx.scale) ~= "function" then
		self.ctx.scale = function()
			return 1
		end
	end

	function self.onChange(listener)
		self.listeners[#self.listeners + 1] = listener
		return function()
			for index, candidate in ipairs(self.listeners) do
				if candidate == listener then
					table.remove(self.listeners, index)
					return
				end
			end
		end
	end

	function self.register(descriptor)
		if type(descriptor) ~= "table" or type(descriptor.id) ~= "string" then
			return nil, "descriptor needs an id"
		end
		if type(descriptor.mount) ~= "function" then
			return nil, ("descriptor '%s' has no mount"):format(descriptor.id)
		end
		if self.byId[descriptor.id] then
			return nil, ("duplicate tab id '%s'"):format(descriptor.id)
		end

		local record = {
			id = descriptor.id,
			title = descriptor.title or descriptor.id,
			glyph = descriptor.glyph or "",
			blurb = descriptor.blurb or "",
			order = descriptor.order or (#self.tabs + 1),
			descriptor = descriptor,
		}
		self.tabs[#self.tabs + 1] = record
		self.byId[record.id] = record
		table.sort(self.tabs, function(a, b)
			if a.order == b.order then
				return a.id < b.id
			end
			return a.order < b.order
		end)
		return record
	end

	function self.list()
		return self.tabs
	end

	function self.unmountCurrent()
		if not self.mounted then
			return true
		end
		local record = self.byId[self.current]
		local instance = self.mounted
		self.mounted = nil

		local ok, err = true, nil
		if record and type(record.descriptor.unmount) == "function" then
			ok, err = pcall(record.descriptor.unmount, instance)
		else
			ok, err = pcall(function()
				instance:Destroy()
			end)
		end
		if not ok then
			report(self.current, "unmount", err)
		end
		return ok
	end

	function self.select(id, opts)
		if self.destroyed then
			return false, "destroyed"
		end
		local record = self.byId[id]
		if not record then
			return false, ("no tab '%s'"):format(tostring(id))
		end
		if self.current == id and not (opts and opts.force) then
			return true, nil
		end

		self.unmountCurrent()

		local ok, instance = pcall(record.descriptor.mount, self.host, self.ctx)
		if not ok then
			report(id, "mount", instance)
			self.current = nil
			return false, instance
		end
		if instance == nil then
			report(id, "mount", "mount returned nil")
			self.current = nil
			return false, "mount returned nil"
		end

		self.mounted = instance
		self.current = id
		table.insert(self.history, id)

		for _, listener in ipairs(self.listeners) do
			pcall(listener, record, instance)
		end

		return true, nil
	end

	function self.back()
		if #self.history < 2 then
			return false
		end
		table.remove(self.history)
		local previous = self.history[#self.history]
		table.remove(self.history)
		return self.select(previous)
	end

	function self.destroy()
		self.unmountCurrent()
		self.destroyed = true
		self.listeners = {}
		self.history = {}
	end

	return self
end

Navigation.new = new

return Navigation
