
--
-- Script variables
--

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
  return string.find(Tracker.ActiveVariantUID, "var_itemsonly")
end

--
-- Check if the tracker is in Gated mode
--
-- Returns: True if tracker is in Character Gate mode
--          False if in an open world mode
--
function isGatedMode()
  local isMapTracker = string.find(Tracker.ActiveVariantUID, "var_maptracker")
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
--
-- Params:
--   name    - Name of the tracker item
--   segment - Memory segment to read from
--   address - Memory address of the check
--   flag    - Bit flag for the check
--   count   - Value to set the counter to
--
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
-- Update a progressive counter to a value
--
-- Params:
--   name    - Name of the tracker item
--   segment - Memory segment to read from
--   address - Memory address of the check
--   flag    - Bit flag for the check
--   count   - Value to set the counter to
--
function updateConsumable(name, segment, address, flag, count)
  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    local value = segment:ReadUInt8(address)
    if (value & flag) ~= 0 then
      trackerItem.AcquiredCount = count
    end
  else
    printDebug("updateConsumable: Unable to find tracker item: " .. name)
  end
end

--
-- Update an event based on whether or not a bit is set
--
-- Params:
--   name    - Name of the tracker item to be set
--   segment - Memory segment to read from
--   address - Memory address of the check
--   flag    - Bit flag used for this check
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
--   name    - Name of the tracker item to be set
--   segment - Memory segment to read from
--   address - Memory address of the check
--   flag    - Bit flag used for this check
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
--   flag      - Flag used to see if the character was acquired
--   name      - Name of the character's tracker object
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
  characters.AcquiredCount = charactersAcquired
end

--
-- Handle the Jidoor Auction House items.
--
-- Params:
--   segment - Memory segment to read from
--
function handleAuctionHouse(segment)
  -- AUCTION_BOUGHT_ESPER1
  --   Bought esper 1 from the auction house: 0x7E1EAD 0x10
  -- AUCTION_BOUGHT_ESPER2
  --   Bought esper 2 from the auction house: 0x7E1EAD 0x20
  local value = segment:ReadUInt8(0x7E1EAD)
  local stage = ((value & 0x20) >> 5) +
                ((value & 0x10) >> 4)
  if ((value & 0x20) >> 5) == 1 then Tracker:FindObjectForCode("AuctionHouse10kGP").Active = true end
  if ((value & 0x10) >> 4) == 1 then Tracker:FindObjectForCode("AuctionHouse20kGP").Active = true end
  local object = Tracker:FindObjectForCode("Auctioneer")
  object.AcquiredCount = stage
end

