-- put logic functions here using the Lua API: https://github.com/black-sliver/PopTracker/blob/master/doc/PACKS.md#lua-interface
-- don't be afraid to use custom logic functions. it will make many things a lot easier to maintain, for example by adding logging.
-- to see how this function gets called, check: locations/locations.json
-- example:
function has_more_then_n_consumable(n)
    local count = Tracker:ProviderCountForCode('consumable')
    local val = (count > tonumber(n))
    if ENABLE_DEBUG_LOG then
        print(string.format("called has_more_then_n_consumable: count: %s, n: %s, val: %s", count, n, val))
    end
    if val then
        return 1 -- 1 => access is in logic
    end
    return 0 -- 0 => no access
end

--
-- Check if the player has enough characters and espers
-- to enter Kefka's Tower.
--
function canAccessKefkasTower()
  
  local reqChars = Tracker:FindObjectForCode("requiredchars")
  local reqEspers = Tracker:FindObjectForCode("requiredespers")
  local reqDragons = Tracker:FindObjectForCode("requireddragons")
  
  local chars = Tracker:FindObjectForCode("Char")
  local espers = Tracker:FindObjectForCode("Esper")
  local dragons = Tracker:FindObjectForCode("Dragon")
  
  --
  -- Required characters has a minimum of 3, so offset the 
  -- current stage of collected characters by two so they match up.
  --
  return (chars.AcquiredCount >=  reqChars.AcquiredCount) and 
         (espers.AcquiredCount >= reqEspers.AcquiredCount) and 
         (dragons.AcquiredCount >= reqDragons.AcquiredCount)
  
end

function hasRequiredCharacterCountKT()
  
  local chars = Tracker:FindObjectForCode("Char")
  
  return (chars.AcquiredCount >=  3)
  
end

function hasRequiredCharacterCountPC()
  
  local chars = Tracker:FindObjectForCode("Char")

  return (chars.AcquiredCount >=  2)
  
end


function updateMagitek()

  local ifritandShivaActive = 0
  if Tracker:FindObjectForCode("IfritandShiva").Active then
    ifritandShivaActive = 1
  end
  local number024Active = 0
  if Tracker:FindObjectForCode("Number024").Active then
    number024Active = 1
  end
  local cranesActive = 0
  if Tracker:FindObjectForCode("Cranes").Active then
    cranesActive = 1
  end
  Tracker:FindObjectForCode("Magitek").AcquiredCount = ifritandShivaActive + number024Active + cranesActive
end

ScriptHost:AddWatchForCode("ifritandShivaWatcher", "IfritandShiva", updateMagitek)
ScriptHost:AddWatchForCode("number024Watcher", "Number024", updateMagitek)
ScriptHost:AddWatchForCode("cranesWatcher", "Cranes", updateMagitek)

function updateAuctioneer()

  local auctionHouse10kGpActive = 0
  if Tracker:FindObjectForCode("AuctionHouse10kGP").Active then
    auctionHouse10kGpActive = 1
  end
  local auctionHouse20kGpActive = 0
  if Tracker:FindObjectForCode("AuctionHouse20kGP").Active then
    auctionHouse20kGpActive = 1
  end
  Tracker:FindObjectForCode("Auctioneer").AcquiredCount = auctionHouse10kGpActive + auctionHouse20kGpActive
end

ScriptHost:AddWatchForCode("auctionHouse10kGpWatcher", "AuctionHouse10kGP", updateAuctioneer)
ScriptHost:AddWatchForCode("auctionHouse20kGpWatcher", "AuctionHouse20kGP", updateAuctioneer)

function updateFloat()

  local imperialAirForceActive = 0
  if Tracker:FindObjectForCode("ImperialAirForce").Active then
    imperialAirForceActive = 1
  end
  local atmaWeaponActive = 0
  if Tracker:FindObjectForCode("AtmaWeapon").Active then
    atmaWeaponActive = 1
  end
  local nerapaActive = 0
  if Tracker:FindObjectForCode("Nerapa").Active then
    nerapaActive = 1
  end
  Tracker:FindObjectForCode("Float").AcquiredCount = imperialAirForceActive + atmaWeaponActive + nerapaActive
end

ScriptHost:AddWatchForCode("imperialAirForceWatcher", "ImperialAirForce", updateFloat)
ScriptHost:AddWatchForCode("atmaWeaponWatcher", "AtmaWeapon", updateFloat)
ScriptHost:AddWatchForCode("nerapaWatcher", "Nerapa", updateFloat)

function updateWoRDoma()

  local DreamStoogesActive = 0
  if Tracker:FindObjectForCode("DreamStooges").Active then
    DreamStoogesActive = 1
  end
  local WrexsoulActive = 0
  if Tracker:FindObjectForCode("Wrexsoul").Active then
    WrexsoulActive = 1
  end
  local DomaCastleThroneActive = 0
  if Tracker:FindObjectForCode("DomaCastleThrone").Active then
    DomaCastleThroneActive = 1
  end
  Tracker:FindObjectForCode("WoRDoma").AcquiredCount = DreamStoogesActive + WrexsoulActive + DomaCastleThroneActive
end

ScriptHost:AddWatchForCode("dreamStoogesWatcher", "DreamStooges", updateWoRDoma)
ScriptHost:AddWatchForCode("wrexsoulWatcher", "Wrexsoul", updateWoRDoma)
ScriptHost:AddWatchForCode("domaCastleThroneWatcher", "DomaCastleThrone", updateWoRDoma)