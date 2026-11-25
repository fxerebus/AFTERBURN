--[[ Tests fixture: a provider with nothing in it. ]]
local AB = _G.AFTERBURN
return AB.Require("Core.DataManager").new({ mode = "blank" })