--
-- Main callback function to handle updating events and bosses.
-- This is registered with the tracker and triggered on memory updates.
--
-- Params:
--   segment - Memory segment to read from
--
function updateEventsAndBosses(segment)
  -- Open Checks
  handleAuctionHouse(segment)
  -- GOT_TRITOCH
  checkBitSet("TritochNrsh", segment, 0x7E1ED3, 0x40)
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
  checkBitSet("sealGate", segment, 0x7E1F0E, 0x02)
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
  Tracker:FindObjectForCode("Magitek").AcquiredCount = 0
  -- GOT_IFRIT_SHIVA
  checkBitSet("IfritandShiva", segment, 0x7E1E8C, 0x02)
  -- DEFEATED_NUMBER_024
  checkBitSet("Number024", segment, 0x7E1E8B, 0x80)
  -- DEFEATED_CRANES (Sets Before Killing Boss, After getting reward)
  checkBitSet("Cranes", segment, 0x7E1E8D, 0x08)
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
  Tracker:FindObjectForCode("Float").AcquiredCount = 0
  -- RECRUITED_SHADOW_FLOATING_CONTINENT
  checkBitSet("ImperialAirForce", segment, 0x7E1E85, 0x04)
  -- DEFEATED_ATMAWPN
  checkBitSet("AtmaWeapon", segment, 0x7E1E94, 0x02)
  -- FINISHED_FLOATING_CONTINENT
  checkBitSet("Nerapa", segment, 0x7E1E94, 0x20)

  -- Cyan
  -- Reset Dream Checks to 0 for game resets
  Tracker:FindObjectForCode("WoRDoma").AcquiredCount = 0
  -- DEFEATED_STOOGES
  checkBitSet("DreamStooges", segment, 0x7E1E9B, 0x01)
  -- FINISHED_DOMA_WOR
  checkBitSet("Wrexsoul", segment, 0x7E1E9B, 0x04)
  -- GOT_ALEXANDR
  checkBitSet("DomaCastleThrone", segment, 0x7E1E9B, 0x08)
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
  checkBitSet("MogDef", segment, 0x7E1EA5, 0x40)

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

  if Tracker:FindObjectForCode("ImperialCamp").Active then
    forceTreasureLocation("@All Treasure Locations/World of Balance/Imperial Camp/Kick Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Left")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Right")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Back")
  end

  if Tracker:FindObjectForCode("PhantomTrain").Active then
    forceTreasureLocation("@All Treasure Locations/World of Balance/Phantom Train/Dining Car")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Phantom Train/Third Car Far Left Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Phantom Train/Third Car Left Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Phantom Train/Third Car Right Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Phantom Train/Third Car Far Right Chest")
  end

  if Tracker:FindObjectForCode("TzenHouse").Active then
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Top Right")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Middle")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Top Left")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Left")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Bottom Left")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Bottom")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Left")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Right")
  end

  if Tracker:FindObjectForCode("WoBThamasa").Active then
    forceTreasureLocation("@All Treasure Locations/World of Balance/Burning House/First Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Burning House/Second Chest")
  end

  if Tracker:FindObjectForCode("Magitek").AcquiredCount == 3 then
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Upper Left")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Right Side Pipe")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Lower Landing")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Across Conveyor Belt")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Near Crate")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/North Lower Balcony")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Secret Room Left")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Secret Room Right")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Lower Balcony")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Hidden Chest")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Lower Left")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/South Bottom Left")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Magitek Factory/Specimen Room")
  end

  if Tracker:FindObjectForCode("Float").AcquiredCount == 3 then
    forceTreasureLocation("@All Treasure Locations/World of Balance/Floating Continent/North Path")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Floating Continent/Lower Path")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Floating Continent/Northeast of Save")
    forceTreasureLocation("@All Treasure Locations/World of Balance/Floating Continent/Escape")
  end

  if Tracker:FindObjectForCode("WoRDoma").AcquiredCount == 3 then
    forceTreasureLocation("@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Fourth Car Upper Right")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Fourth Car Middle")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Third Car Bottom Right")
    forceTreasureLocation("@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Third Car Middle")
  end
end

--
-- Callback for updating counters from word values
-- flags are from data/event_word.py
--
-- Params:
--  segment - Memory segment to read from
--
function updateCounters(segment)
  -- DRAGONS_DEFEATED
  Tracker:FindObjectForCode("Dragon").AcquiredCount = segment:ReadUInt8(0x7E1FCE)
  -- ESPERS_FOUND
  Tracker:FindObjectForCode("Esper").AcquiredCount = segment:ReadUInt8(0x7E1FC8)
end

function updateTreasureLocation(segment, location, address, flag)
  local loc = Tracker:FindObjectForCode(location)
  if loc then
    local value = segment:ReadUInt8(address)
    local locCheck = ((value & flag) ~= 0)
    if locCheck then
      loc.AvailableChestCount = loc.AvailableChestCount - 1
  else
    loc.AvailableChestCount =   loc.ChestCount
    end
  else
    printDebug("checkBitSet: Unable to find tracker location: " .. location)
  end
end

function forceTreasureLocation(location)
  local loc = Tracker:FindObjectForCode(location)
  if loc then
  loc.AvailableChestCount = loc.AvailableChestCount - 1
  else
    printDebug("checkBitSet: Unable to find tracker location: " .. location)
  end
