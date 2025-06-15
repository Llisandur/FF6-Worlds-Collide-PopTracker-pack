-- this is an example/default implementation for AP autotracking
-- it will use the mappings defined in item_mapping.lua and location_mapping.lua to track items and locations via their ids
-- it will also keep track of the current index of on_item messages in CUR_INDEX
-- addition it will keep track of what items are local items and which one are remote using the globals LOCAL_ITEMS and GLOBAL_ITEMS
-- this is useful since remote items will not reset but local items might
-- if you run into issues when touching A LOT of items/locations here, see the comment about Tracker.AllowDeferredLogicUpdate in autotracking.lua
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")

CUR_INDEX = -1
LOCAL_ITEMS = {}
GLOBAL_ITEMS = {}

-- resets an item to its initial state
function resetItem(item_code, item_type)
  local obj = Tracker:FindObjectForCode(item_code)
  if obj then
    item_type = item_type or obj.Type
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("resetItem: resetting item %s of type %s", item_code, item_type))
    end
    if item_type == "toggle" or item_type == "toggle_badged" then
      obj.Active = false
    elseif item_type == "progressive" or item_type == "progressive_toggle" then
      obj.CurrentStage = 0
      obj.Active = false
    elseif item_type == "consumable" then
      obj.AcquiredCount = 0
    elseif item_type == "custom" then
      -- your code for your custom lua items goes here
    elseif item_type == "static" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("resetItem: tried to reset static item %s", item_code))
    elseif item_type == "composite_toggle" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format(
        "resetItem: tried to reset composite_toggle item %s but composite_toggle cannot be accessed via lua." ..
        "Please use the respective left/right toggle item codes instead.", item_code))
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("resetItem: unknown item type %s for code %s", item_type, item_code))
    end
  elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("resetItem: could not find item object for code %s", item_code))
  end
end

-- advances the state of an item
function incrementItem(item_code, item_type, multiplier)
  local obj = Tracker:FindObjectForCode(item_code)
  if obj then
    item_type = item_type or obj.Type
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("incrementItem: code: %s, type %s", item_code, item_type))
    end
    if item_type == "toggle" or item_type == "toggle_badged" then
      obj.Active = true
    elseif item_type == "progressive" or item_type == "progressive_toggle" then
      if obj.Active then
        obj.CurrentStage = obj.CurrentStage + 1
      else
        obj.Active = true
      end
    elseif item_type == "consumable" then
      obj.AcquiredCount = obj.AcquiredCount + obj.Increment * multiplier
    elseif item_type == "custom" then
      -- your code for your custom lua items goes here
    elseif item_type == "static" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("incrementItem: tried to increment static item %s", item_code))
    elseif item_type == "composite_toggle" and AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format(
        "incrementItem: tried to increment composite_toggle item %s but composite_toggle cannot be access via lua." ..
        "Please use the respective left/right toggle item codes instead.", item_code))
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("incrementItem: unknown item type %s for code %s", item_type, item_code))
    end
  elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("incrementItem: could not find object for code %s", item_code))
  end
end

-- apply everything needed from slot_data, called from onClear
function apply_slot_data(slot_data)
  -- put any code here that slot_data should affect (toggling setting items for example)
end

-- called right after an AP slot is connected
function onClear(slot_data)
  -- use bulk update to pause logic updates until we are done resetting all items/locations
  Tracker.BulkUpdate = true
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("called onClear, slot_data:\n%s", dump_table(slot_data)))
  end
  CUR_INDEX = -1
  -- reset locations
  for _, mapping_entry in pairs(LOCATION_MAPPING) do
    for _, location_table in ipairs(mapping_entry) do
      if location_table then
        local location_code = location_table[1]
        if location_code then
          if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
            print(string.format("onClear: clearing location %s", location_code))
          end
          if location_code:sub(1, 1) == "@" then
            local obj = Tracker:FindObjectForCode(location_code)
            if obj then
              obj.AvailableChestCount = obj.ChestCount
            elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
              print(string.format("onClear: could not find location object for code %s", location_code))
            end
          else
            -- reset hosted item
            local item_type = location_table[2]
            resetItem(location_code, item_type)
          end
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
          print(string.format("onClear: skipping location_table with no location_code"))
        end
      elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onClear: skipping empty location_table"))
      end
    end
  end
  -- reset items
  for _, mapping_entry in pairs(ITEM_MAPPING) do
    for _, item_table in ipairs(mapping_entry) do
      if item_table then
        local item_code = item_table[1]
        local item_type = item_table[2]
        if item_code then
          resetItem(item_code, item_type)
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
          print(string.format("onClear: skipping item_table with no item_code"))
        end
      elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onClear: skipping empty item_table"))
      end
    end
  end
  apply_slot_data(slot_data)
  LOCAL_ITEMS = {}
  GLOBAL_ITEMS = {}
  -- manually run snes interface functions after onClear in case we need to update them (i.e. because they need slot_data)
  if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
    -- add snes interface functions here
  end
  Tracker.BulkUpdate = false
