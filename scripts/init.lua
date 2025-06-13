-- entry point for all lua code of the pack
-- more info on the lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
ENABLE_DEBUG_LOG = true
-- get current variant
local variant = Tracker.ActiveVariantUID
-- check variant info
IS_ITEMS_ONLY = variant:find("itemsonly")
IS_MAP = variant:find("maptracker")

print("Loaded variant: ", variant)
if ENABLE_DEBUG_LOG then
  print("Debug logging is enabled!")
end

-- Utility Script for helper functions etc.
ScriptHost:LoadScript("scripts/utils.lua")

-- Logic
ScriptHost:LoadScript("scripts/logic/logic.lua")

-- Custom Items
ScriptHost:LoadScript("scripts/custom_items/class.lua")
ScriptHost:LoadScript("scripts/custom_items/progressiveTogglePlus.lua")
ScriptHost:LoadScript("scripts/custom_items/progressiveTogglePlusWrapper.lua")

-- Items
Tracker:AddItems("items/items.jsonc")
if IS_ITEMS_ONLY then
  Tracker:AddLayouts("layouts/tracker.json")
elseif IS_MAP then -- <--- use variant info to optimize loading
  -- Maps
  Tracker:AddMaps("var_maptracker/maps/maps.jsonc")
  -- Locations
  Tracker:AddLocations("var_maptracker/locations/locations.jsonc")
  -- Tracker
  Tracker:AddLayouts("var_maptracker/layouts/tracker.jsonc")
else
  Tracker:AddLayouts("layouts/gatedTracker.json")
end

-- Layout
--Tracker:AddLayouts("layouts/items.jsonc")
--Tracker:AddLayouts("layouts/tracker.jsonc")
Tracker:AddLayouts("layouts/broadcast.jsonc")

-- AutoTracking for Poptracker
if PopVersion and PopVersion >= "0.18.0" then
  ScriptHost:LoadScript("scripts/autotracking.lua")
end
