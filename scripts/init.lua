Tracker:AddItems("items/items.json")

if (string.find(Tracker.ActiveVariantUID, "items_only")) then
  Tracker:AddLayouts("layouts/tracker.json")
elseif (string.find(Tracker.ActiveVariantUID, "map_tracker")) then
  ScriptHost:LoadScript("scripts/logic.lua")
  Tracker:AddMaps("map_tracker/maps/maps.json")
  Tracker:AddLayouts("map_tracker/layouts/tracker.json")
  Tracker:AddLocations("map_tracker/locations/locations.json")
else
  Tracker:AddLayouts("layouts/gatedTracker.json")
end

Tracker:AddLayouts("layouts/broadcast.json")

if _VERSION == "Lua 5.3" then
    ScriptHost:LoadScript("scripts/autotracking.lua")
else    
    print("Auto-tracker is unsupported by your tracker version")
end