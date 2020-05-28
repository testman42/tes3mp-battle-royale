
-- Battle Royale game mode by testman
-- v0.6

-- MAXIMUM TODO:
-- as soon as this project is functional and published, figure out how to elegantly split this huge file into smaller files

-- TODO:
-- find a decent name for overall project
-- untangle all the spaghetti code
-- - A LOT OF IT
-- -- HOLY SHIT I CAN'T STRESS ENOUGH HOW MUCH FIXING AND IMPROVING THIS CODE NEEDS
-- - also comment whole thing much better
-- - should this slowly get split into multiple files?
-- - order functions in the order that makes sense
-- -- figure out how to make timers execute functions with given arguments instead of relying on global variables
-- - networking optimisations. (stop clogging up server by making massive packet spikes)
-- figure out how the zone-shrinking logic should actually work
-- - implement said decent zone-shrinking logic
-- - make shrinking take some time instead of being an instant event
-- - make zone circle-shaped (or at least blocky pixelated circle shaped)
-- make fog_limits be already in place, just enable / disable them instead of placing them
-- make players unable to open vanilla containers
-- implement custom containers that can be opened by players
-- clear inventory
-- think about restore fatigue constant effect
-- make sure to clear spells
-- implement hybrid playerzone shrinking system:
-- - use cell based system at the start
-- - switch to coordinates-math-distance-circle at the end
-- maybe make player unable to drop items?
-- implement a config option that determines if server will use 2-step match initiation (/newmatch and then /ready) or just one (just /ready)
-- - read: do we even want everyone on server to participate in round or do we allow them to "sit a round out"?
-- - will use a single step match creation logic for now. Figure out proper two-step match creation mechanics in this time.
-- - well, the creation logic will always be two-step. Difference is just if the first step is in hands of players or if it's automated by server
-- decide on terminoligy. Is one session of battle royale called a "match" or a "round"?
-- - Renaming all to "match" for now just for consistency, can Ctrl+H it later
-- decide on what should always be part of a log and what should be just debug message
-- - properly define debug levels
-- - warning messages about game mechanics (eg. "In this match you can not enter interiors"
-- - tell fog stage to players (include "x out of y" in fog shrink message")
--[[

=================== DESIGN DOCUMENT PART ===================

Usually I like to plan out project development, but this time I went directly into the code and I got lost very quickly in a mess of concepts.
So with this we are taking a step back and defining some things that can help make sense of this mess of a code below.

Match start logic:

There are two stages of the lobby process.

First one is when there is nothing happening. Players are in the lobby, they can move around, also they can fight and kill each other without consequences.
They respawn in lobby if killed. At this stage, it is possible to initiate second stage.
The second stage is used to determine if match can be started and which players will be participating in said match.
The variable in the configuration section of this script determines if the players are in control of initiating the second stage or if it is controlled by server.
The second stage lasts for the determined amount of time and at the end of that period the server checks if criteria for start of the match is met.
Criteria 
If initiation of second stage is controlled by the server, then the stage starts as soon as the second player logs in.

maybe TODO: draw flowchart for this process using http://asciiflow.com/

Overall logic:

players spawn in lobby (currently modified ToddTest) by default, where they can sign up for next round and wait until it starts
once round starts, players get teleported to exterior, timers for parachuting logic and also timer for fog shrinking starts.
From that point on we differentiate between players in lobby and players in game. Well, players who are in lobby stay like they were and
players who are in round get to do battle royale stuff until they get killed or round ends. After that they get flagged as out of round and 
spawn in lobby with rest of players.

fog - the thing that battle royale games have. It shrinks over time and damages players who stand in it. Most other games call it "storm" if I am not mistaken.

fogGridLimits - an array that contains the bottom left (min X and min Y) and top right (max X and max Y) for each level

fog grid - Currently used logic is square-based, but same principle could easily work for other shapes, preferably circle (https://en.wikipedia.org/wiki/Midpoint_circle_algorithm)
(and https://www.ques10.com/p/10771/explain-the-midpoint-circle-generating-algorithm-1/)
Whole area gets segmented when the match starts, so that it doesn't have to determine each new zone when fog starts shrinking
Below example is for grid with 4 levels. Each time fog shrinks, it moves one level in. and all cells in that area start dealing damage to player

+------------------------------#
| 1                            |
|  +------------------#        |
|  | 2    +---------# |        |
|  |      | 3       | |        |
|  |      | +--#    | |        |
|  |      | | 4|    | |        |
|  |      | #--+    | |        |
|  |      #---------+ |        |
|  |                  |        |
|  |                  |        |
|  #------------------+        |
|                              |
|                              |
#------------------------------+
(# represents the coordinates that are saved in array, + and the lines are extrapolated from the given two cells)

Distance between cells is exactly 8192 units
https://wiki.openmw.org/index.php?title=Measurement_Units

scale for fog_border to fit across whole length of a cell is 2.677

fogZone - one set of cells. It is used to easily determine if cell that player entered should cause damage to player or not.
-- TODO: this needs to be renamed to "zone" or something like it, because overuse of the term "level" in this script is getting out of hand

fogStage - basically index of fog progress

example of shrink durations: https://pubg.gamepedia.com/The_Playzone#Maps (think about using this for ratio between shrink times)
https://www.reddit.com/r/FortNiteBR/comments/78y6mp/total_time_for_storm_to_close/doxn1jh/

On Linux use loop "while :; do ./tes3mp-server || rm -f CoreScripts/data/cell/* && cp CoreScripts/data/clean_ToddTest.json CoreScripts/data/cell/ToddTest.json; done" to run server
Best if done in tmux

]]

-- TODO: find a decent name
testBR = {}

-- ====================== CONFIG SECTION ======================

-- print out a lot more messages about what script is doing
-- TODO: properly define debug levels
debugLevel = 0

-- how fast time passes
-- you will most likely want this to be very low in order to have skybox remain the same
--timeScale = 0.1

-- determines default time of day, can be used to regulate brightness
--timeOfDay = 9

-- determines default weather
--weather = 0

-- Determines if the effects from player's chosen race get applied
--allowRacePowers = false

-- Determines if the effects from player's chosen celestial sign get applied
--allowSignPowers = false

-- Determines if it is possible to use different presets of equipment / stats 
--allowClasses = true

-- Determines if players are allowed to move into cells that are not part of exterior
-- allowEnteringInteriorCells = false

-- define image files for map
fogWarnFilePath = tes3mp.GetDataPath() .. "/map/fogwarn.png"
fog1FilePath = tes3mp.GetDataPath() .. "/map/fog1.png"
fog2FilePath = tes3mp.GetDataPath() .. "/map/fog2.png"
fog3FilePath = tes3mp.GetDataPath() .. "/map/fog3.png"
fogFilePaths = {fogWarnFilePath, fog1FilePath, fog2FilePath, fog3FilePath}

-- default stats for players
defaultStats = {
playerLevel = 1,
playerAttributes = 80,
playerSkills = 80,
playerHealth = 200,
--playerHealth = 10000,
playerMagicka = 100,
playerFatigue = 300,
playerLuck = 100,
playerSpeed = 100,
playerAcrobatics = 75,
playerMarksman = 150
}

-- turns out it's much easier if you don't try to combine arrays whose elements do not necesarily correspond
-- config that determines how the fog will behave 
fogZoneSizes = {"all", 20, 15, 10, 5, 3, 1}

-- Actual attempt
--fogStageDurations = {500, 400, 240, 120, 90, 60, 30, 0}
-- Debug durations, first one for automatic quick iteration, second one for manual control
--fogStageDurations = {10, 10, 10, 10, 10, 10, 10, 10, 10, 10}
fogStageDurations = {9000, 9000, 9000, 9000, 9000, 9000, 9000, 0}

-- determines the order of how levels increase damage
-- TODO: Would it make more sense to abandon this and instead map values to integers
-- have -1 be "nothing", 0 would be warning, and then positive integers
-- but that would make whole thing less customisable
-- let's keep it like this for now
fogDamageValues = {"warn", 1, 2, 3}


-- used to determine the cell span on which to use the fog logic
-- {{min_X, min_Y},{max_X, max_Y}}
mapBorders = {{-15,-15}, {25,25}}

-- determines how the process for starting the match goes
-- if true, then server periodically proposes new match and starts it if criteria is met (just /ready)
-- if false, then players are in control of proposing a new match (/newmatch then /ready)
automaticMatchmaking = true

-- how many seconds does match proposal last
matchProposalTime = 30

-- ID of the cell that is used for lobby
-- remember that this is case sensitive
lobbyCell = "ToddTest"

-- position in lobby cell where player spawns
lobbyCoordinates = {2177.776367, 653.002380, -184.874023}

-- how the shrinking zone is called in game
-- start with uppercase because it's at the start of the sentence
fogName = "Blight storm" 
--fogName = "Blizzard"

-- how long does each stage last, in seconds
-- enter values in reverse, because airmode is used as index
-- since airmode gets decreased over time, this array gets used from last value to first
-- 15 is about how much time it takes to fall from spawn to the top of Red Mountain. 
-- 30 should be enough to fall to any ground safely
-- - apparenlty it is not because of some networking / performance thing. 40 should really be enough though
-- TODO: does anyone want this to be in ascending order? We could use #airDropStageTimes - airmode + 1 to achieve this.
airDropStageTimes = {40, 25}
--airDropStageTimes = {35, 2500}

-- list of weapons used to generate random loot
-- TODO: this is more complex than just one list, loot tables will require more lists
--weaponList = {}

-- list of armor used to generate random loot
--armorList = {}

-- loot tables
-- "loot tables" in vanilla game: https://en.uesp.net/wiki/Morrowind:Leveled_Lists
lootTables = {
armor = {},
weapons = {},
potions = {},
scrolls = {},
ingredients = {}
}

lootTables.armor[1] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
lootTables.armor[2] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
lootTables.armor[3] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
lootTables.armor[4] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
lootTables.weapons[1] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
lootTables.weapons[2] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
lootTables.weapons[3] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
lootTables.weapons[4] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
lootTables.potions[1] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
lootTables.potions[2] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
lootTables.potions[3] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
lootTables.potions[4] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
lootTables.scrolls[1] = {"sc_frostguard", "sc_firstbarrier"}
lootTables.scrolls[2] = {"sc_frostguard", "sc_firstbarrier"}
lootTables.scrolls[3] = {"sc_frostguard", "sc_firstbarrier"}
lootTables.scrolls[4] = {"sc_frostguard", "sc_firstbarrier"}
lootTables.ingredients[1] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
lootTables.ingredients[2] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
lootTables.ingredients[3] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
lootTables.ingredients[4] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}


-- x, z, y so spawning function has to be adjusted
lootSpawnLocations ={
{"0, -7", 1897.5004882812, 1473.7244873047, -57060.12109375},
{"0, -7", 5335.876953125, 1672.0218505859, -56260.42578125},
{"-11, 11", -85677.1953125, 997.19689941406, 91837.0546875},
{"18, 3", 149032.09375, 648.02185058594, 29671.837890625},
{"18, 4", 147871.765625, 680.02185058594, 38927.62109375},
{"-2, -9", -11254.506835938, 218.03240966797, -70889.328125},
{"3, -10", 29876.8046875, 768.02185058594, -76459.2265625},
{"-3, -2", -23688.044921875, 504.02185058594, -16165.71875},
{"-3, -2", -17149.45703125, 168.02185058594, -15837.62890625},
{"-3, -2", -17338.44921875, 160.02185058594, -11923.168945312},
{"4, -11", 33648.3046875, 576.02191162109, -89430.1171875},
{"4, -13", 32827.9296875, 1054.3166503906, -98990.921875},
{"-4, -2", -24935.73046875, 960.02185058594, -12761.151367188},
{"6, -7", 53834.80078125, 160.48626708984, -51331.71484375},
{"7, 22", 61849.34765625, 255.99046325684, 182278.78125}
}


-- ====================== GLOBAL VARIABLES ======================

-- unique identifier for the match
matchID = nil

-- indicates if there is currently an active match going on
matchInProgress = false

-- indicates if match proposal is currently in progress
matchProposalInProgress = false

-- keep track of which players are in a match
-- used in actual match logic
playerList = {}

-- list of players (PIDs) who are ready to start a match
-- used just for the pre-match logic. If criteria for starting the match is met, playerList becomes a copy of this list
readyList = {}

-- used to track the fog progress
currentFogStage = 1

-- used to store ony bottom left and top right corner of each level
fogGridLimits = {}

-- used to track unique indexes of objects that present cell border
trackedObjects = {
cellBorderObjects = {},
spawnedItems = {},
droppedItems = {},
placedItems = {}
}

-- for warnings about time remaining until fog shrinks
fogShrinkRemainingTime = 0

-- used for handling the stages of player movement at the start of the match
airmode = 0

-- ====================== FUN STARTS HERE ======================

-- used for match IDs and for RNG seed
time = require("time")

-- used for generation of random numbers
math.randomseed(os.time())

-- ====================== UTILITY FUNCTIONS ======================

-- used to easily regulate the level of information when debugging
function DebugLog(requiredDebugLevel, message)
	if debugLevel >= requiredDebugLevel then
		tes3mp.LogMessage(2, message)
	end
end

-- used to easily regulate the level of information when debugging
function DebugMessage(requiredDebugLevel, pid, message)
	if debugLevel >= requiredDebugLevel then
		tes3mp.SendMessage(pid, message, true)
	end
end

-- check if numbers are both positive or both negative
function DoNumbersHaveSameSign(number1, number2)
    return (number1 >= 0 and number2 >= 0) or (number1 < 0 and number1 < 0)
end

-- return a deep copy of a table
-- https://gist.github.com/MihailJP/3931841
function copyTable(t) 
    if type(t) ~= "table" then return t end
    local meta = getmetatable(t)
    local target = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            target[k] = clone(v)
        else
            target[k] = v
        end
    end
    setmetatable(target, meta)
    return target
end

-- searches list for value
-- since we can't steal "if element in list" from Python
function IsInList(value, list)
    for index, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

-- since apparently doing table.remove(table, value) would be just too easy
function RemoveFromList(value, list)
    for index, item in ipairs(list) do
        if item == value then
            table.remove(list, index)
        end
    end
end

-- ====================== MATCH-RELATED FUNCTIONS =====================

-- Advances the shrinking process for one phase 
function AdvanceFog()
	tes3mp.SendMessage(0,fogName .. " is shrinking.\n", true)
	currentFogStage = currentFogStage + 1

    testBR.StartFogTimerForStage(currentFogStage)

	testBR.UpdateMap()

    testBR.UpdateZoneBorder()

	for _, pid in pairs(playerList) do
		if Players[pid]:IsLoggedIn() then
			-- send new map state to player
			testBR.SendMapToPlayer(pid)
			-- apply fog effects to players in cells that are now in fog
			testBR.UpdateDamageLevel(pid)
		end
	end
end

-- Used to initiate next step of the air-drop process
function HandleAirTimerTimeout()
    DebugLog(2, "AirTimer Timeout")
    testBR.HandleAirMode()
end

-- Used to handle the warnings related to the zone-shrinking process
function HandleShrinkTimerAlertTimeout()
	for _, pid in pairs(playerList) do
        if Players[pid]:IsLoggedIn() then
		    if fogShrinkRemainingTime > 60 then
			    tes3mp.MessageBox(pid, -1, fogName .. " shrinking in a minute!")
		    else
			    tes3mp.MessageBox(pid, -1, fogName .. " shrinking in " .. tostring(fogShrinkRemainingTime))
		    end
        end
	end

	-- now that minute warning is done, set timer for 10 second warning
	if fogShrinkRemainingTime > 60 then
		fogShrinkRemainingTime = 50 
	end
	
	-- stop making new timers if time is up
	if fogShrinkRemainingTime > 1 then
		-- for warning each second for last 10 seconds
		if fogShrinkRemainingTime <= 10 then
			fogShrinkRemainingTime = fogShrinkRemainingTime - 1
		end
		testBR.StartShrinkAlertTimer(fogShrinkRemainingTime)
	end
end

-- Evaluates if the new match should be started and starts it if criteria is met
function EndMatchProposal()
	tes3mp.LogMessage(2, "Ending current match proposal")
    matchProposalInProgress = false
    DebugLog(2, "readyList has " .. tostring(#readyList) .. " PIDs in it")
	if #readyList >= 2 then
        tes3mp.SendMessage(0, "Match has started.\n", true)
		testBR.StartMatch()
	else
		tes3mp.SendMessage(0, "Match was not started.\n", true)
        if automaticMatchmaking then
            testBR.StartMatchProposal()
        end
	end
    readyList = {}
end


-- check the config for what type of matchmaking process is used and starts the process if needed
testBR.OnServerPostInit = function()
    if automaticMatchmaking then
        testBR.StartMatchProposal()
    end
end

-- Initiates the battle royale match for players who decided to participate
testBR.StartMatch = function()
	matchID = os.time()
	tes3mp.LogMessage(2, "Starting a battle royale match with ID " .. tostring(matchID))

	playerList = copyTable(readyList)

    testBR.StartFogShrink()

    testBR.ResetMapTiles()

    testBR.SpawnLoot()

    DebugLog(2, "playerList has " .. tostring(#playerList) .. " PIDs in it")
	for _, pid in pairs(playerList) do
        if Players[pid]:IsLoggedIn() then
            tes3mp.SendWorldMap(pid)
            testBR.PlayerInit(pid)
        else
            RemoveFromList(pid, playerList)
        end
	end

    -- has to be after for loop, otherwise PlayerInit resets the initial speed given by first stage of Airdrop
    testBR.StartAirdrop()
	
end

-- end match and send everyone back to the lobby
testBR.EndMatch = function()
    -- Stop the shhrinking timer
    tes3mp.StopTimer(fogTimer)
    -- respawn all the remaining players back in lobby
	for _, pid in pairs(playerList) do
        if Players[pid]:IsLoggedIn() then
		    testBR.SpawnPlayer(pid, true)
            testBR.SetFogDamageLevel(pid, 0)
        end
	end
    playerList = {}
    testBR.ResetWorld()

    if automaticMatchmaking then
        testBR.StartMatchProposal()
    end
end

-- TODO: implement this after implementing chests / drop-on-death
testBR.ResetWorld = function()

    -- removes the last border
    --testBR.RemovePreviousBorder()

    --cleans up items
    --testBR.RemoveAllItems()
    --testBR.ResetCells()
    --testBR.ResetTimeOfDay()
    --testBR.ResetWeather()

    -- TODO: would this be more elegant with functions or is it fine to just brute-force through the list?
    for _, list in pairs(trackedObjects) do
        for index, entry in pairs(list) do
            testBR.DeleteObject(entry[1], entry[2])
        end
    end
    
end

-- place object in exterior
-- if list is given, the mpNum will be aded to that list
testBR.PlaceObject = function(object_id, cell, x, y, z, rot_x, rot_y, rot_z, scale, list, object_count, object_charge)
	DebugLog(2, "Placing object " .. tostring(object_id))
    DebugLog(3, "x: " .. tostring(x) .. ", y: " .. tostring(y) .. ", z: " .. tostring(z))
	local mpNum = WorldInstance:GetCurrentMpNum() + 1
	local refId = object_id
    local location = {posX = x, posY = y, posZ = z, rotX = rot_x, rotY = rot_y, rotZ = rot_z}
	local refIndex =  0 .. "-" .. mpNum
    if object_count and object_charge then
	    local itemref = {refId = object_id, count = object_count, charge = object_charge }
    end
	
	WorldInstance:SetCurrentMpNum(mpNum)
	tes3mp.SetCurrentMpNum(mpNum)

	if LoadedCells[cell] == nil then
		logicHandler.LoadCell(cell)
	end
	LoadedCells[cell]:InitializeObjectData(refIndex, refId)
	LoadedCells[cell].data.objectData[refIndex].location = location
	LoadedCells[cell].data.objectData[refIndex].scale = scale
	table.insert(LoadedCells[cell].data.packets.place, refIndex)

    -- add object to the list
    -- this is basically used just to track instances of fog_border
    if list then
        entry = {cell, refIndex}
        table.insert(list, entry)
    end

    -- TODO: ask David about networking. Do we have to send one package for each object placement
    -- or can that be grouped together in some way.
	DebugLog(2, "Sending object info to players")
	for onlinePid, player in pairs(Players) do
		if Players[onlinePid]:IsLoggedIn() then
			tes3mp.InitializeEvent(onlinePid)
			tes3mp.SetEventCell(cell)
			tes3mp.SetObjectRefId(refId)
            if object_count and object_charge then
			    tes3mp.SetObjectCount(object_count)
			    tes3mp.SetObjectCharge(object_count)
            else
                tes3mp.SetObjectCount(1)
			    tes3mp.SetObjectCharge(-1)
            end
			tes3mp.SetObjectRefNumIndex(0)
			tes3mp.SetObjectMpNum(mpNum)
			tes3mp.SetObjectPosition(location.posX, location.posY, location.posZ)
			tes3mp.SetObjectRotation(location.rotX, location.rotY, location.rotZ)
			tes3mp.SetObjectScale(scale)
			tes3mp.AddWorldObject()
			tes3mp.SendObjectPlace()
			tes3mp.SendObjectScale()
		end
	end
	LoadedCells[cell]:Save()
end

testBR.DeleteObject = function(cellName, objectUniqueIndex)
    if cellName and LoadedCells[cellName] then
        LoadedCells[cellName]:DeleteObjectData(objectUniqueIndex)
        logicHandler.DeleteObjectForEveryone(cellName, objectUniqueIndex)
    end
end

-- place an object that represents a border between the given coordinates
testBR.PlaceBorderBetweenPoints = function(x, y)
    -- calculate the middle between the points
    -- - Khan Academy: https://www.youtube.com/watch?v=Ez_-RwV9WVo
    -- calculate rotation
    -- calculate distance between points, use it to determine object scale

end

-- 
testBR.PlaceBorderBetweenCells = function(cell1_x, cell1_y, cell2_x, cell2_y)
    -- checke on whichh axis to place border
    -- border can be either horisontal or vertical.
    -- Horisontal between two cells where one is "on top" of the other. (different Y coordinates)
    -- Vertical when cells are next to each other. (Different X coordinates)
    -- If neither of axis has same value, then cells have no border between them
    local horisontal_border = nil
    -- 3.14159 (pi) is 180 degrees, 1.5708 is 90 degrees
    local rotation = 0

    -- TODO: rewrite this in a decent way, so that it doesn't end up in a CS Diploma meme
    if cell1_x == cell2_x then
        horisontal_border = false
    elseif cell1_y == cell2_y then
        horisontal_border = true
        rotation = 1.5708
    else
        -- turns out cells don't even share the edge lol
        tes3mp.LogMessage(2, "Cells have no sides in common, can't place border between them")
        return
    end

    DebugLog(3, "Finding host cell for border between " .. tostring(cell1_x) .. ", " .. tostring(cell1_y) .. " and " .. tostring(cell2_x) .. ", " .. tostring(cell2_y))
    -- figure out which cell should host the border
    -- technically, each cell has only two options to host: bottom edge or left edge. Top edge and right edge are already in domain of the neighbouring cells
    -- TES3MP requires correct cell to be used when placing objects. If object coordinates are outside of the cell, it will not spawn
    -- 0,0 is in the bottom left corner of the cell 0,0, so everything below and including 8191,8191 goes into that cell
    -- 8192,8192 goes into cell 1,1 | 8192,8191 goes into cell 1,0 | 8191,8192 goes into cell 0,1
    -- so border between 0,0 and 0,1 would be hosted in 0,1. Between -1,0 and 0,0, the 0,0 would host border. Between -1,-42 and -1,-43 the -1,-42 would host
    local host_cell = nil
    -- we are comparing just if greater. not equal, not smaller.
    -- one of those is always equial, otherwise function would have exited already
    -- so we are interested just in the other one. If it's smaller, then
    if cell1_x > cell2_x or cell1_y > cell2_y then
        host_cell = 1
    else
        host_cell = 2
    end
    
    local cells = {{cell1_x, cell1_y}, {cell2_x, cell2_y}}
    local host_cell_string = tostring(cells[host_cell][1]) .. ", " .. tostring(cells[host_cell][2])
    local x_coordinate = cells[host_cell][1] * 8192
    local y_coordinate = cells[host_cell][2] * 8192

    if horisontal_border then
        y_coordinate = y_coordinate + 4096
    else
        x_coordinate = x_coordinate + 4096
    end

    -- TODO: Figure out way to adjust altitude of the border
    -- TODO: Handle mesh offset. The fog_border (mesh Ex_GG_fence_s_02.nif) appears to have 24,5 units of offset in Y directoon from it's spawn point
    -- rotate for 180 degrees on Y axis so the the straight edge replaces the curved edge
    testBR.PlaceObject("fog_border", host_cell_string, x_coordinate, y_coordinate, 4200, 0, 3.14159, rotation, 2.677, trackedObjects["cellBorderObjects"])

end

-- sets border at cell edge if given true
testBR.PlaceCellBorders = function(cell_x, cell_y, top, bottom, left, right)
    if top then
        testBR.PlaceBorderBetweenCells(cell_x, cell_y, cell_x, cell_y+1)
    end
    if bottom then
        testBR.PlaceBorderBetweenCells(cell_x, cell_y, cell_x, cell_y-1)
    end
    if left then
        testBR.PlaceBorderBetweenCells(cell_x, cell_y, cell_x-1, cell_y)
    end
    if right then
        testBR.PlaceBorderBetweenCells(cell_x, cell_y, cell_x+1, cell_y)
    end
end

testBR.SpawnLoot = function()
    
    for _, entry in pairs(lootSpawnLocations) do
        -- adjusted for X, Z, Y
        testBR.SpawnLootAroundPosition(entry[1], entry[2], entry[4], entry[3], 0)
    end
end

testBR.SpawnLootAroundPosition = function(cell, x, y, z, rot_z)

    local amount_of_loot = math.random(4,8)
    local spacing = 50
    local x_offset = 0
    local y_offset = 0
    for i=1,amount_of_loot do
        local object_id = testBR.GetRandomLoot()
        testBR.SpawnItem(object_id, cell, x+x_offset*spacing, y+y_offset*spacing, z+10, 0, 0, rot_z, 1)
        x_offset = x_offset + 1
        if x_offset > 3 then
            x_offset = 0
            y_offset = y_offset + 1
        end
    end
end

-- TODO: fix this abomination, make it account for empty tables
testBR.GetRandomLoot = function(loot_type, loot_tier)
    if not loot_type then
        -- lol I'm sorry, I thought this was a decent programming language
        -- I miss Python
        --loot_type = math.random(#lootTables)
        loot_types = {"armor", "weapons", "potions", "scrolls", "ingredients"}
        loot_type = loot_types[math.random(1,5)]
    end

    if not loot_tier then
        DebugLog(3, "loot_type: " .. tostring(loot_type))
        loot_tier = math.random(1,#lootTables[loot_type])
    end
    
    return lootTables[loot_type][loot_tier][math.random(#lootTables[loot_type][loot_tier])]
end

testBR.SpawnItem = function(object_id, cell, x, y, z, rot_x, rot_y, rot_z, scale)

    testBR.PlaceObject(object_id, cell, x, y, z, rot_x, rot_y, rot_z, scale, trackedObjects["spawnedItems"])

end


-- starts a new match proposal
testBR.StartMatchProposal = function()
    DebugLog(3, "Running StartMatchProposal function")
    -- check if there are at least 2 players on server and that there is no other match proposal already in progress
    -- Apparently at this stage the #Players shows 0 after 1 player is online and 1 once second players is online
    -- So instead of trying to figure out why this is so, we will just shift things for 1, replacing 1 with 0
    if #Players > 0 and not matchInProgress and not matchProposalInProgress then
        tes3mp.LogMessage(2, "Proposing a start of a new match")
        tes3mp.SendMessage(0, "New match is being proposed. Type " .. color.Yellow .. "/ready" .. color.White .. " in the next " .. tostring(matchProposalTime) .. " seconds in order to join.\n", true)
	    matchProposalInProgress = true
        readyList = {}
	    matchProposalTimer = tes3mp.CreateTimerEx("EndMatchProposal", time.seconds(matchProposalTime), "i", 1)
	    tes3mp.StartTimer(matchProposalTimer)
    else
        DebugLog(3, "#Players: " .. tostring(#Players) .. ", matchInProgress: " .. tostring(matchInProgress) .. ", matchProposalInProgress" .. tostring(matchProposalInProgress))
        reasonMessage = "Something went horribly wrong on the server. This should NEVER happen. Go yell at testman\n"
        if #Players <= 0 then
            tes3mp.LogMessage(2, "Not enough players to start match proposal")
            reasonMessage = "New match proposal was not started because there are not enough players on the server.\n"
        elseif matchInProgress then
            tes3mp.LogMessage(2, "Match in progress, won't start proposal for new one")
            reasonMessage = "New match proposal was not started because the match is currently in progress.\n"
        elseif matchProposalInProgress then
            tes3mp.LogMessage(2, "Match proposal already in process")
            reasonMessage = "New match proposal was not started because one is already in progress.\n"
        end
        if #Players > 0 then
            tes3mp.SendMessage(0, reasonMessage, true)
        end
    end
end

-- set the damage level for player at cell transition
-- TODO: make it so that damage level doesn't get cleared and re-applied on every cell transition
testBR.UpdateDamageLevel = function(pid)
	tes3mp.LogMessage(2, "Updating damage level for PID " .. tostring(pid))
    -- playerCel = Players[pid].data.location.cell
	playerCell = tes3mp.GetCell(pid)
	DebugLog(3, "playerCell for PID " .. tostring(pid) .. ": " .. tostring(playerCell))
    

    -- sanity check
    if not testBR.IsCellExternal(playerCell) then
        tes3mp.LogMessage(2, tostring(playerCell) .. " is not external cell and therefore can't have damage level.")
        return false
    end

	newDamageLevel = testBR.CheckCellDamageLevel(playerCell)

    DebugMessage(3, pid, "cell: " .. playerCell .. " dl: " .. tostring(newDamageLevel) .. "\n")
	
	if not newDamageLevel then
		testBR.SetFogDamageLevel(pid, 0)
    else
        testBR.SetFogDamageLevel(pid, newDamageLevel)
	end
end


testBR.CheckCellDamageLevel = function(cell)
	tes3mp.LogMessage(2, "Checking damage level for cell " .. tostring(cell))

    damageLevel = 0

    -- sanity check
    if not testBR.IsCellExternal(cell) then
        tes3mp.LogMessage(2, tostring(cell) .. " is not external cell and therefore can't have damage level.")
        return 0
    end
    
	-- danke StackOverflow
	--x, y = playerCell:match("([^,]+),([^,]+)")
	x, y = cell:match("([^,]+),([^,]+)")

	for level=1,#fogGridLimits do
		DebugLog(2, "GetCurrentDamageLevel: " .. tostring(testBR.GetCurrentDamageLevel(level)))
		DebugLog(3, "x is number: " .. tostring(tonumber(x)))
		DebugLog(3, "y is number: " .. tostring(tonumber(y)))
		DebugLog(3, "cell only in level: " .. tostring(testBR.IsCellOnlyInZone({tonumber(x), tonumber(y)}, level)))
		if tonumber(testBR.GetCurrentDamageLevel(level)) and tonumber(x) and tonumber(y)
        and testBR.IsCellOnlyInZone({tonumber(x), tonumber(y)}, level) then
            damageLevel = testBR.GetCurrentDamageLevel(level)
			DebugLog(2, "Damage level for cell " .. tostring(cell) .. " is set to " .. tostring(damageLevel))
			break
		end
	end
	
	return damageLevel
end

-- Start the process of decreasing safe area
testBR.StartFogShrink = function()
    fogGridLimits = testBR.GenerateFogGrid(fogZoneSizes)
    DebugLog(2, "fogGridLimits is an array with " .. tostring(#fogGridLimits) .. " elements")

	currentFogStage = 1

    testBR.StartFogTimerForStage(currentFogStage)
end

testBR.StartFogTimerForStage = function(stage)
	tes3mp.LogMessage(2, "Setting shrink timer for stage" .. tostring(stage))
	testBR.StartFogTimer(fogStageDurations[stage])
end

testBR.StartFogTimer = function(delay)
	tes3mp.LogMessage(2, "Setting shrink timer to " .. tostring(delay) .. " seconds")
    -- sanity check
    -- TODO: figure out why delay can be nil
    if delay then
	    tes3mp.SendMessage(0,fogName .. " will be shrinking in " .. tostring(delay) .. " seconds.\n", true)
	    fogTimer = tes3mp.CreateTimerEx("AdvanceFog", time.seconds(delay), "i", 1)
	    tes3mp.StartTimer(fogTimer)
    end
end

-- start a timer 
testBR.StartShrinkAlertTimer = function(stage)
	tes3mp.LogMessage(2, "Setting shrink timer alert for fog stage" .. tostring(stage))
    fogShrinkRemainingTime = 0
    if stage <= #fogStageDurations then
		testBR.StartFogTimer(fogStageDurations[stage])
		if fogStageDurations[stage] > 60 then
			fogShrinkRemainingTime = fogStageDurations[stage] - 60
		else
			fogShrinkRemainingTime = fogStageDurations[stage]
		end
		-- TODO: make this actually work before enabling it
		--testBR.StartShrinkAlertTimer(fogShrinkRemainingTime)
		testBR.StartShrinkAlertTimer(fogShrinkRemainingTime)
	end
	shrinkAlertTimer = tes3mp.CreateTimerEx("HandleShrinkTimerAlertTimeout", time.seconds(fogStageDurations[stage]), "i", 1)
	tes3mp.StartTimer(shrinkAlertTimer)
end

-- returns a list of squares that are to be used for fog levels
-- for example: { {{10, 0}, {0, 10}}, {{5, 5}, {5, 5}}, {} }
testBR.GenerateFogGrid = function(fogZoneSizes)	
	tes3mp.LogMessage(2, "Generating fog grid")
	generatedFogGrid = {}

	for level=1,#fogZoneSizes do
		tes3mp.LogMessage(2, "Generating level " .. tostring(level))
		generatedFogGrid[level] = {}
		
		-- handle the first item in the array (double check just to be sure)
		--if type(fogZoneSizes[level]) ~= "number" and fogZoneSizes[level] = "all" then
		-- or lol, we can just check if this is first time going through the loop
		-- this does assume that config is not messed up, that first entry is meant to be whole area
		if level == 1 then
			table.insert(generatedFogGrid[level], {mapBorders[1][1], mapBorders[1][2]})
			table.insert(generatedFogGrid[level], {mapBorders[2][1], mapBorders[2][2]})
		else
			-- check out some stuff about previous level
			xIncludesZero = 0
			yIncludesZero = 0
			-- check if min X and max X are both positive or both negative
			-- because if they are not, it means that one of cells in X range is also {0, y}, which must be counted in the length as well
			if DoNumbersHaveSameSign(generatedFogGrid[level-1][1][1], generatedFogGrid[level-1][2][1]) then
				xIncludesZero = 1
			end
			-- same for Y
			if DoNumbersHaveSameSign(generatedFogGrid[level-1][1][2], generatedFogGrid[level-1][2][2]) then
				yIncludesZero = 1
			end

			previousXLength = math.abs(generatedFogGrid[level-1][1][1]) + math.abs(generatedFogGrid[level-1][2][1]) + xIncludesZero
			previousYLength = math.abs(generatedFogGrid[level-1][1][2]) + math.abs(generatedFogGrid[level-1][2][2]) + yIncludesZero

			-- figure out if there is space for next level
			-- -1 because we are checking if new size fits into a square that is one cell smaller from both sides
			if fogZoneSizes[level] < previousXLength - 1 and fogZoneSizes[level] < previousYLength - 1 then
				-- all right, looks like it will fit
				-- now we can even try to add "border" that is one cell wide, so that edges of previous level and new level don't touch
				cellBorder = 0
				if fogZoneSizes[level] < previousXLength - 2 and fogZoneSizes[level] < previousYLength - 2 then
					DebugLog(2, "Level " .. tostring(level) .. " can get a cell-wide border")
					cellBorder = 1
				end
			
			-- this gives available area for the whole level
			-- {minX, maxX}
			availableVerticalArea = {generatedFogGrid[level-1][1][1] + 1 + cellBorder, generatedFogGrid[level-1][2][1] - 1 - cellBorder}
			-- {minY, maxY}
			availableHorisontalArea = {generatedFogGrid[level-1][1][2] + 1 + cellBorder, generatedFogGrid[level-1][2][2] - 1 - cellBorder}

			-- but now we need to determine what is the available area for the bottom left cell from which the whole level will be extrapolated from
			-- we leave minX as it is, but we subtract level size from the maxX
			availableCornerAreaX = {availableVerticalArea[1], availableVerticalArea[2] - fogZoneSizes[level]}
			-- same for Y
			availableCornerAreaY = {availableHorisontalArea[1], availableHorisontalArea[2] - fogZoneSizes[level]}
			
			-- choose random cell in the available area
			newX = math.random(availableCornerAreaX[1],availableCornerAreaX[2])
			newY = math.random(availableCornerAreaY[1],availableCornerAreaY[2])
			
			-- save bottom left corner
			table.insert(generatedFogGrid[level], {newX, newY})
			-- save top right corner
			table.insert(generatedFogGrid[level], {newX + fogZoneSizes[level], newY + fogZoneSizes[level]})
			DebugLog(2, "" .. tostring(level) .. " goes from " .. tostring(newX) .. ", " .. tostring(newY) .. " to " ..
				tostring(newX + fogZoneSizes[level]) .. ", " .. tostring(newY + fogZoneSizes[level]))
			-- lol no place to add the level. Who made this config?
			else
				tes3mp.LogMessage(2, "Given level size does not fit into previous level, skipping this one")
				-- TODO: lol this will actually break, since this for loop does not account for missing data
				-- so just don't make bad configs until this gets implemented :^^^^)
			end
		end
	end

	return generatedFogGrid
end

-- Send new world-map tiles to players
testBR.UpdateMap = function()
	tes3mp.LogMessage(2, "Updating map to fog level " .. tostring(currentFogStage))
	tes3mp.ClearMapChanges()

	for zoneIndex=1,#fogGridLimits do
        testBR.UpdateMapZone(zoneIndex)
	end
end

-- Load map tiles for specific zone
testBR.UpdateMapZone = function(zone)
    DebugLog(2, "Updating map level" .. tostring(zone))

    for x=fogGridLimits[zone][1][1],fogGridLimits[zone][2][1] do
	    for y=fogGridLimits[zone][1][2],fogGridLimits[zone][2][2] do
            if not fogGridLimits[zone+1] or (fogGridLimits[zone+1] and not testBR.IsCellInZone({x, y}, zone+1)) then
			    tes3mp.LoadMapTileImageFile(x, y, fogFilePaths[currentFogStage - zone])
		    end
        end
    end
end

testBR.UpdateZoneBorder = function()
    
    --DebugLog(2, "moving " .. tostring(#cellBorderObjects) .. " objects to previousCellBorderObjects")
    --for i=1,#cellBorderObjects do
    --    table.insert(previousCellBorderObjects, cellBorderObjects[1])
    --end
    --cellBorderObjects = {}

    -- top / north and bottom / south border
    -- iterate over x, place border above max_y and below min_y
    -- -1 so that border goes between fogwarn and fog1, instead of in front of fogwarn
    if currentFogStage > 1 and fogGridLimits[currentFogStage-1] then

        -- this would ideally happen after the new border was placed, but it would require some variable juggling
        testBR.RemovePreviousBorder()

        for x=fogGridLimits[currentFogStage-1][1][1],fogGridLimits[currentFogStage-1][2][1] do
            testBR.PlaceCellBorders(x, fogGridLimits[currentFogStage-1][2][2], true, false, false, false)
            testBR.PlaceCellBorders(x, fogGridLimits[currentFogStage-1][1][2], false, true, false, false)
        end

        -- left / west and right / east border
        -- iterate over y, place border on right of max_x and left of min_x
        for y=fogGridLimits[currentFogStage-1][1][2],fogGridLimits[currentFogStage-1][2][2] do
            testBR.PlaceCellBorders(fogGridLimits[currentFogStage-1][2][1], y, false, false, false, true)
            testBR.PlaceCellBorders(fogGridLimits[currentFogStage-1][1][1], y, false, false, true, false)
        end
    end
    
end

testBR.RemovePreviousBorder = function()

    
    --DebugLog(2, "currentFogStage:" .. tostring(currentFogStage))
    --DebugLog(2, "table length:" .. tostring(#previousCellBorderObjects))
    --DebugLog(2, "to delete: " .. tostring(previousCellBorderObjects[1][2]))
    --DebugLog(2, "in cell: " .. tostring(previousCellBorderObjects[1][1]))
    --for i=1,#previousCellBorderObjects do
    --    DebugLog(2, "deleting: " .. tostring(previousCellBorderObjects[currentFogStage][i][2]) .. " from cell " .. tostring(previousCellBorderObjects[currentFogStage][i][1]) )
    --    logicHandler.DeleteObjectForEveryone(previousCellBorderObjects[currentFogStage][i][1], previousCellBorderObjects[currentFogStage][i][2])
    --end
    -- reset this as well
    --previousCellBorderObjects = {}
    if #trackedObjects["cellBorderObjects"] > 0 then
        for i=1,#trackedObjects["cellBorderObjects"] do
            --DebugLog(2, "deleting: " .. tostring(previousCellBorderObjects[currentFogStage][i][2]) .. " from cell " .. tostring(previousCellBorderObjects[currentFogStage][i][1]) )
            --logicHandler.DeleteObjectForEveryone(cellBorderObjects[i][1], cellBorderObjects[i][2])
            testBR.DeleteObject(trackedObjects["cellBorderObjects"][i][1], trackedObjects["cellBorderObjects"][i][2])
        end
    end
    
end

-- replace the current zone-marking tiles with the normal (vanilla) ones
testBR.ResetMapTiles = function()
	tes3mp.LogMessage(2, "Resetting map tiles")
	tes3mp.ClearMapChanges()

	for x=mapBorders[1][1],mapBorders[2][1] do
	    for y=mapBorders[1][2],mapBorders[2][2] do
            DebugLog(4, "Refreshing tile " .. x .. ", " .. y )
            filePath = tes3mp.GetDataPath() .. "/map/" .. x .. ", " .. y .. ".png"
            tes3mp.LoadMapTileImageFile(x, y, filePath)
        end
    end
end

-- Returns the value that is used to determine how much damage the cells in that zone currently deal
-- zone is index in array
testBR.GetCurrentDamageLevel = function(zone)
	tes3mp.LogMessage(2, "Looking up damage level for zone " .. tostring(zone))
	if currentFogStage - zone > #fogDamageValues then
		return fogDamageValues[#fogDamageValues]
	else
		return fogDamageValues[currentFogStage - zone]
	end
end

-- Start the first stage of the air-drop process
testBR.StartAirdrop	= function()
    DebugLog(2, "Starting airdrop")
    airmode = 2
	testBR.HandleAirMode()
    -- inform all players about the duration of fast movement
    tes3mp.SendMessage(playerList[1], "You have " .. airDropStageTimes[2] .. " seconds of speed boost.\n", true)
end

-- make effects get applied to players and set timer if needed
testBR.HandleAirMode = function()
    DebugLog(2, "Handling air mode. Current airmode = " .. tostring(airmode))

    for _, pid in pairs(playerList) do
        if Players[pid]:IsLoggedIn() then
            testBR.SetAirMode(pid, airmode)
        end
    end
    
	airmode = airmode - 1

    -- If needed, set timer for next air mode handling
	if airmode >= 0 then
        DebugLog(2, "Setting airTimer")
        airTimer = tes3mp.CreateTimerEx("HandleAirTimerTimeout", time.seconds(airDropStageTimes[airmode+1]), "i", 1)
		tes3mp.StartTimer(airTimer)
	end
end

-- check if player is last one
-- this can be modified in case teams get implemented
testBR.CheckVictoryConditions = function()
    tes3mp.LogMessage(2, "Checking if victory conditions are met")
    DebugLog(3, "#playerList: " .. tostring(#playerList))
	if #playerList == 1 then
		tes3mp.SendMessage(playerList[1], color.Yellow .. Players[playerList[1]].data.login.name .. " has won the match\n", true)
        tes3mp.MessageBox(playerList[1], -1, "Winner winner CHIM for dinner")
		Players[playerList[1]].data.BRinfo.wins = Players[playerList[1]].data.BRinfo.wins + 1
		Players[playerList[1]]:Save()
        testBR.EndMatch()
	end
end

-- check if cell is used for lobby
testBR.IsCellLobby = function(cell)
    DebugLog(3, "Checking if " .. tostring(cell) .. " is lobby.")
    if cell == lobbyCell then
		return true
	end
    return false
end

-- check if cell is external
testBR.IsCellExternal = function(cell)
    DebugLog(2, "Checking if the cell (" .. cell .. ") is external.")
	_, _, cellX, cellY = string.find(cell, patterns.exteriorCell)
    DebugLog(3, "cellX: " .. tostring(cellX) .. ", cellY: " .. tostring(cellY))
    if cellX == nil or cellY == nil then
        return false
    end
    return true
end

-- returns true if cell is within the zone
testBR.IsCellInZone = function(cell, zone)
	DebugLog(4, "Checking if " .. tostring(cell[1]) .. ", " .. tostring(cell[2]) .. " is in zone " .. tostring(zone))
	-- check if cell within zone limits
	if fogGridLimits[zone] and testBR.IsCellInRange(cell, fogGridLimits[zone][1], fogGridLimits[zone][2]) then
		return true
	end
	return false
end

-- basically same function as above, only with added exclusivity check
-- returns true if cell is part of zone
-- TODO: make this by implementing an "isExclusive" argument instead of having two seperate functions
testBR.IsCellOnlyInZone = function(cell, zone)
	DebugLog(2, "Checking if " .. tostring(cell[1]) .. ", " .. tostring(cell[2]) .. " is only in zone " .. tostring(zone))

    if testBR.IsCellInZone(cell, zone) then
        if testBR.IsCellInZone(cell, zone+1) then
            return false
        end
        return true
    end
    return false
end

-- returns true if cell is inside the rectangle defined by given coordinates
testBR.IsCellInRange = function(cell, topRight, bottomLeft)
	DebugLog(4, "Checking if " .. tostring(cell[1]) .. ", " .. tostring(cell[2]) .. " is inside the "
		 .. tostring(topRight[1]) .. ", " .. tostring(topRight[2]) .. " - " .. tostring(bottomLeft[1]) .. ", " .. tostring(bottomLeft[2]) .. " rectangle")
	if cell[1] >= topRight[1] and cell[1] <= bottomLeft[1] and cell[2] >= topRight[2] and cell[2] <= bottomLeft[2] then
		return true
	end
	return false
end

-- get coordinates of all corners for given cell
testBR.getCellCorners = function(cell_x, cell_y)
    -- lowest x value
    local min_x = cell_x * 8192
    -- lowest y value
    local min_y = cell_y * 8192
    -- highest x value
    local max_x = cell_x * 8192 + 8192
    -- highest y value
    local max_y = cell_y * 8192 + 8192

    -- bottom left
    local bl = { min_x, min_y }
    -- bottom right
    local br = { min_x, max_y }
    -- top left
    local tl = { max_x, min_y}
    -- top right
    local tr = { max_x, max_y}
    local corners = { bl, br, tl, tr}
    return corners
end

-- Restore cells to their initial state
testBR.ResetCells = function()
    -- TODO: increase this in order to ensure that no changes persist after match has ended
    for x=-20,40 do
	    for y=-20,40 do
            testBR.resetCell(tostring(x) .. tostring(y))
        end
    end
end

-- literally stolen from https://github.com/tes3mp-scripts/CellReset/blob/master/main.lua#L99
-- TODO: does not seem to be working, remove
testBR.resetCell = function(cellDescription)
    local cell = Cell(cellDescription)
    local cellFilePath = tes3mp.GetModDir() .. "/cell/" .. cell.entryFile
    
    if tes3mp.DoesFileExist(cellFilePath) then
        cell:LoadFromDrive()

        for record_type, links in pairs(cell.data.recordLinks) do
            local recordStore = RecordStores[record_type]
            for refId, objects in pairs(links) do
                recordStore:RemoveLinkToCell(refId, cell)
            end
        end

        cell = Cell(cellDescription)
        cell:SaveToDrive()
    end

    --CellReset.data.cells[cellDescription] = nil
end

-- ====================== MATCH DEBUG FUNCTIONS ======================

-- debug function
testBR.QuickStart = function()
    DebugLog(2, "Doing QuickStart")
	if debugLevel > 0 then
        for pid, player in pairs(Players) do
            if Players[pid]:IsLoggedIn() then
                testBR.PlayerConfirmParticipation(pid)
            end
        end		
		testBR.StartMatch()
	end
end

-- Administrative function to forcefully end match
testBR.AdminEndMatch = function(pid)
	if Players[pid]:IsAdmin() then
		testBR.EndMatch()
	end
end

-- force the next stage of shrinking process regardless of the remaining time
testBR.ForceNextFog = function(pid)
	if #fogStageDurations >= currentFogStage + 1 then
		AdvanceFog()
	end
end

-- used to manually clear map
testBR.FillMapTiles = function(pid)
    if debugLevel > 0 then
        testBR.ResetMapTiles()
        testBR.SendMapToPlayer(pid)
    end
end

-- ====================== MISC UTILITY USED ONLY ONCE FUNCTION ======================

-- NOPE: this didn't even work well, it produced bad tiles or missed them completely
-- actual tiles were then generated by manually moving across all cells in game

-- this makes player move through mosts of the external cells automatically
-- it's just a lefover, but I left it here for archiving purposes
-- values for x and y and multipliers are far from optinally configured
-- meaning that player can go through same set of cells more than once
-- I ran this in background while doing other productive stuff

-- testBR.GenerateMapTiles = function(pid)
-- 	tes3mp.LogMessage(2, "Spawning player " .. tostring(pid))
--     if debugLevel > 0 and Players[pid]:IsAdmin() then
--         for x=-20,40 do
--             for y=-20,40 do
--                 if Players[pid]:IsLoggedIn() then
-- 		            tes3mp.LogMessage(2, "Spawning player " .. tostring(pid) .. " at " .. tostring(random_x) .. ", " .. tostring(random_y))
-- 		            spawnPoint = {"1, 1", x*4500, y*6000, 40000, 0}
-- 
--                     tes3mp.SetCell(pid, spawnPoint[1])
--                     tes3mp.SendCell(pid)
--                     tes3mp.SetPos(pid, spawnPoint[2], spawnPoint[3], spawnPoint[4])
--                     tes3mp.SetRot(pid, 0, spawnPoint[5])
--                     tes3mp.SendPos(pid)
--                     -- so that client has time to load cell, generate image and send it to server
--                     -- works on on operating systems where "sleep" is a valid command
--                     os.execute("sleep 0.5")
--                 else
--                     return 0       
--                 end
--             end
--         end
--     end
-- end

-- ====================== PLAYER-RELATED FUNCTIONS ======================

-- Set up all the things that player needs at the start of the match
testBR.PlayerInit = function(pid)
	tes3mp.LogMessage(2, "Starting initial setup for PID " .. tostring(pid))
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() and IsInList(pid, playerList) then

		testBR.ResetCharacter(pid)

		testBR.SpawnPlayer(pid)

		testBR.PlayerSpells(pid)

		testBR.PlayerItems(pid)

		testBR.SetFogDamageLevel(pid, 0)
	end
end

-- Manage the spells and effects for player
testBR.PlayerSpells = function(pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		Players[pid].data.spellbook = {}
		command = "player->addspell feather_power"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
		command = "player->addspell restore_fatigue_power"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	end
end

-- Manage items that player has
testBR.PlayerItems = function(pid)

    -- testBR.seeIfPlayerDeservesAnyNewItems(pid)
    
	testBR.LoadPlayerItems(pid)

end

-- save changes and make items appear on player
testBR.LoadPlayerItems = function(pid)
	tes3mp.LogMessage(2, "Loading items for " .. tostring(pid))
    testBR.LoadPlayerOutfit(pid)
	Players[pid]:Save()
	Players[pid]:LoadInventory()
	Players[pid]:LoadEquipment()
end

-- load player's clothes
testBR.LoadPlayerOutfit = function(pid)
    tes3mp.LogMessage(2, "Loading outfit for " .. tostring(pid))
    -- TODO: consider making a check for the existance of required data
    -- for now just assume that testBR.VerifyPlayerData did it's thing fine
    --Players[pid].data.BRinfo.BROutfit

    playerRace = string.lower(Players[pid].data.character.race)
    -- give shoes
    if (playerRace ~= "argonian") and (playerRace ~= "khajiit") then
	    Players[pid].data.equipment[7] = { refId = "common_shoes_01", count = 1, charge = -1 }
    end
    -- give shirt
	Players[pid].data.equipment[8] = { refId = "common_shirt_01", count = 1, charge = -1 }
    -- give pants
	Players[pid].data.equipment[9] = { refId = "common_pants_01", count = 1, charge = -1 }
end

--testBR.PlayerJoin = function(pid)
--	tes3mp.LogMessage(2, "Setting state for "  .. tostring(pid))
--	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
--        table.insert(playerList, pid)
--	end
--	tes3mp.SendMessage(pid, color.Yellow .. "Noice. Now you can either propose new match with /newmatch or do /ready when new match is being suggested .\n", false)
--end

-- Used by players to start a new match proposal
testBR.PlayerStartMatchProposal = function(pid)
    if pid ~= nil then
        tes3mp.SendMessage(pid, "New match will start if all participants are ready. Type " .. color.Yellow .. " /ready" .. color.White .. " to confirm.\n", true)
        testBR.StartMatchProposal()
        -- if match proposal started then mark the player who started the proposal as first participant
        if matchProposalInProgress then
            testBR.PlayerConfirmParticipation(pid)
        end
    end
end

-- Used by players to enlist themselves as participants in the next match
testBR.PlayerConfirmParticipation = function(pid)
	--if matchProposalInProgress and Players[pid] ~= nil and Players[pid]:IsLoggedIn() then IsInList(pid, playerList) then
    -- TODO: figure out proper criteria for this
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() and not IsInList(pid, readyList) and not matchInProgress then
        table.insert(readyList, pid)
		tes3mp.SendMessage(pid, color.Yellow .. Players[pid].data.login.name .. " is ready.\n", true)
	end
end

-- set airborne-related effects
-- 1 = just slowfall
-- 2 = slowfall and speed boost
testBR.SetAirMode = function(pid, mode)
	DebugLog(2, "Setting air mode to " .. tostring(mode) .. " for PID " .. tostring(pid))
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		if mode == 2 then
			testBR.SetSlowFall(pid, true)
			Players[pid].data.attributes["Speed"].base = 3000
		elseif mode == 1 then
			testBR.SetSlowFall(pid, true)
			-- TODO: make this restore the proper value
			Players[pid].data.attributes["Speed"].base = defaultStats.playerSpeed
		else 
			testBR.SetSlowFall(pid, false)
		end

		Players[pid]:Save()
		Players[pid]:LoadAttributes()
	end
end

-- either enables or disables slowfall for player
-- this part assumes that there is a proper entry for slowfall_power in recordstore
testBR.SetSlowFall = function(pid, boolean)
	tes3mp.LogMessage(2, "Setting slowfall mode for PID " .. tostring(pid))
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		if boolean then
			command = "player->addspell slowfall_power"
		else
			command = "player->removespell slowfall_power"
		end
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	end
end


testBR.ProcessCellChange = function(pid)
	tes3mp.LogMessage(2, "Processing cell change for PID " .. tostring(pid))
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() and IsInList(pid, playerList) then
		-- TODO: lol I have no idea how to properly re-paint a tile after player "discovered it"
		--tes3mp.SendWorldMap(pid)
		Players[pid]:SaveStatsDynamic()
		--Players[pid]:Save()
        testBR.UpdateDamageLevel(pid)
	end
end

-- Set's player position 
testBR.SpawnPlayer = function(pid, spawnInLobby)
	tes3mp.LogMessage(2, "Spawning player " .. tostring(pid))
	if spawnInLobby then
		chosenSpawnPoint = {lobbyCell, lobbyCoordinates[1], lobbyCoordinates[2], lobbyCoordinates[3], 0}
        testBR.ResetCharacter(pid)
        testBR.LoadPlayerItems(pid)
	else
		-- TEST: use random spawn point for now
		random_x = math.random(-40000,80000)
		random_y = math.random(-40000,120000)
		tes3mp.LogMessage(2, "Spawning player " .. tostring(pid) .. " at " .. tostring(random_x) .. ", " .. tostring(random_y))
		chosenSpawnPoint = {"1, 1", random_x, random_y, 40000, 0}
	end

	tes3mp.SetCell(pid, chosenSpawnPoint[1])
	tes3mp.SendCell(pid)
	tes3mp.SetPos(pid, chosenSpawnPoint[2], chosenSpawnPoint[3], chosenSpawnPoint[4])
	tes3mp.SetRot(pid, 0, chosenSpawnPoint[5])
	tes3mp.SendPos(pid)
end

-- Have player drop all items when they get killed while in match
testBR.DropAllItems = function(pid)
	tes3mp.LogMessage(2, "Dropping all items for PID " .. tostring(pid))

	--mpNum = WorldInstance:GetCurrentMpNum() + 1
	z_offset = 5

	--for index, item in pairs(Players[pid].data.inventory) do
	inventoryLength = #Players[pid].data.inventory
	if inventoryLength > 0 then
		for index=1,inventoryLength do
			testBR.DropItem(pid, index, z_offset)
			z_offset = z_offset + 5
		end
	end
	Players[pid].data.inventory = {}
	Players[pid]:Save()
end

testBR.DropItem = function(pid, index, z_offset)
	
	local player = Players[pid]
	
	local item = player.data.inventory[index]
	
    if item then

        local cell = tes3mp.GetCell(pid)

        local location = {
		    posX = tes3mp.GetPosX(pid), posY = tes3mp.GetPosY(pid), posZ = tes3mp.GetPosZ(pid) + z_offset,
		    rotX = tes3mp.GetRotX(pid), rotY = 0, rotZ = tes3mp.GetRotZ(pid)
	    }
        local itemref = {refId = item.refId, count = item.count, charge = item.charge }

        testBR.PlaceObject(item.refId, cell, location.posX, location.posY, location.posZ, location.rotY, location.rotY, location.rotZ, 1, trackedObjects["droppedItems"])
    end
    
end

-- inspired by code from from David-AW (https://github.com/David-AW/tes3mp-safezone-dropitems/blob/master/deathdrop.lua#L134)
-- and from rickoff (https://github.com/rickoff/Tes3mp-Ecarlate-Script/blob/0.7.0/DeathDrop/DeathDrop.lua
testBR.DropItem_old = function(pid, index, z_offset)
		
	local player = Players[pid]
	
	local item = player.data.inventory[index]
		
	local mpNum = WorldInstance:GetCurrentMpNum() + 1
	local cell = tes3mp.GetCell(pid)
	local location = {
		posX = tes3mp.GetPosX(pid), posY = tes3mp.GetPosY(pid), posZ = tes3mp.GetPosZ(pid) + z_offset,
		rotX = tes3mp.GetRotX(pid), rotY = 0, rotZ = tes3mp.GetRotZ(pid)
	}
	local refId = item.refId
	local refIndex =  0 .. "-" .. mpNum
	local itemref = {refId = item.refId, count = item.count, charge = item.charge }
	Players[pid]:Save()
	DebugLog(2, "Removing item " .. tostring(item.refId))
	Players[pid]:LoadItemChanges({itemref}, enumerations.inventory.REMOVE)	
	
	WorldInstance:SetCurrentMpNum(mpNum)
	tes3mp.SetCurrentMpNum(mpNum)

	LoadedCells[cell]:InitializeObjectData(refIndex, refId)
	LoadedCells[cell].data.objectData[refIndex].location = location			
	table.insert(LoadedCells[cell].data.packets.place, refIndex)
	DebugLog(2, "Sending data to other players")
	for onlinePid, player in pairs(Players) do
		if Players[pid]:IsLoggedIn() then
			tes3mp.InitializeEvent(onlinePid)
			tes3mp.SetEventCell(cell)
			tes3mp.SetObjectRefId(refId)
			tes3mp.SetObjectCount(item.count)
			tes3mp.SetObjectCharge(item.charge)
			tes3mp.SetObjectRefNumIndex(0)
			tes3mp.SetObjectMpNum(mpNum)
			tes3mp.SetObjectPosition(location.posX, location.posY, location.posZ)
			tes3mp.SetObjectRotation(location.rotX, location.rotY, location.rotZ)
			tes3mp.AddWorldObject()
			tes3mp.SendObjectPlace()
		end
	end
	LoadedCells[cell]:Save()
end

-- Apply given damage effect to player
testBR.SetFogDamageLevel = function(pid, level)
	tes3mp.LogMessage(2, "Setting damage level for PID " .. tostring(pid))
	if level == 0 then
		command = "player->removespell fogdamage1"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
		command = "player->removespell fogdamage2"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
		command = "player->removespell fogdamage3"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	elseif level == 1 then
		command = "player->addspell fogdamage1"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	elseif level == 2 then
		command = "player->addspell fogdamage2"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	elseif level == 3 then
		command = "player->addspell fogdamage3"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	end
end

-- Send all the new changes to world-view map to player
testBR.SendMapToPlayer = function(pid)
	tes3mp.LogMessage(2, "Sending map to PID " .. tostring(pid))
	tes3mp.SendWorldMap(pid)
end

-- TODO: why is this here? Was it for removing containers and NPCS/creatures?
testBR.OnCellLoad = function(pid)

end

-- Handle player death
testBR.ProcessDeath = function(pid)
	if IsInList(pid, playerList) then
		testBR.DropAllItems(pid)
        RemoveFromList(pid, playerList)
		testBR.CheckVictoryConditions()
	end
	testBR.SpawnPlayer(pid, true)
	testBR.SetFogDamageLevel(pid, 0)
    testBR.PlayerItems(pid)
	Players[pid]:Save()
end

-- Add battle-royale specific data to player file if it is not already present
testBR.VerifyPlayerData = function(pid)
	tes3mp.LogMessage(2, "Verifying player data for " .. tostring(Players[pid]))
	
	if Players[pid].data.BRinfo == nil then
		BRinfo = {}
		BRinfo.matchId = ""
		BRinfo.chosenSpawnPoint = nil
		BRinfo.team = 0
		BRinfo.totalKills = 0
		BRinfo.totalDeaths = 0		
		BRinfo.wins = 0
		BRinfo.BROutfit = {} -- used to hold data about player's chosen outfit
		BRinfo.secretNumber = math.random(100000,999999) -- used for verification
		Players[pid].data.BRinfo = BRinfo
		Players[pid]:Save()
	end
end

testBR.ResetCharacter = function(pid)
    testBR.ResetCharacterStats(pid)
    testBR.ResetCharacterItems(pid)
end

-- Called from local PlayerInit to reset characters for each new match
testBR.ResetCharacterStats = function(pid)
	tes3mp.LogMessage(2, "Resetting stats for " .. Players[pid].data.login.name .. ".")

	-- Reset battle royale
	Players[pid].data.BRinfo.team = 0
	
	-- Reset player level
	Players[pid].data.stats.level = defaultStats.playerLevel
	Players[pid].data.stats.levelProgress = 0
	
	-- Reset player attributes
	for name in pairs(Players[pid].data.attributes) do
		Players[pid].data.attributes[name].base = defaultStats.playerAttributes
		Players[pid].data.attributes[name].skillIncrease = 0
	end

	Players[pid].data.attributes.Speed.base = defaultStats.playerSpeed
	Players[pid].data.attributes.Luck.base = defaultStats.playerLuck
	
	-- Reset player skills
	for name in pairs(Players[pid].data.skills) do
		Players[pid].data.skills[name].base = defaultStats.playerSkills
		Players[pid].data.skills[name].progress = 0
	end

	Players[pid].data.skills.Acrobatics.base = defaultStats.playerAcrobatics
	Players[pid].data.skills.Marksman.base = defaultStats.playerMarksman

	-- Reset player stats
	Players[pid].data.stats.healthBase = defaultStats.playerHealth
	Players[pid].data.stats.healthCurrent = defaultStats.playerHealth
	Players[pid].data.stats.magickaBase = defaultStats.playerMagicka
	Players[pid].data.stats.magickaCurrent = defaultStats.playerMagicka
	Players[pid].data.stats.fatigueBase = defaultStats.playerFatigue
	Players[pid].data.stats.fatigueCurrent = defaultStats.playerFatigue

	
	--tes3mp.LogMessage(2, "Stats all reset")
	
	-- Reload player with reset information
	Players[pid]:Save()
	Players[pid]:LoadLevel()
	--tes3mp.LogMessage(2, "Player level loaded")
	Players[pid]:LoadAttributes()
	--tes3mp.LogMessage(2, "Player attributes loaded")
	Players[pid]:LoadSkills()
	--tes3mp.LogMessage(2, "Player skills loaded")
	Players[pid]:LoadStatsDynamic()
	--tes3mp.LogMessage(2, "Dynamic stats loaded")
end

testBR.ResetCharacterItems = function(pid)
    if Players[pid]:IsLoggedIn() then
        Players[pid].data.inventory = {}
        Players[pid].data.equipment = {}
	    Players[pid]:Save()
	    Players[pid]:LoadInventory()
	    Players[pid]:LoadEquipment()
    end
end

-- Handle generation of new character
testBR.EndCharGen = function(pid)
	tes3mp.LogMessage(2, "Ending character generation for " .. tostring(pid))
	Players[pid]:SaveLogin()
	Players[pid]:SaveCharacter()
	Players[pid]:SaveClass()
	Players[pid]:SaveStatsDynamic()
	Players[pid]:SaveEquipment()
	Players[pid]:SaveIpAddress()
	Players[pid]:CreateAccount()
	testBR.VerifyPlayerData(pid)
end

-- checks if player is allowed to be in the cell
testBR.validateCell = function(pid)
    
    DebugLog(2, "Checking if PID " .. tostring(pid) .. " is allowed to be in the cell.")
    
    cell = tes3mp.GetCell(pid)

	-- allow player to spawn in lobby	
	if testBR.IsCellLobby(cell) then
		return true
	end

    if not testBR.IsCellExternal(cell) then
		tes3mp.LogMessage(2, "Cell is not external and can not be entered")
		Players[pid].data.location.posX = tes3mp.GetPreviousCellPosX(pid)
		Players[pid].data.location.posY = tes3mp.GetPreviousCellPosY(pid)
		Players[pid].data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
        Players[pid]:LoadCell()
        return false
    end
    
    return true
end

customEventHooks.registerHandler("OnPlayerFinishLogin", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
        testBR.SpawnPlayer(pid, true)
        local confirmations = {"Cool", "Noice", "Awesome", "Yup", "Got it", "Makes sense", "Sounds good", "Will keep that in mind", "Bottom text", "Just let me in", "Dagoth Ur did nothing wrong"}
        tes3mp.CustomMessageBox(pid, 1, "WARNING:\nThis is an unfinished prototype for battle royale.\n\nIt is not even remotely balanced yet.\nAnd it can crash at any moment.\nIf it does, the server will automatically restart.\n\nStill, feel free to provide feedback by opening an issue in the tes3mp-battle-royale GitLab (or GitHub) repository.\n\nType" .. , confirmations[math.random(1,11)])
		testBR.VerifyPlayerData(pid)
        -- check if player count is high enough to start automatic process
        if automaticMatchmaking then
            testBR.StartMatchProposal()
        end
	end
end)

customEventHooks.registerHandler("OnPlayerDisconnect", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
        if IsInList(pid, playerList) then
		    RemoveFromList(pid, playerList)
		    testBR.CheckVictoryConditions(pid)
        end
	end
end)

customEventHooks.registerHandler("OnPlayerDeath", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.ProcessDeath(pid)
	end
end)

customEventHooks.registerHandler("OnCellLoad", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.OnCellLoad(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerCellChange", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.ProcessCellChange(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerEndCharGen", function(eventstatus, pid)
	if Players[pid] ~= nil then
		tes3mp.LogMessage(2, "++++ Newly created: " .. tostring(pid))
		testBR.EndCharGen(pid)
        if automaticMatchmaking then
            testBR.StartMatchProposal()
        end
	end
end)

customEventHooks.registerHandler("OnServerPostInit", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.OnServerPostInit()
	end
end)

-- custom validator for cell change
customEventHooks.registerValidator("OnPlayerCellChange", function(eventStatus, pid)
	tes3mp.LogMessage(2, "Player " .. pid .. " trying to enter cell " .. tostring(tes3mp.GetCell(pid)))

    if testBR.validateCell(pid) then
        return customEventHooks.makeEventStatus(true,true)
    else
        return customEventHooks.makeEventStatus(false,true)
    end

end)

customCommandHooks.registerCommand("newmatch", testBR.StartMatchProposal)
customCommandHooks.registerCommand("ready", testBR.PlayerConfirmParticipation)
customCommandHooks.registerCommand("forcestart", testBR.StartMatch)
customCommandHooks.registerCommand("forcenextfog", AdvanceFog)
customCommandHooks.registerCommand("forceend", testBR.AdminEndMatch)
customCommandHooks.registerCommand("x", testBR.QuickStart)
customCommandHooks.registerCommand("generatemaptiles", testBR.GenerateMapTiles)
customCommandHooks.registerCommand("fillmap", testBR.FillMapTiles)

return testBR