end

-- called when an item gets collected
function onItem(index, item_id, item_name, player_number)
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("called onItem: %s, %s, %s, %s, %s", index, item_id, item_name, player_number, CUR_INDEX))
  end
  if not AUTOTRACKER_ENABLE_ITEM_TRACKING then
    return
  end
  if index <= CUR_INDEX then
    return
  end
  local is_local = player_number == Archipelago.PlayerNumber
  CUR_INDEX = index;
  local mapping_entry = ITEM_MAPPING[item_id]
  if not mapping_entry then
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("onItem: could not find item mapping for id %s", item_id))
    end
    return
  end
  for _, item_table in pairs(mapping_entry) do
    if item_table then
      local item_code = item_table[1]
      local item_type = item_table[2]
      local multiplier = item_table[3] or 1
      if item_code then
        incrementItem(item_code, item_type, multiplier)
        -- keep track which items we touch are local and which are global
        if is_local then
          if LOCAL_ITEMS[item_code] then
            LOCAL_ITEMS[item_code] = LOCAL_ITEMS[item_code] + 1
          else
            LOCAL_ITEMS[item_code] = 1
          end
        else
          if GLOBAL_ITEMS[item_code] then
            GLOBAL_ITEMS[item_code] = GLOBAL_ITEMS[item_code] + 1
          else
            GLOBAL_ITEMS[item_code] = 1
          end
        end
      elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onClear: skipping item_table with no item_code"))
      end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("onClear: skipping empty item_table"))
    end
  end
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("local items: %s", dump_table(LOCAL_ITEMS)))
    print(string.format("global items: %s", dump_table(GLOBAL_ITEMS)))
  end
  -- track local items via snes interface
  if PopVersion < "0.20.1" or AutoTracker:GetConnectionState("SNES") == 3 then
    -- add snes interface functions for local item tracking here
  end
  --print(string.format("updatePartyAP: test %s", Tracker:ProviderCountForCode("Terra")))
end

-- called when a location gets cleared
function onLocation(location_id, location_name)
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("called onLocation: %s, %s", location_id, location_name))
  end
  if not AUTOTRACKER_ENABLE_LOCATION_TRACKING then
    return
  end
  local mapping_entry = LOCATION_MAPPING[location_id]
  if not mapping_entry then
    if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("onLocation: could not find location mapping for id %s", location_id))
    end
    return
  end
  for _, location_table in pairs(mapping_entry) do
    if location_table then
      local location_code = location_table[1]
      if location_code then
        local obj = Tracker:FindObjectForCode(location_code)
        if obj then
          if location_code:sub(1, 1) == "@" then
            obj.AvailableChestCount = obj.AvailableChestCount - 1
            print(string.format("test: %s, %s", location_table[1], location_table[2]))
          else
            -- increment hosted item
            local item_type = location_table[2]
            local multiplier = 1
            incrementItem(location_code, item_type, multiplier)
          end
        elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
          print(string.format("onLocation: could not find object for code %s", location_code))
        end
      elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
        print(string.format("onLocation: skipping location_table with no location_code"))
      end
    elseif AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
      print(string.format("onLocation: skipping empty location_table"))
    end
  end
end

