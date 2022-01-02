-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
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
-- Callback function to handle updating the number of espers collected.
--
-- Params:
--   segment - Memory segment to read from
--
function updateEspers(segment)

  local espersAcquired = 0
  for i = 0, 3 do
    local byteValue = segment:ReadUInt8(0x7E1A69 + i)
    if i == 3 then
      -- The last byte only tracks 3 espers.
      -- Mask off the rest of the byte.
      byteValue = byteValue & 0x07
    end
    espersAcquired = espersAcquired + countSetBits(byteValue)
  end
  
  -- Set the progressive esper counter
  --
  -- NOTE: There are 27 espers in game, but the tracker only
  --       defines 24 progressive steps for the esper item.
  --       Clamp the value to a max of 24 since setting a 
  --       progressive item to a non-existent stage causes 
  --       it to uncheck entirely.
  --
  local espers = Tracker:FindObjectForCode("Esper")
  espers.CurrentStage = math.min(espersAcquired, 24)

end

--
-- Handle the Jidoor Auction House items.
--
-- Params:
--   segment - Memory segment to read from
--
function handleAuctionHouse(segment)

  -- Bought esper 1 from the auction house: 0x7E1EAD 0x20
  -- Bought esper 2 from the auction house: 0x7E1EAD 0x10
  local value = segment:ReadUInt8(0x7E1EAD)
  local stage = ((value & 0x20) >> 5) + 
                ((value & 0x10) >> 4)
  local object = Tracker:FindObjectForCode("Auctioneer")
  object.CurrentStage = stage
  
end

--
-- Handle the Floating Continent progressive item checks.
--
-- Params:
--   segment - Memory segment to read from
--
function handleFloatingContinent(segment)

  local currentStage = 0
  
  -- Pick up Shadow at the beginning (check 1)
  local value = segment:ReadUInt8(0x7E1E85)
  if (value & 0x04) ~= 0 then
    currentStage = currentStage + 1
  end
  
  -- This bit clears after killing Atma (check 2)  
  value = segment:ReadUInt8(0x7E1EEB)
  if (value & 0x80) == 0 then
    currentStage = currentStage + 1
  end
  
  -- Completion of the floating Continent (check 3)
  value = segment:ReadUInt8(0x7E1EEF)
  if (value & 0x20) ~= 0 then
    currentStage = currentStage + 1
  end
  
  -- Finally, set the current stage of the floating continent progressive item
  local object = Tracker:FindObjectForCode("Float")
  object.CurrentStage = currentStage

end

--
-- Handle the Magitek Factory progressive item checks.
--
-- Params:
--   segment - Memory segment to read from
--
function handleMagitekFactory(segment)

  local currentStage = 0
  
  -- Beat Ifrit/Shiva (check 1)
  local value = segment:ReadUInt8(0x7E1E8C)
  if (value & 0x01) ~= 0 then
    currentStage = currentStage + 1
  end
  
  -- This bit clears after killing #042 (check 2)  
  value = segment:ReadUInt8(0x7E1F49)
  if (value & 0x02) == 0 then
    currentStage = currentStage + 1
  end
  
  -- Award before the final boss fight (check 3)
  value = segment:ReadUInt8(0x7E1E8D)
  if (value & 0x08) ~= 0 then
    currentStage = currentStage + 1
  end
  
  -- Finally, set the current stage of the Magitek Factory progressive item
  local object = Tracker:FindObjectForCode("Magitek")
  object.CurrentStage = currentStage

end

--
-- Handle the Cyan's Dream progressive item checks.
--
-- Params:
--   segment - Memory segment to read from
--
function handleCyansDream(segment)

  local currentStage = 0
  
  local dreamPossible = segment:ReadUInt8(0x7E1EDC)
  if (dreamPossible & 0x04) ~= 0 then 
    -- Beat The Stooges (check 1)
    local value = segment:ReadUInt8(0x7E1EAF)
    if (value & 0x02) ~= 0 then
      currentStage = 1
    end
    
    value = segment:ReadUInt8(0x7E1E9B)
    if (value & 0x04) ~= 0 then
      -- Wrexsoul has been defeated
      currentStage = 2
      
      -- This bit is set after Wrexsoul dies, so don't check it
      -- unless Wrexsoul is already defeated.
      value = segment:ReadUInt8(0x7E1F29)
      if (value & 0x02) == 0 then
        currentStage = 3
      end
    end

  end
  
  -- Finally, set the current stage of the Cyan's Dream progressive item
  local object = Tracker:FindObjectForCode("WoRDoma")
  object.CurrentStage = currentStage

