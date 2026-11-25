--[[
	Core/Session.lua — how long this run has been up.

	Plain Lua, no Roblox API, so the timer is provable here rather than in Studio.
	The clock is injected: Session.new({ clock = fn }) drives time forward in a
	test without sleeping, and defaults to os.clock at runtime.

	Session counts, it does not display policy. Formatting lives here only
	because the shape of the string is part of the contract (a run past an hour
	must not wrap to 0:00), and the Dashboard asks for it.
]]

local Session = {}
Session.__index = Session

local function realClock()
	return os.clock()
end

--- Starts a session. opts.clock replaces the time source; opts.at sets an origin.
function Session.new(opts)
	local o = opts or {}
	local self = setmetatable({}, Session)
	self._clock = o.clock or realClock
	self._origin = tonumber(o.at) or self._clock()
	self._frozen = nil
	return self
end

--- Seconds since the session opened. Never negative, even with a stuttering clock.
function Session:elapsed()
	if self._frozen ~= nil then
		return self._frozen
	end
	return math.max(0, self._clock() - self._origin)
end

--- Time the session has been up, as whole seconds. Alias kept explicit.
function Session:ticks()
	return math.floor(self:elapsed())
end

--- Stops the clock at its current value; further calls are idempotent.
function Session:stop()
	if self._frozen == nil then
		self._frozen = self:elapsed()
	end
	return self._frozen
end

function Session:stopped()
	return self._frozen ~= nil
end

--- h:mm:ss with unbounded hours, so 3600 reads 1:00:00 and not 0:00.
function Session.format(seconds)
	local total = math.max(0, math.floor(tonumber(seconds) or 0))
	local hours = total // 3600
	local minutes = (total % 3600) // 60
	local secs = total % 60
	return ("%d:%02d:%02d"):format(hours, minutes, secs)
end

--- The same value as a view label ("0:00:07" plus a unit word).
function Session.label(seconds)
	return Session.format(seconds)
end

return Session