-- called when a locations is scouted
function onScout(location_id, location_name, item_id, item_name, item_player)
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("called onScout: %s, %s, %s, %s, %s", location_id, location_name, item_id, item_name,
      item_player))
  end
  -- not implemented yet :(
end

-- called when a bounce message is received
function onBounce(json)
  if AUTOTRACKER_ENABLE_DEBUG_LOGGING_AP then
    print(string.format("called onBounce: %s", dump_table(json)))
  end
  -- your code goes here
end

-- add AP callbacks
-- un-/comment as needed
Archipelago:AddClearHandler("clear handler", onClear)
if AUTOTRACKER_ENABLE_ITEM_TRACKING then
  Archipelago:AddItemHandler("item handler", onItem)
end
if AUTOTRACKER_ENABLE_LOCATION_TRACKING then
  Archipelago:AddLocationHandler("location handler", onLocation)
end
-- Archipelago:AddScoutHandler("scout handler", onScout)
-- Archipelago:AddBouncedHandler("bounce handler", onBounce)




function updatePartyAP()

  local charactersAcquired = 0
  -- Toggle tracker icons based on what characters were found
  charactersAcquired = Tracker:ProviderCountForCode("Terra") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Locke") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Cyan") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Shadow") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Edgar") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Sabin") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Celes") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Strago") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Relm") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Setzer") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Mog") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Gau") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Gogo") + charactersAcquired
  charactersAcquired = Tracker:ProviderCountForCode("Umaro") + charactersAcquired

  -- Set the progressive character counter
  local characters = Tracker:FindObjectForCode("Char")
  characters.AcquiredCount = (charactersAcquired)

end

