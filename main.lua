
-- Battle Royale game mode by testman
-- v0.7

-- TODO: find a decent name
testBR = {}

testBR.scriptName = "TES3MP-Battle-Royale"

-- used for match IDs and for RNG seed
time = require("time")

-- used for generation of random numbers
math.randomseed(os.time())

-- import essay - https://www.barnorama.com/wp-content/uploads/2012/09/0113.jpg
-- load order of these is important
DataManager = require("custom/tes3mp-battle-royale/dependencies/DataManager/main")
PlayerLobby = require("custom/tes3mp-battle-royale/dependencies/PlayerLobby/main")
brConfig = require("custom/tes3mp-battle-royale/BRConfig")
brDebug = require("custom/tes3mp-battle-royale/BRDebug")
matchLogic = require("custom/tes3mp-battle-royale/game_logic/matchLogic")
playerLogic = require("custom/tes3mp-battle-royale/game_logic/playerLogic")
mapLogic = require("custom/tes3mp-battle-royale/game_logic/mapLogic")
lobbyLogic = require("custom/tes3mp-battle-royale/game_logic/lobbyLogic")
brCustomHandlers = require("custom/tes3mp-battle-royale/BRCustomHandlers")
brCustomValidators = require("custom/tes3mp-battle-royale/BRCustomValidators")
brCustomCommands = require("custom/tes3mp-battle-royale/BRCustomCommands")

-- ====================== GLOBAL VARIABLES ======================

-- used to track unique indexes of objects that present cell border
testBR.trackedObjects = {
-- basically just fog_border
cellBorderObjects = {}, 
-- items that get spawned at the start of the match
spawnedItems = {},
-- items that get dropped when player dies
droppedItems = {},
-- items that players manually moved out of their inventory
placedItems = {}
}

-- ========================= MAIN =========================

-- check the config for what type of matchmaking process is used and starts the process if needed
testBR.OnServerPostInit = function()
    -- if debug is above level 1 then write it in log
    brDebug.Log(1, "Running server in debug mode. DebugLevel: " .. tostring(brConfig.debugLevel))

    if brConfig.automaticMatchmaking then
        lobbyLogic.StartMatchProposal()
    end
    
end

return testBR