end


--
-- Count the number of defeated dragons and set the
-- current stage counter on the dragons progressive item.
--
-- The "Dragons Remaining" byte won't work for this since 
-- the randomizer changes it to match the number of dragons
-- required to beat the sead.
--
function handleDragonIndicator()

  local dragonStage = 0;
  
  if Tracker:FindObjectForCode("IceDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("StormDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("RedDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("BlueDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("WhiteDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("DirtDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("GoldDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  if Tracker:FindObjectForCode("SkullDragon").Active then
    dragonStage = dragonStage + 1
  end
  
  Tracker:FindObjectForCode("Dragon").CurrentStage = dragonStage
  
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
  local inGame = (AutoTracker:ReadU16(0x7E1EDE) & 0x3FFF) ~= 0
  
  -- Open Checks
  checkBitSet("Tritoch", segment, 0x7E1ED3, 0x40)
  handleAuctionHouse(segment)
  checkBitSet("TzenThief", segment, 0x7E1ECF, 0x10)
  
  --
  -- Kefka At Narshe:
  -- 0x7E1F45 0x10 is the bit that controls whether or
  -- not the NPC is present to start the event.
  --
  -- When the battle starts, 0x7E1F45 0x10 is set low and
  -- 0x7E1F45 0x01 is set high.  0x7E1F45 0x01 is cleared
  -- after the battle with Kefka is finished.
  --
  local narsheBattleStarted = segment:ReadUInt8(0x7E1F45)
  if (narsheBattleStarted & 0x10) == 0 and inGame then
    checkBitCleared("Kefka", segment, 0x7E1F45, 0x01)
  else 
    unsetTrackerItem("Kefka")
  end
  
  -- Terra Checks
  checkBitSet("Whelk", segment, 0x7E1EA6, 0x20)
  checkBitSet("LeteRiver", segment, 0x7E1ECA, 0x80)
  checkBitSet("sealCave", segment, 0x7E1F0E, 0x02)
  checkBitSet("Phunbaba", segment, 0x7E1E97, 0x80)
  
  --
  -- The Ramuh check has 2 different flags depending on whether the
  -- reward is a character or an esper.
  --    0x7E1EE3 0x40 
  --    0x7E1EE3 0x80
  --  
  -- NOTE:
  -- The bit is set high when Terra is recruited (or in open world)
  -- and set low when Ramuh has been completed.  Because there is no
  -- other flag to determine if this check is done, we have to rely on
  -- the game mode and characters collected in order to know if it
  -- should be checked.
  --
  local terra = (segment:ReadUInt8(0x7E1EDE) & 0x01) ~= 0
  if (terra or (not isGatedMode())) and inGame then
    checkBitCleared("ZozoRamuh", segment, 0x7E1EE3, 0xC0)
  else 
    unsetTrackerItem("ZozoRamuh")
  end
  
  -- Locke Checks
  checkBitSet("NarsheWpn", segment, 0x7E1E96, 0x40)
  checkBitSet("PhoenixCave", segment, 0x7E1E9A, 0x80)
  checkBitSet("tunnelArmor", segment, 0x7E1E96, 0x02)
  
  -- Setzer Checks
  checkBitSet("KohlingenDoge", segment, 0x7E1EB1, 0x40)
  checkBitSet("DarillTomb", segment, 0x7E1ED6, 0x04)
  
  -- Sabin Checks
  checkBitSet("BarenFalls", segment, 0x7E1E87, 0x40)
  checkBitSet("ImperialCamp", segment, 0x7E1E86, 0x80)
  checkBitSet("Vargas", segment, 0x7E1E82, 0x01)
  checkBitSet("PhantomTrain", segment, 0x7E1E87, 0x08)
  checkBitSet("TzenHouse", segment, 0x7E1ED1, 0x04)
  
  -- Celes Checks
  handleMagitekFactory(segment)
  checkBitSet("OperaHouse", segment, 0x7E1E8B, 0x08)
  local chainedCelesAvailable = segment:ReadUInt8(0x7E1EDC)
  if (chainedCelesAvailable & 0x40) ~= 0 then
    checkBitCleared("ChainedCeles", segment, 0x7E1EE2, 0x80)
  else
    unsetTrackerItem("ChainedCeles")    
  end  

  -- Shadow Checks
  checkBitSet("GauManor", segment, 0x7E1EAC, 0x04)
  checkBitCleared("WoRVeldt", segment, 0x7E1F2A, 0x20)
  handleFloatingContinent(segment)
  
  -- Cyan
  checkBitSet("WoBDoma", segment, 0x7E1E88, 0x01)
  checkBitSet("MtZozo", segment, 0x7E1E9A, 0x04)
  handleCyansDream(segment)
  
  -- Relm Checks
  checkBitSet("EsperMtn", segment, 0x7E1E92, 0x20)
  checkBitSet("Owzer", segment, 0x7E1EC8, 0x01)
  
  -- Strago Checks
  checkBitSet("WoBThamasa", segment, 0x7E1E92, 0x01)
  checkBitSet("EbotsRock", segment, 0x7E1EB3, 0x10)
  --checkBitSet("FanaticsTower", segment, 0x7E1EDB, 0x08) -- Boss killed
  checkBitSet("FanaticsTower", segment, 0x7E1E97, 0x04) -- Reward collected
  
  
  -- Mog Checks
  checkBitSet("LoneWolf", segment, 0x7E1ED3, 0x80)
  
  -- Edgar Checks
  checkBitCleared("FigThrone", segment, 0x7E1EE1, 0x01)
  checkBitSet("FigCave", segment, 0x7E1E98, 0x40)
  checkBitSet("AncientCastle", segment, 0x7E1EDB, 0x20)
  
  -- Gogo Checks
  checkBitSet("ZoneEater", segment, 0x7E1E9A, 0x10)
  
  -- Umaro Checks
  checkBitSet("UmaroNrsh", segment, 0x7E1E8F, 0x40)
  
  -- Gau Checks
  checkBitSet("SerpentTrench", segment, 0x7E1E8A, 0x01)
  -- See updateSpecial function for Gau Veldt check.
  
  -- Kefka's Tower
  checkBitCleared("AtmaWpn", segment, 0x7E1F57, 0x20)
  
  -- Dragons:
  -- Dragon bits are set based on location, not actual dragon.
  checkBitCleared("IceDragon", segment, 0x7E1F52, 0x20)
  checkBitSet("StormDragon", segment, 0x7E1ED3, 0x04)
  checkBitCleared("WhiteDragon", segment, 0x7E1F52, 0x10)
  checkBitCleared("BlueDragon", segment, 0x7E1F54, 0x02)
  checkBitCleared("GoldDragon", segment, 0x7E1F56, 0x08)
  checkBitCleared("SkullDragon", segment, 0x7E1F56, 0x10)
  checkBitSet("DirtDragon", segment, 0x7E1E8C, 0x02)

  -- 
  -- Don't try to track the Red Dragon until the lava room
  -- in the Phoenix Cave has been flooded.  The Red Dragon Bit
  -- is set when the room is flooded and then cleared when the
  -- Red Dragon is defeated.  
  --
  local isLavaRoomFlooded = (segment:ReadUInt8(0x7E1EDA) & 0x01) ~= 0
  if isLavaRoomFlooded then
    checkBitCleared("RedDragon", segment, 0x7E1F53, 0x10)
  else
    unsetTrackerItem("RedDragon")
  end
  
  -- Set the indicator for number of dragons killed.
  handleDragonIndicator()  
    
end

--
-- There are a couple of events that are tracked outside of the
-- normal event memory block.  These are:
--
--  - Doom Gaze defeated
--  - Gau Obtained
--
-- Params:
--   segment - Memory segment to read from
--
function updateSpecial(segment)

  checkBitSet("DoomGaze", segment, 0x7E1DD2, 0x01)
  checkBitSet("VeldtJerky", segment, 0x7E1DD2, 0x02)
  
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
ScriptHost:AddMemoryWatch("Espers", 0x7E1A69, 4, updateEspers)
ScriptHost:AddMemoryWatch("Events", 0x7E1E80, 0xDF, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Special", 0x7E1DD2, 1, updateSpecial)
ScriptHost:AddMemoryWatch("Treasure", 0x7E1E40, 0x30, updateTreasure)