function updateDragonsAP()
  -- DRAGONS_DEFEATED
  local dragonCount = 0

  dragonCount = Tracker:ProviderCountForCode("RedDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("StormDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("BlueDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("SkullDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("GoldDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("DirtDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("WhiteDragon") + dragonCount
  dragonCount = Tracker:ProviderCountForCode("IceDragon") + dragonCount

  Tracker:FindObjectForCode("Dragon").AcquiredCount = dragonCount
end

function updateEspersAP()
  -- Espers clamped to 24 since that is all the progressive counter is defined for
  -- ESPERS_FOUND
  local esperCount = 0

  esperCount = Tracker:ProviderCountForCode("Ramuh") + esperCount
  esperCount = Tracker:ProviderCountForCode("Ifrit") + esperCount
  esperCount = Tracker:ProviderCountForCode("Shiva") + esperCount
  esperCount = Tracker:ProviderCountForCode("Siren") + esperCount
  esperCount = Tracker:ProviderCountForCode("Terrato") + esperCount
  esperCount = Tracker:ProviderCountForCode("Shoat") + esperCount
  esperCount = Tracker:ProviderCountForCode("Maduin") + esperCount
  esperCount = Tracker:ProviderCountForCode("Bismark") + esperCount
  esperCount = Tracker:ProviderCountForCode("Stray") + esperCount
  esperCount = Tracker:ProviderCountForCode("Palidor") + esperCount
  esperCount = Tracker:ProviderCountForCode("Tritoch") + esperCount
  esperCount = Tracker:ProviderCountForCode("Odin") + esperCount
  esperCount = Tracker:ProviderCountForCode("Raiden") + esperCount
  esperCount = Tracker:ProviderCountForCode("Bahamut") + esperCount
  esperCount = Tracker:ProviderCountForCode("Alexandr") + esperCount
  esperCount = Tracker:ProviderCountForCode("Crusader") + esperCount
  esperCount = Tracker:ProviderCountForCode("Ragnarok Esper") + esperCount
  esperCount = Tracker:ProviderCountForCode("Kirin") + esperCount
  esperCount = Tracker:ProviderCountForCode("ZoneSeek") + esperCount
  esperCount = Tracker:ProviderCountForCode("Carbunkl") + esperCount
  esperCount = Tracker:ProviderCountForCode("Phantom") + esperCount
  esperCount = Tracker:ProviderCountForCode("Sraphim") + esperCount
  esperCount = Tracker:ProviderCountForCode("Golem") + esperCount
  esperCount = Tracker:ProviderCountForCode("Unicorn") + esperCount
  esperCount = Tracker:ProviderCountForCode("Fenrir") + esperCount
  esperCount = Tracker:ProviderCountForCode("Starlet") + esperCount
  esperCount = Tracker:ProviderCountForCode("Phoenix") + esperCount

  Tracker:FindObjectForCode("Esper").AcquiredCount = esperCount
end


ScriptHost:AddWatchForCode("terraWatcher", "Terra", updatePartyAP)
ScriptHost:AddWatchForCode("lockeWatcher", "Locke", updatePartyAP)
ScriptHost:AddWatchForCode("cyanWatcher", "Cyan", updatePartyAP)
ScriptHost:AddWatchForCode("shadowWatcher", "Shadow", updatePartyAP)
ScriptHost:AddWatchForCode("edgarWatcher", "Edgar", updatePartyAP)
ScriptHost:AddWatchForCode("sabinWatcher", "Sabin", updatePartyAP)
ScriptHost:AddWatchForCode("celesWatcher", "Celes", updatePartyAP)
ScriptHost:AddWatchForCode("stragoWatcher", "Strago", updatePartyAP)
ScriptHost:AddWatchForCode("relmWatcher", "Relm", updatePartyAP)
ScriptHost:AddWatchForCode("setzerWatcher", "Setzer", updatePartyAP)
ScriptHost:AddWatchForCode("mogWatcher", "Mog", updatePartyAP)
ScriptHost:AddWatchForCode("gauWatcher", "Gau", updatePartyAP)
ScriptHost:AddWatchForCode("gogoWatcher", "Gogo", updatePartyAP)
ScriptHost:AddWatchForCode("umaroWatcher", "Umaro", updatePartyAP)
ScriptHost:AddWatchForCode("ramuhWatcher", "Ramuh", updateEspersAP)
ScriptHost:AddWatchForCode("ifritWatcher", "Ifrit", updateEspersAP)
ScriptHost:AddWatchForCode("shivaWatcher", "Shiva", updateEspersAP)
ScriptHost:AddWatchForCode("sirenWatcher", "Siren", updateEspersAP)
ScriptHost:AddWatchForCode("terratoWatcher", "Terrato", updateEspersAP)
ScriptHost:AddWatchForCode("shoatWatcher", "Shoat", updateEspersAP)
ScriptHost:AddWatchForCode("maduinWatcher", "Maduin", updateEspersAP)
ScriptHost:AddWatchForCode("bismarkWatcher", "Bismark", updateEspersAP)
ScriptHost:AddWatchForCode("strayWatcher", "Stray", updateEspersAP)
ScriptHost:AddWatchForCode("palidorWatcher", "Palidor", updateEspersAP)
ScriptHost:AddWatchForCode("tritochWatcher", "Tritoch", updateEspersAP)
ScriptHost:AddWatchForCode("odinWatcher", "Odin", updateEspersAP)
ScriptHost:AddWatchForCode("raidenWatcher", "Raiden", updateEspersAP)
ScriptHost:AddWatchForCode("bahamutWatcher", "Bahamut", updateEspersAP)
ScriptHost:AddWatchForCode("alexandrWatcher", "Alexandr", updateEspersAP)
ScriptHost:AddWatchForCode("crusaderWatcher", "Crusader", updateEspersAP)
ScriptHost:AddWatchForCode("ragnarokWatcher", "Ragnarok Esper", updateEspersAP)
ScriptHost:AddWatchForCode("kirinWatcher", "Kirin", updateEspersAP)
ScriptHost:AddWatchForCode("zoneseekWatcher", "ZoneSeek", updateEspersAP)
ScriptHost:AddWatchForCode("carbunklWatcher", "Carbunkl", updateEspersAP)
ScriptHost:AddWatchForCode("phantomWatcher", "Phantom", updateEspersAP)
ScriptHost:AddWatchForCode("sraphimWatcher", "Sraphim", updateEspersAP)
ScriptHost:AddWatchForCode("golemWatcher", "Golem", updateEspersAP)
ScriptHost:AddWatchForCode("unicornWatcher", "Unicorn", updateEspersAP)
ScriptHost:AddWatchForCode("fenrirWatcher", "Fenrir", updateEspersAP)
ScriptHost:AddWatchForCode("starletWatcher", "Starlet", updateEspersAP)
ScriptHost:AddWatchForCode("phoenixWatcher", "Phoenix", updateEspersAP)
ScriptHost:AddWatchForCode("redDragonWatcher", "RedDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("stormDragonWatcher", "StormDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("blueDragonWatcher", "BlueDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("skullDragonWatcher", "SkullDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("goldDragonWatcher", "GoldDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("dirtDragonWatcher", "DirtDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("whiteDragonWatcher", "WhiteDragon", updateDragonsAP)
ScriptHost:AddWatchForCode("iceDragonWatcher", "IceDragon", updateDragonsAP)