end


function updateTreasure(segment)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Arvis's Clock", 0x7E1E40, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Elder's Clock", 0x7E1E41, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Adventuring School Advanced Battle Tactics Chest", 0x7E1E51, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Adventuring School Battle Tactics Chest", 0x7E1E51, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Adventuring School Environmental Science Chest", 0x7E1E51, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Adventuring School Environmental Science Pot", 0x7E1E51, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House South Chest", 0x7E1E41, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House Middle Right", 0x7E1E41, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House Middle Left", 0x7E1E40, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House Top Right", 0x7E1E40, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House Top Middle", 0x7E1E40, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Treasure House Top Left", 0x7E1E40, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/West Mines Right WoB", 0x7E1E60, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/West Mines Left WoB", 0x7E1E60, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Narshe/Moogle Lair WoB", 0x7E1E60, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Narshe/West Mines Right WoR", 0x7E1E41, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Narshe/West Mines Left WoR", 0x7E1E41, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Narshe/Moogle Lair WoR", 0x7E1E41, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Albrook/Armor Shop Left", 0x7E1E4C, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Albrook/Armor Shop Right", 0x7E1E4C, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Albrook/Cafe Clock", 0x7E1E4C, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Albrook/Inn Barrel", 0x7E1E4C, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Albrook/Weapon Shop Pot", 0x7E1E4C, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Albrook/Docks Crate", 0x7E1E4C, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/North Cavern Left", 0x7E1E58, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/North Cavern Right", 0x7E1E58, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/South Cavern Bottom", 0x7E1E58, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/South Cavern Top", 0x7E1E58, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/West Cavern Bottom", 0x7E1E59, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Cave/West Cavern Left", 0x7E1E59, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Castle/Treasure Room Left", 0x7E1E59, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Castle/Treasure Room Right", 0x7E1E59, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Castle/East Room", 0x7E1E59, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Castle/Library", 0x7E1E59, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Ancient Castle/Jail", 0x7E1E59, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 1", 0x7E1E4F, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 2 Bottom", 0x7E1E50, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 2 Top", 0x7E1E50, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 3 Bottom Left", 0x7E1E4F, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 3 Island", 0x7E1E4F, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 3 Plaza", 0x7E1E50, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 3 Hidden Passage", 0x7E1E4F, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Basement 3 Bridge", 0x7E1E4F, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Entrance", 0x7E1E4F, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Save Point", 0x7E1E48, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Treasure Room Left", 0x7E1E50, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Treasure Room Upper Left", 0x7E1E50, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Treasure Room Upper Floor Left", 0x7E1E50, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Sealed Gate/Treasure Room Upper Floor Right", 0x7E1E50, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Basement 2 Southeast", 0x7E1E53, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Basement 2 Southwest", 0x7E1E53, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Basement 3 Center", 0x7E1E53, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Basement 3 Right", 0x7E1E53, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Pre-Boss Room Left", 0x7E1E54, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Daryl's Tomb/Pre-Boss Room Right", 0x7E1E54, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/Cyan's Bedroom", 0x7E1E4C, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/Lower Hall Pot", 0x7E1E46, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/Southeast Tower Left", 0x7E1E46, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/Southeast Tower Right", 0x7E1E46, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/West Sleeping Quarters Chest", 0x7E1E56, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Doma Castle/West Sleeping Quarters Clock", 0x7E1E46, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Dragon's Neck/Cabin Pot", 0x7E1E5C, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Duncan's Cabin/Bucket", 0x7E1E44, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Esper Mountain/Entrance Cavern", 0x7E1E4D, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Esper Mountain/Outside Bridge", 0x7E1E4D, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Esper Mountain/Side Slope", 0x7E1E4D, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Esper Mountain/Treasure Slope", 0x7E1E4D, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Fanatic's Tower/Seventeenth Floor", 0x7E1E56, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Fanatic's Tower/Twenty-sixth Floor", 0x7E1E56, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Fanatic's Tower/Thirty-fifth Floor", 0x7E1E56, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Fanatic's Tower/Seventh Floor", 0x7E1E57, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Fanatic's Tower/Eighth Floor", 0x7E1E56, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Figaro Castle/East Shop Left", 0x7E1E41, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Figaro Castle/East Shop Right", 0x7E1E41, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Figaro Castle/Upper Hall", 0x7E1E42, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Figaro Castle/West Shop", 0x7E1E42, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 2 Treasure Room", 0x7E1E53, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 3 Treasure Room Far Left", 0x7E1E52, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 3 Treasure Room Left", 0x7E1E52, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 3 Treasure Room Right", 0x7E1E53, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 3 Treasure Room Far Right", 0x7E1E53, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Figaro Castle/Basement 3 Treasure Room Statue", 0x7E1E53, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/First Row Right", 0x7E1E4D, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/First Row Left", 0x7E1E4D, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Stove", 0x7E1E4F, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Second Row Far Right", 0x7E1E4E, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Second Row Right", 0x7E1E4E, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Second Row Left", 0x7E1E4E, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Second Row Far Left", 0x7E1E4E, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Third Row", 0x7E1E4E, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Fourth Row Left", 0x7E1E4E, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Fourth Row Right", 0x7E1E4E, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Fifth Row Left", 0x7E1E4E, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Fifth Row Right", 0x7E1E4F, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Base/Bottom Right Hidden Chest", 0x7E1E60, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Jidoor/Owzer's House Pot", 0x7E1E48, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Jidoor/Owzer's Basement Left Door", 0x7E1E5A, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Jidoor/Owzer's Basement Door Trio", 0x7E1E60, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 Balcony Left", 0x7E1E5C, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 Balcony Right", 0x7E1E5D, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 Entrance Stairs", 0x7E1E5C, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 Hidden Room", 0x7E1E5E, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 1 Metal Switchback", 0x7E1E5A, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 1 Landing Area", 0x7E1E5A, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 2 Left Area Top", 0x7E1E5B, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 2 Left Area Bottom", 0x7E1E5B, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 Right Path", 0x7E1E5B, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 After Magitek Left", 0x7E1E5B, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 3 After Magitek Right", 0x7E1E5B, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 1 Winding Path", 0x7E1E5B, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Poltergeist Hidden Chest", 0x7E1E5E, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 2 Outside Switchback", 0x7E1E5B, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 2 Pipe Output", 0x7E1E5C, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Kefka's Tower/Group 2 Switch Room", 0x7E1E5B, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Kohlingen/Old Man's House", 0x7E1E48, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Kohlingen/Rachel's House Clock", 0x7E1E48, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Maranda/Crate Left", 0x7E1E5E, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Maranda/Crate Bottom Right", 0x7E1E5E, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Mobliz/Shelter Pot", 0x7E1E54, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Mobliz/House Barrel", 0x7E1E5F, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Mobliz/Post Office Clock", 0x7E1E47, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Mt. Kolts/Exit", 0x7E1E45, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Mt. Kolts/Hidden Cavern", 0x7E1E44, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Mt. Kolts/West Face South", 0x7E1E44, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Mt. Kolts/West Face North", 0x7E1E44, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/East Cavern Middle", 0x7E1E54, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/East Cavern Right", 0x7E1E54, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/East Cavern Lower Left", 0x7E1E54, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/East Cavern Upper", 0x7E1E54, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/Treasure Slope", 0x7E1E54, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Mt. Zozo/Cyan's Room", 0x7E1E5D, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Umaro's Cave/Basement 1 Lower Left", 0x7E1E55, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Umaro's Cave/Basement 1 Left Central", 0x7E1E55, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Umaro's Cave/Basement 2 Lower Left", 0x7E1E55, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Nikeah/Inn Clock", 0x7E1E47, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Lower Cavern East Pool Island", 0x7E1E56, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Lower Cavern East Pool Bridge", 0x7E1E55, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Lower Cavern Spikes", 0x7E1E55, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Lower Cavern Rock Jumping", 0x7E1E57, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Lower Cavern Cool Lava", 0x7E1E55, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Upper Cavern Spikes", 0x7E1E55, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Upper Cavern Hidden Room", 0x7E1E58, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Upper Cavern Across Bridge", 0x7E1E55, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Phoenix Cave/Upper Cavern Near Red Dragon", 0x7E1E56, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/Banon's Room", 0x7E1E46, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/Bedroom", 0x7E1E45, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/Main Room Pot", 0x7E1E45, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Bottom Left", 0x7E1E45, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Bottom Right", 0x7E1E45, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Upper Left", 0x7E1E45, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Bucket", 0x7E1E45, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Pot", 0x7E1E45, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Returner's Hideout/North Room Secret Room", 0x7E1E46, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Serpent Trench/First Branch", 0x7E1E47, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Serpent Trench/Second Branch", 0x7E1E48, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement Hidden Path Entrance", 0x7E1E44, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement Hidden Path North Left", 0x7E1E44, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement Hidden Path North Right", 0x7E1E44, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement Hidden Path South", 0x7E1E44, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement 2 South", 0x7E1E5F, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement 2 Northeast", 0x7E1E5F, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Basement 2 Hidden Chest", 0x7E1E5F, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Old Man's Bucket", 0x7E1E43, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Secret Path Clock", 0x7E1E43, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Chocobo Stable Box WoB", 0x7E1E61, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Chocobo Stable Barrel WoB", 0x7E1E61, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Shoreline Box WoB", 0x7E1E61, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Barrel Near Cafe WoB", 0x7E1E61, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Box Near Cafe WoB", 0x7E1E61, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Arsenal Barrel WoB", 0x7E1E61, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Wall Barrel WoB", 0x7E1E62, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Exit Barrel WoB", 0x7E1E61, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Chocobo Stable Box WoR", 0x7E1E43, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Chocobo Stable Barrel WoR", 0x7E1E43, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Shoreline Box WoR", 0x7E1E5C, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Barrel Near Cafe WoR", 0x7E1E42, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Box Near Cafe WoR", 0x7E1E42, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Arsenal Barrel WoR", 0x7E1E42, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Wall Barrel WoR", 0x7E1E5C, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro/Mansion Exit Barrel WoR", 0x7E1E42, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement West Cell", 0x7E1E5F, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement East Cell", 0x7E1E60, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement East Room Left", 0x7E1E43, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement East Room Below Clock", 0x7E1E43, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement East Room Right", 0x7E1E43, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro/Mansion Basement East Room Far Right", 0x7E1E43, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro Cave/Eastern Passage", 0x7E1E60, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro Cave/Southwest Passage", 0x7E1E60, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/South Figaro Cave/Eastern Bridge", 0x7E1E61, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro Cave/Eastern Passage ", 0x7E1E4C, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro Cave/Southwest Passage ", 0x7E1E42, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ South Figaro Cave/Eastern Bridge ", 0x7E1E42, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Strago's House Near Table (Second Floor)", 0x7E1E5C, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Item Shop Barrel", 0x7E1E5F, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Relic Shop Barrel", 0x7E1E5F, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Inn Barrel", 0x7E1E5F, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Strago's House Barrel", 0x7E1E5E, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Thamasa/Elder's House Barrel", 0x7E1E5E, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Veldt Cave/North Upper Left", 0x7E1E57, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Veldt Cave/North Hidden Room", 0x7E1E58, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Veldt Cave/South Lower Left", 0x7E1E58, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Crusher Room Right", 0x7E1E5D, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Crusher Room Middle", 0x7E1E5D, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Crusher Room Left", 0x7E1E5D, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Jumping Room", 0x7E1E5C, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Lower Cavern Left", 0x7E1E58, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Lower Cavern Right", 0x7E1E5A, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Triple Bridge Right", 0x7E1E5D, 0x20)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Triple Bridge Middle", 0x7E1E5D, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Zone Eater/Triple Bridge Left", 0x7E1E5A, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Armor Shop", 0x7E1E49, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Cafe", 0x7E1E49, 0x04)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Clock Puzzle", 0x7E1E49, 0x02)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Relic Shop Seventh Floor", 0x7E1E49, 0x08)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/West Tower North Left Pot", 0x7E1E5D, 0x80)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/West Tower North Right Pot", 0x7E1E5E, 0x01)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Relic Shop Thirteenth Floor", 0x7E1E49, 0x10)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Esper Room Left", 0x7E1E48, 0x40)
  updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Zozo/Esper Room Right", 0x7E1E48, 0x80)

  if not (Tracker:FindObjectForCode("PhantomTrain").Active) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Phantom Train/Dining Car", 0x7E1E46, 0x80)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Phantom Train/Third Car Far Left Chest", 0x7E1E5E, 0x08)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Phantom Train/Third Car Left Chest", 0x7E1E47, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Phantom Train/Third Car Right Chest", 0x7E1E47, 0x08)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Phantom Train/Third Car Far Right Chest", 0x7E1E47, 0x04)
  end

  if not (Tracker:FindObjectForCode("TzenHouse").Active) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Top Right", 0x7E1E51, 0x40)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Middle", 0x7E1E52, 0x02)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Top Left", 0x7E1E51, 0x80)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Left", 0x7E1E52, 0x01)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House First Floor Bottom Left", 0x7E1E52, 0x04)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Bottom", 0x7E1E52, 0x20)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Left", 0x7E1E52, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/ Tzen/Collapsing House Basement Right", 0x7E1E52, 0x08)
  end

  if not (Tracker:FindObjectForCode("WoBThamasa").Active) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Burning House/First Chest", 0x7E1E4D, 0x01)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Burning House/Second Chest", 0x7E1E4D, 0x02)
  end

  if not (Tracker:FindObjectForCode("Magitek").AcquiredCount == 3) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Upper Left", 0x7E1E4A, 0x04)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Right Side Pipe", 0x7E1E4A, 0x08)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Lower Landing", 0x7E1E4A, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Across Conveyor Belt", 0x7E1E4A, 0x80)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Near Crate", 0x7E1E4A, 0x20)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/North Lower Balcony", 0x7E1E4A, 0x40)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Secret Room Left", 0x7E1E4B, 0x04)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Secret Room Right", 0x7E1E4B, 0x08)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Lower Balcony", 0x7E1E4B, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Hidden Chest", 0x7E1E4B, 0x20)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Lower Left", 0x7E1E4B, 0x01)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/South Bottom Left", 0x7E1E4B, 0x02)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Magitek Factory/Specimen Room", 0x7E1E4B, 0x40)
  end

  if not (Tracker:FindObjectForCode("Float").AcquiredCount == 3) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Floating Continent/North Path", 0x7E1E50, 0x80)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Floating Continent/Lower Path", 0x7E1E4B, 0x80)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Floating Continent/Northeast of Save", 0x7E1E51, 0x01)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Floating Continent/Escape", 0x7E1E51, 0x02)
  end

  if not (Tracker:FindObjectForCode("WoRDoma").AcquiredCount == 3) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Fourth Car Upper Right", 0x7E1E57, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Fourth Car Middle", 0x7E1E57, 0x20)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Third Car Bottom Right", 0x7E1E57, 0x04)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Ruin/Cyan's Dream/Phantom Train Third Car Middle", 0x7E1E57, 0x08)
  end

  if not (Tracker:FindObjectForCode("ImperialCamp").Active) then
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Camp/Kick Chest", 0x7E1E46, 0x04)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Left", 0x7E1E5A, 0x10)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Right", 0x7E1E5A, 0x08)
    updateTreasureLocation(segment, "@All Treasure Locations/World of Balance/Imperial Camp/Central Tent Back", 0x7E1E5A, 0x04)
  end

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