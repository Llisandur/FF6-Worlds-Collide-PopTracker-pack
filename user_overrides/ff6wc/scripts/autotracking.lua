-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = true
-------------------------------------------------------

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Enable Debug Logging:        ", "true")
end
print("---------------------------------------------------------------------")
print("")

--
-- Script variables
--

--
-- Invoked when the auto-tracker is activated/connected
--
function autotracker_started()
    
end

--
-- Print a debug message if debug logging is enabled
-- Debug messages will be printed to the developer console.
--
function printDebug(message)

  if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print(message)
  end

end

--
-- Check if the tracker is in items only mode
--
-- Returns: True if the tracker is in items only mode
--          False if the tracker is in any other mode
--
function itemsOnlyTracking()

  return string.find(Tracker.ActiveVariantUID, "items_only")

end

--
-- Check if the tracker is in Gated mode
--
-- Returns: True if tracker is in Character Gate mode
--          False if in an open world mode
--
function isGatedMode()

  local isMapTracker = string.find(Tracker.ActiveVariantUID, "map_tracker")
  
  if isMapTracker then
    -- If the tracker is in map tracker mode, check if the
    -- config option for game mode is set to "Character Gated"
    local gameMode = Tracker:FindObjectForCode("gamemode")
    return gameMode.CurrentStage == 0
  else
    -- Non-map tracker mode.  There is a chance that the player is in 
    -- the item tracking mode and is playing an open world seed, but
    -- character gated mode seems far more common.  Without a way to
    -- toggle modes, character gating is a safer default.
    return true
  end

end

--
-- Update a progressive counter to a value
-- params
--  name: name of the tracker item
--  segment: memory segment to read from
--  address: memory address of the check
--  flag : bit flag for the check
--  count : value to set the counter to

function updateProgressive(name, segment, address, flag, count)
  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    local value = segment:ReadUInt8(address)
    if (value & flag) ~= 0 then
      trackerItem.CurrentStage = count
    end
  else
    printDebug("updateProgressive: Unable to find tracker item: " .. name)  
  end
end

