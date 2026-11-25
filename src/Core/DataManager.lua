--[[
	Core/DataManager.lua — the one place the Dashboard gets values from.

	Every value leaves here wrapped: { value = ..., provenance = "simulated" }.
	Screens render the pair, never the bare value, so a badge cannot be forgotten
	as pages multiply — a missing field is a defect the suite can see, not
	something a screenshot has to catch.

	Provenance today is always "simulated": Config.live.enabled is false and no
	provider can read a real path yet. DataManager.provenance() is the single
	answer to "where did this come from", and Stage 7 changes only that function.

	Provider modes exist so degradation is testable rather than assumed:
	  "simulated" — the full fabricated set (default)
	  "blank"     — nothing at all
	  "partial"   — a value and a progress fraction missing
]]

local AB = AB or _G.AFTERBURN

local Config = AB.Require("Config")
local Session = AB.Require("Core.Session")

local DataManager = {}

-------------------------------------------------------------- provenance ----

--- The provenance every value carries right now.
function DataManager.provenance()
	if Config.live.enabled and DataManager.liveAvailable() then
		return "live"
	end
	return "simulated"
end

--- Stage 7 replaces the body; nothing can satisfy it yet, so it stays false.
function DataManager.liveAvailable()
	return false
end

--- Wraps a value with its provenance. Exported so fixtures speak the same shape.
function DataManager.badged(value, provenance)
	return { value = value, provenance = provenance or DataManager.provenance() }
end

---------------------------------------------------------------- provider ----

function DataManager.new(opts)
	local o = opts or {}
	local self = setmetatable({}, { __index = DataManager })
	self.mode = o.mode or "simulated"
	self.session = o.session or Session.new()
	self._provenance = o.provenance or "simulated"
	return self
end

local function wrap(self, value)
	return DataManager.badged(value, self._provenance)
end

function DataManager:identity()
	if self.mode == "blank" then
		return nil
	end
	local name = "Operator"
	local role = "Authorized session"
	if self.mode == "partial" then
		name = nil -- the tile has to fall back to a placeholder
	end
	return wrap(self, { name = name, role = role })
end

function DataManager:welcome()
	if self.mode == "blank" then
		return nil
	end
	return wrap(self, "Welcome back. Systems nominal.")
end

function DataManager:activity()
	if self.mode == "blank" then
		return nil
	end
	local state = "idle"
	if self.mode == "partial" then
		state = nil
	end
	return wrap(self, { state = state, text = "No routine running" })
end

--- Headline tiles. Values are fabricated and badged; the suite counts badges.
function DataManager:stats()
	if self.mode == "blank" then
		return {}
	end
	local uptime = Session.format(self.session:ticks())
	local stats = {
		{ id = "uptime", label = "Session", value = uptime },
		{ id = "routes", label = "Routes ready", value = "9" },
		{ id = "provider", label = "Provider", value = "Simulated" },
	}
	if self.mode == "partial" then
		stats[3].value = nil
	end
	return stats
end

--- Feature overview fractions (0..1). All fabricated.
function DataManager:overview()
	if self.mode == "blank" then
		return {}
	end
	local rows = {
		{ id = "farming", label = "Farming", progress = 0.35 },
		{ id = "mastery", label = "Mastery", progress = 0.12 },
		{ id = "raids", label = "Raids", progress = 0 },
	}
	if self.mode == "partial" then
		rows[2].progress = nil
	end
	return rows
end

function DataManager:feed()
	if self.mode == "blank" then
		return {}
	end
	return {
		{ id = "boot", kind = "info", text = "Shell initialised" },
		{ id = "sim", kind = "warning", text = "Live data disabled in Config" },
	}
end

return DataManager
