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
  return ((chars.AcquiredCount - 2) >=  reqChars.CurrentStage) and 
         (espers.AcquiredCount >= reqEspers.CurrentStage) and 
         (dragons.AcquiredCount >= reqDragons.CurrentStage)
  
end

function hasRequiredCharacterCountKT()
  
  local chars = Tracker:FindObjectForCode("Char")
  
  return ((chars.CurrentStage + 1) >=  3)
  
end

function hasRequiredCharacterCountPC()
  
  local chars = Tracker:FindObjectForCode("Char")

  return ((chars.CurrentStage + 1) >=  2)
  
end