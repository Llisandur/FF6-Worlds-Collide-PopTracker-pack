--
-- Check if the player has enough characters and espers
-- to enter Kefka's Tower.
--
function canAccessKefkasTower()
  
  local reqChars = Tracker:FindObjectForCode("requiredchars")
  local reqEspers = Tracker:FindObjectForCode("requiredespers")
  
  local chars = Tracker:FindObjectForCode("Char")
  local espers = Tracker:FindObjectForCode("Esper")
  
  --
  -- Required characters has a minimum of 3, so offset the 
  -- current stage of collected characters by two so they match up.
  --
  return ((chars.CurrentStage - 2) >=  reqChars.CurrentStage) and 
         (espers.CurrentStage >= reqEspers.CurrentStage)
  
end

function hasRequiredCharacterCountKT()
  
  local chars = Tracker:FindObjectForCode("Char")
  
  return ((chars.CurrentStage + 1) >=  3)
  
end

function hasRequiredCharacterCountPC()
  
  local chars = Tracker:FindObjectForCode("Char")

  return ((chars.CurrentStage + 1) >=  2)
  
end