--
-- Update an event based on whether or not a bit is set
--
--  Params:
--    name - Name of the tracker item to be set
--    segment - Memory segment to read from
--    address - Memory address of the check
--    flag - Bit flag used for this check
--
function checkBitSet(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    local value = segment:ReadUInt8(address)
    trackerItem.Active = ((value & flag) ~= 0)
  else
    printDebug("checkBitSet: Unable to find tracker item: " .. name)  
  end
  
end

--
-- Update an event based on whether or not a bit is cleared
-- 
-- Params:
--   name - Name of the tracker item to be set
--   segment - Memory segment to read from
--   address - Memory address of the check
--   flag - Bit flag used for this check
--
function checkBitCleared(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    local value = segment:ReadUInt8(address)
    trackerItem.Active = ((value & flag) == 0)
  else
    printDebug("checkBitCleared: Unable to find tracker item: " .. name)  
  end
  
end

--
-- Manually unset a tracker item by name.
--
-- Params:
--   name - Name of the tracker item to unset
--
function unsetTrackerItem(name)

  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    trackerItem.Active = false
  else
    printDebug("unsetTrackerItem: Unable to find tracker item: " .. name)  
  end

end

--
-- Count the number of bits set in a byte.
--
-- Params:
--   value - Byte value to count
--
-- Returns: Number of high bits in the given byte
--
function countSetBits(value)

  local bitsSet = 0
  for i = 0, 8 do
    if (value & (1 << i)) > 0 then
      bitsSet = bitsSet + 1
    end
  end
  
  return bitsSet

end

--
-- Toggle a character based on whether or not he/she was found in the party.
--
-- Params:
--   byteValue - Byte value containing character information 
--   flag - Flag used to see if the character was acquired
--   name - Name of the character's tracker object
--
function toggleCharacter(byteValue, flag, name)

  character = Tracker:FindObjectForCode(name)
  if character then
    character.Active = (byteValue & flag) ~= 0
  else
    printDebug("Unable to find character: " .. name)
  end

end

--
-- Read party data and determine which characters have been found
--
-- Params:
--   segment - Memory segment to read from
--
function updateParty(segment)

  local charsByte1 = segment:ReadUInt8(0x7E1EDE)
  -- Top 2 bits of the second character byte aren't used.
  local charsByte2 = segment:ReadUInt8(0x7E1EDF) & 0x3F
  
  -- Don't track individual characters in items only mode
  if not itemsOnlyTracking() then
    -- Toggle tracker icons based on what characters were found
    toggleCharacter(charsByte1, 0x01, "Terra")
    toggleCharacter(charsByte1, 0x02, "Locke")
    toggleCharacter(charsByte1, 0x04, "Cyan")
    toggleCharacter(charsByte1, 0x08, "Shadow")
    toggleCharacter(charsByte1, 0x10, "Edgar")
    toggleCharacter(charsByte1, 0x20, "Sabin")
    toggleCharacter(charsByte1, 0x40, "Celes")
    toggleCharacter(charsByte1, 0x80, "Strago")
    toggleCharacter(charsByte2, 0x01, "Relm")
    toggleCharacter(charsByte2, 0x02, "Setzer")
    toggleCharacter(charsByte2, 0x04, "Mog")
    toggleCharacter(charsByte2, 0x08, "Gau")
    toggleCharacter(charsByte2, 0x10, "Gogo")
    toggleCharacter(charsByte2, 0x20, "Umaro")
  end
  
  local charactersAcquired = 
      math.max(countSetBits(charsByte1) + countSetBits(charsByte2), 1)
  
  -- Set the progressive character counter
  local characters = Tracker:FindObjectForCode("Char")
  characters.CurrentStage = (charactersAcquired - 1)

end

--
-- Handle the Jidoor Auction House items.
--
-- Params:
--   segment - Memory segment to read from
--
function handleAuctionHouse(segment)

  -- AUCTION_BOUGHT_ESPER1
  -- Bought esper 1 from the auction house: 0x7E1EAD 0x10
  -- AUCTION_BOUGHT_ESPER2
  -- Bought esper 2 from the auction house: 0x7E1EAD 0x20
  local value = segment:ReadUInt8(0x7E1EAD)
  local stage = ((value & 0x20) >> 5) + 
                ((value & 0x10) >> 4)
  local object = Tracker:FindObjectForCode("Auctioneer")
  object.CurrentStage = stage
  
end

--
-- Main callback function to handle updating events and bosses.
-- This is registered with the tracker and triggered on memory updates.
--
-- Params:
--   segment - Memory segment to read from
--
function updateEventsAndBosses(segment)
  
  --
  -- This is a bit of a sanity check.  If we don't have any characters
  -- then assume we are not in game.  This is used to disable some of 
  -- the checks during the starting menu screen while still allowing
  -- the tracker to track things on a selected save slot.  It's a bit of
  -- a hack, but it seems to work rather well.
  --
  -- local inGame = (AutoTracker:ReadU16(0x7E1EDE) & 0x3FFF) ~= 0
  
  -- Open Checks
  handleAuctionHouse(segment)
  -- GOT_TRITOCH
  checkBitSet("Tritoch", segment, 0x7E1ED3, 0x40)
  -- BOUGHT_ESPER_TZEN
  checkBitSet("TzenThief", segment, 0x7E1ECF, 0x10)
  -- FINISHED_NARSHE_BATTLE
  checkBitSet("Kefka", segment, 0x7E1E88, 0x40)
  -- DEFEATED_DOOM_GAZE
  checkBitSet("DoomGaze", segment, 0x7E1ED4, 0x2)
  
  -- Terra Checks
  -- DEFEATED_WHELK
  checkBitSet("Whelk", segment, 0x7E1EA6, 0x20)
  -- RODE_RAFT_LETE_RIVER
  checkBitSet("LeteRiver", segment, 0x7E1ECA, 0x80)
  -- no flag
  checkBitSet("sealCave", segment, 0x7E1F0E, 0x02)
  -- RECRUITED_TERRA_MOBLIZ
  checkBitSet("Phunbaba", segment, 0x7E1E97, 0x80)
  -- GOT_ZOZO_REWARD (new custom bit in 1.0)
  checkBitSet("ZozoRamuh", segment, 0x7E1E8A, 0x04)
  
  -- Locke Checks
  -- GOT_RAGNAROK
  checkBitSet("NarsheWpn", segment, 0x7E1E96, 0x40)
  -- RECRUITED_LOCKE_PHOENIX_CAVE
  checkBitSet("PhoenixCave", segment, 0x7E1E9A, 0x80)
  -- DEFEATED_TUNNEL_ARMOR
  checkBitSet("tunnelArmor", segment, 0x7E1E96, 0x02)
  
  -- Setzer Checks
  -- RECRUITED_SHADOW_KOHLINGEN
  checkBitSet("KohlingenDoge", segment, 0x7E1EB1, 0x40)
  -- DEFEATED_DULLAHAN
  checkBitSet("DarillTomb", segment, 0x7E1ED6, 0x04)
  
  -- Sabin Checks
  -- no flag
  checkBitSet("BarenFalls", segment, 0x7E1E87, 0x80)
  -- FINISHED_IMPERIAL_CAMP
  checkBitSet("ImperialCamp", segment, 0x7E1E86, 0x80)
  -- DEFEATED_VARGAS
  checkBitSet("Vargas", segment, 0x7E1E82, 0x01)
  -- GOT_PHANTOM_TRAIN_REWARD (toggles when picking up reward in caboose)
  checkBitSet("PhantomTrain", segment, 0x7E1EB2, 0x04)
  -- FINISHED_COLLAPSING_HOUSE
  checkBitSet("TzenHouse", segment, 0x7E1ED1, 0x04)
  
  -- Celes Checks
  -- Set magitek factory to stage to 0 for game resets
  Tracker:FindObjectForCode("Magitek").CurrentStage = 0
  -- GOT_IFRIT_SHIVA
  updateProgressive("Magitek", segment, 0x7E1E8C, 0x02, 1)
  -- DEFEATED_NUMBER_024
  updateProgressive("Magitek", segment, 0x7E1E8B, 0x80, 2)
  -- DEFEATED_CRANES (Sets Before Killing Boss, After getting reward)
  updateProgressive("Magitek", segment, 0x7E1E8D, 0x08, 3)  
  -- FINISHED_OPERA_DISRUPTION
  checkBitSet("OperaHouse", segment, 0x7E1E8B, 0x08)
  -- FREED_CELES
  checkBitSet("ChainedCeles", segment, 0x7E1E83, 0x20)

  -- Shadow Checks
  -- RECRUITED_SHADOW_GAU_FATHER_HOUSE
  checkBitSet("GauManor", segment, 0x7E1EAC, 0x04)
  -- DEFEATED_SR_BEHEMOTH
  checkBitSet("WoRVeldt", segment, 0x7E1EB3, 0x02)
  -- Reset Floating Continent to 0 for game resets
  Tracker:FindObjectForCode("Float").CurrentStage = 0
  -- RECRUITED_SHADOW_FLOATING_CONTINENT
  updateProgressive("Float", segment, 0x7E1E85, 0x04, 1)
  -- DEFEATED_ATMAWPN
  updateProgressive("Float", segment, 0x7E1E94, 0x02, 2)
  -- FINISHED_FLOATING_CONTINENT
  updateProgressive("Float", segment, 0x7E1E94, 0x20, 3)

  -- Cyan
  -- Reset Dream Checks to 0 for game resets
  Tracker:FindObjectForCode("WoRDoma").CurrentStage = 0
  -- DEFEATED_STOOGES
  updateProgressive("WoRDoma", segment, 0x7E1E9B, 0x01, 1)
  -- FINISHED_DOMA_WOR
  updateProgressive("WoRDoma", segment, 0x7E1E9B, 0x04, 2)
  -- GOT_ALEXANDR
  updateProgressive("WoRDoma", segment, 0x7E1E9B, 0x08, 3)
  -- FINISHED_DOMA_WOB
  checkBitSet("WoBDoma", segment, 0x7E1E88, 0x01)
  -- FINISHED_MT_ZOZO
  checkBitSet("MtZozo", segment, 0x7E1E9A, 0x04)
  
  -- Relm Checks
  -- DEFEATED_ULTROS_ESPER_MOUNTAIN
  checkBitSet("EsperMtn", segment, 0x7E1E92, 0x20)
  -- DEFEATED_CHADARNOOK
  checkBitSet("Owzer", segment, 0x7E1ECA, 0x08)
  
  -- Strago Checks
  -- DEFEATED_FLAME_EATER
  checkBitSet("WoBThamasa", segment, 0x7E1E92, 0x01)
  -- DEFEATED_HIDON
  checkBitSet("EbotsRock", segment, 0x7E1EB3, 0x10)
  -- RECRUITED_STRAGO_FANATICS_TOWER
  checkBitSet("FanaticsTower", segment, 0x7E1E97, 0x04)
  
  -- Mog Checks
  -- This sets right after "you'll never get", works picking either reward
  -- CHASING_LONE_WOLF7
  checkBitSet("LoneWolf", segment, 0x7E1EC7, 0x80)
    
  -- Edgar Checks
  -- NAMED_EDGAR
  checkBitSet("FigThrone", segment, 0x7E1E80, 0x10)
  -- DEFEATED_TENTACLES_FIGARO
  checkBitSet("FigCave", segment, 0x7E1E98, 0x40)
  -- GOT_RAIDEN
  checkBitSet("AncientCastle", segment, 0x7E1EDB, 0x20)
  
  -- Gogo Checks
  -- RECRUITED_GOGO_WOR
  checkBitSet("ZoneEater", segment, 0x7E1E9A, 0x10)
  
  -- Umaro Checks
  -- RECRUITED_UMARO_WOR
  checkBitSet("UmaroNrsh", segment, 0x7E1E8F, 0x40)

  -- Gau Checks
  -- GOT_SERPENT_TRENCH_REWARD
  checkBitSet("SerpentTrench", segment, 0x7E1E8A, 0x01)
  -- VELDT_REWARD_OBTAINED
  checkBitSet("VeldtJerky", segment, 0x7E1EB7, 0x10)
  
  -- Kefka's Tower
  -- DEFEATED_ATMA
  checkBitSet("AtmaWpn", segment, 0x7E1E94, 0x04)
  
  -- Dragons
  -- DEFEATED_NARSHE_DRAGON
  checkBitSet("IceDragon", segment, 0x7E1EA3, 0x04)
  -- DEFEATED_MT_ZOZO_DRAGON
  checkBitSet("StormDragon", segment, 0x7E1EA3, 0x08)
  -- DEFEATED_OPERA_HOUSE_DRAGON
  checkBitSet("DirtDragon", segment, 0x7E1EA3, 0x10)
  -- DEFEATED_KEFKA_TOWER_DRAGON_G
  checkBitSet("GoldDragon", segment, 0x7E1EA3, 0x20)
  -- DEFEATED_KEFKA_TOWER_DRAGON_S
  checkBitSet("SkullDragon", segment, 0x7E1EA3, 0x40)
  -- DEFEATED_ANCIENT_CASTLE_DRAGON
  checkBitSet("BlueDragon", segment, 0x7E1EA3, 0x80)
  -- DEFEATED_PHOENIX_CAVE_DRAGON
  checkBitSet("RedDragon", segment, 0x7E1EA4, 0x01)
  -- DEFEATED_FANATICS_TOWER_DRAGON
  checkBitSet("WhiteDragon", segment, 0x7E1EA4, 0x02)
  
end

--
-- Callback for updating counters from word values
-- flags are from data/event_word.py
--
-- Params:
--  segment - Memory segment to read from

function updateCounters(segment)
  -- DRAGONS_DEFEATED
  Tracker:FindObjectForCode("Dragon").CurrentStage = segment:ReadUInt8(0x7E1FCE)
  -- Espers clamped to 24 since that is all the progressive counter is defined for
  -- ESPERS_FOUND
  local esperCount = segment:ReadUInt8(0x7E1FC8)
  Tracker:FindObjectForCode("Esper").CurrentStage = math.min(esperCount, 24)
end

function updateTreasure(segment)
  local treasureAcquired = 0
  for i = 0, 47 do
    local byteValue = segment:ReadUInt8(0x7E1E40 + i)
    treasureAcquired = treasureAcquired + countSetBits(byteValue)
    
  end
  
  local treasures = Tracker:FindObjectForCode("Treasure")
  treasures.AcquiredCount = treasureAcquired
end 

--
-- Set up memory watches on memory used for autotracking.
--

printDebug("Adding memory watches")
ScriptHost:AddMemoryWatch("Party", 0x7E1EDE, 2, updateParty)
ScriptHost:AddMemoryWatch("Events", 0x7E1E80, 0xDF, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Counters", 0x7E1FC2, 0xD, updateCounters)
ScriptHost:AddMemoryWatch("Treasure", 0x7E1E40, 0x30, updateTreasure)