
-- Battle Royale game mode by testman
-- v0.2

-- TODO:
-- find a decent name for overall project
-- untangle all the spaghetti code
-- - A LOT OF IT
-- -- HOLY SHIT I CAN'T STRESS ENOUGH HOW MUCH FIXING AND IMPROVING THIS CODE NEEDS
-- - order functions in the order that makes sense
-- -- figure out how to make timers execute functions with given arguments instead of relying on global variables
-- figure out how the zone-shrinking logic should actually work
-- implement said decent zone-shrinking logic
-- - make shrinking take some time instead of being an instant event
-- - make zone circle-shaped (or at least blocky pixelated circle shaped)
-- make players unable to open vanilla containers
-- implement custom containers that can be opened by players
-- make players start taking damage if they are in a cell that turned into a non-safe cell
-- clear inventory
-- think about restore fatigue constant effect
-- resend map to rejoining player
-- - lolwat no, disconnecting should count the same as getting killed, and player should respawn in lobby after reconnecting
-- make sure to clear spells
-- implement hybrid playerzone shrinking system:
-- - use cell based system at the start
-- - switch to coordinates-math-distance-circle at the end
-- longer drop speed boost time
-- implement a config option that determines if server will use 2-step joining (/join and then /ready) or just one (just /ready)
-- - read: do we even want everyone on server to participate in round or do we allow them to "sit a round out"?
-- - will use a single step match creation logic for now. Figure out proper two-step match creation mechanics in this time.
-- decide on terminoligy. Is one session of battle royale called a "match" or a "round"?
-- - Renaming all to "match" for now just for consistency, can Ctrl+H it later
-- decide on what should always be part of a log and what should be just debug message
-- - properly define debug levels

--[[

=================== DESIGN DOCUMENT PART ===================

Usually I like to plan out project development, but this time I went directly into the code and I got lost very quickly in a mess of concepts.
So with this we are taking a step back and defining some things that can help make sense of this mess of a code below.

Overall logic:

players spawn in lobby (currently modified ToddTest) by default, where they can sign up for next round and wait until it starts
once round starts, players get teleported to exterior, timers for parachuting logic and also timer for fog shrinking starts.
From that point on we differentiate between players in lobby and players in game. Well, players who are in lobby stay like they were and
players who are in round get to do battle royale stuff until they get killed or round ends. After that they get flagged as out of round and 
spawn in lobby with rest of players.

fog - the thing that battle royale games have. It shrinks over time and damages players who stand in it. Most other games call it "storm" if I am not mistaken.

fogGridLimits - an array that contains the bottom left (min X and min Y) and top right (max X and max Y) for each level

fog grid - Currently used logic is square-based, but same principle could easily work for other shapes, preferably circle (https://en.wikipedia.org/wiki/Midpoint_circle_algorithm)
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

fogLevel - one set of cells. It is used to easily determine if cell that player entered should cause damage to player or not.

fogStage - basically index of fog progress

]]

-- TODO: find a decent name
testBR = {}

-- ====================== CONFIG ======================

-- print out a lot more messages about what script is doing
-- TODO: properly define debug levels
debugLevel = 3

-- how fast time passes
-- you will most likely want this to be very low in order to have skybox remain the same
--timeScale = 0.1

-- determines default time of day for maps that do not have it specified
--timeOfDay = 9

-- determines default weather
--weather = 0

-- Determines if the effects from player's chosen race get applied
--allowRacePowers = false

-- Determines if the effects from player's chosen celestial sign get applied
--allowSignPowers = false

-- Determines if it is possible to use different presets of equipment / stats 
--allowClasses = true

-- define image files for map
fogWarnFilePath = tes3mp.GetDataPath() .. "/map/fogwarn.png"
fog1FilePath = tes3mp.GetDataPath() .. "/map/fog1.png"
fog2FilePath = tes3mp.GetDataPath() .. "/map/fog2.png"
fog3FilePath = tes3mp.GetDataPath() .. "/map/fog3.png"
fogFilePaths = {fogWarnFilePath, fog1FilePath, fog2FilePath, fog3FilePath}

-- default stats for players
defaultStats = {
playerLevel = 1,
playerAttributes = 75,
playerSkills = 75,
playerHealth = 100,
playerMagicka = 100,
playerFatigue = 300,
playerLuck = 100,
playerSpeed = 75,
playerAcrobatics = 50,
playerMarksman = 150
}

-- turns out it's much easier if you don't try to combine arrays whose elements do not necesarily correspond
-- config that determines how the fog will behave 
fogLevelSizes = {"all", 20, 15, 10, 5, 3, 1}

--fogStageDurations = {6000, 3000, 240, 120, 120, 60, 60, 0}
fogStageDurations = {10, 10, 10, 10, 10, 10, 10, 10, 10, 10}

-- determines the order of how levels increase damage
fogDamageValues = {"warn", 1, 2, 3}


-- used to determine the cell span on which to use the fog logic
-- {{min_X, min_Y},{max_X, max_Y}}
mapBorders = {{-15,-15}, {25,25}}

-- list of weapons used to generate random loot
weaponList = {}

-- list of armor used to generate random loot
armorList = {}

-- determines how the process for starting the match goes
-- if false, then server periodically proposes new match and starts it if criteria is met
-- if true, then players are in control of proposing a new match
twoStepJoinProcess = false


-- how many seconds does match proposal last
matchProposalTime = 30

-- ID of the cell that is used for lobby
-- remember that this is case sensitive
lobbyCell = "ToddTest"

-- position in lobby cell where player spawns
lobbyCoordinates = {2177.776367, 653.002380, -184.874023}

-- how the shrinking zone is called in game
-- start with uppercase because it's at the start of the sentence
--fogName = "Blight storm" 
fogName = "Blizzard"

-- how long does each stage last, in seconds
-- enter values in reverse, because airmode is used as index
-- since airmode gets decreased over time, this array gets used from last value to first
-- 15 is about how much time it takes to fall from spawn to the top of Red Mountain. 
-- 30 should be enough to fall to any ground safely
-- TODO: does anyone want this to be in ascending order? We could use #airDropStageTimes - airmode + 1 to achieve this.
airDropStageTimes = {30, 15}

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

-- for warnings about time remaining until fog shrinks
fogShrinkRemainingTime = 0

-- do players use /join and then /ready or do they do just /ready
-- determines whether match proposing is automated or if players have more control over timing
twoStepMatchmaking = false

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
function IsInList(value, list)
    for index, item in ipairs(list) do
        if item == value then
            return true
        end
    end
    return false
end

-- ====================== MATCH-RELATED FUNCTIONS ======================

function EndMatchProposal()
	tes3mp.LogMessage(2, "Ending current match proposal")
	if #readyList >= #playerList then
		testBR.StartMatch()
	else
		tes3mp.SendMessage(0, "Match was not started.\n", true)
	end
	matchProposalInProgress = false
    readyList = {}
end

function HandleAirTimerTimeout()
    DebugLog(2, "AirTimer Timeout")
    testBR.HandleAirMode()
end

function HandleShrinkTimerAlertTimeout()
	for pid, player in pairs(Players) do
		if fogShrinkRemainingTime > 60 then
			tes3mp.MessageBox(pid, -1, fogName .. " shrinking in a minute!")
		else
			tes3mp.MessageBox(pid, -1, fogName .. " shrinking in " .. tostring(fogShrinkRemainingTime))
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

function AdvanceFog()
	tes3mp.SendMessage(0,fogName .. " is shrinking.\n", true)
	currentFogStage = currentFogStage + 1
	if currentFogStage <= #fogStageDurations then
		testBR.StartFogTimer(fogStageDurations[currentFogStage])
		if fogStageDurations[currentFogStage] > 60 then
			fogShrinkRemainingTime = fogStageDurations[currentFogStage] - 60
		else
			fogShrinkRemainingTime = fogStageDurations[currentFogStage]
		end
		-- TODO: make this actually work before enabling it
		--testBR.StartShrinkAlertTimer(fogShrinkRemainingTime)
		testBR.TEMP_StartShrinkAlertTimer(fogShrinkRemainingTime)
	end

	testBR.UpdateMap()

	for pid, player in pairs(Players) do
		if player ~= nil and player:IsLoggedIn() and IsInList(pid, playerList) then
			-- send new map state to player
			testBR.SendMapToPlayer(pid)
			-- apply fog effects to players in cells that are now in fog
			testBR.CheckCellDamageLevel(pid)
		end
	end
end

testBR.OnServerPostInit = function()

    if not twoStepJoinProcess then
        tes3mp.LogMessage(2, "Starting automatic match proposal" )
        testBR.StartAutomaticMatchProposal()
    end
end

--
testBR.StartMatch = function()
	matchID = os.time()
	tes3mp.LogMessage(2, "Starting a battle royale match with ID " .. tostring(matchID))

	playerList = copyTable(readyList)

    testBR.StartFogShrink()

	testBR.ResetWorld()

    DebugLog(2, "playerList has " .. tostring(#playerList) .. " PIDs in it")
	for _, pid in pairs(playerList) do
        testBR.PlayerInit(pid)
	end

    -- has to be after for loop, otherwise PlayerInit resets the initial speed given by first stage of Airdrop
    testBR.StartAirdrop()
	
end

-- TODO: implement this after implementing chests / drop-on-death
testBR.ResetWorld = function()

end

-- starts a new match proposal
-- can be started by server or by player
testBR.StartMatchProposal = function(pid)
	tes3mp.LogMessage(2, "Proposing a start of a new match")
	matchProposalInProgress = true
    readyList = {}
    if not pid ~= nil then
        tes3mp.SendMessage(pid, "New match will start if all participants are ready. Type /ready to confirm.\n", true)
    end
	matchProposalTimer = tes3mp.CreateTimerEx("EndMatchProposal", time.seconds(matchProposalTime), "i", 1)
	tes3mp.StartTimer(matchProposalTimer)
end

testBR.StartAutomaticMatchProposal = function()

end

-- set the damage level for player at cell transition
-- TODO: make it so that damage level doesn't get cleared and re-applied on every cell transition
testBR.CheckCellDamageLevel = function(pid)
	tes3mp.LogMessage(2, "Checking new cell for PID " .. tostring(pid))
	playerCell = Players[pid].data.location.cell
	DebugLog(3, "playerCell for PID " .. tostring(pid) .. ": " .. tostring(playerCell))

    -- sanity check
    if not testBR.IsCellExternal(playerCell) then
        tes3mp.LogMessage(2, tostring(playerCell) .. " is not external cell and therefore can't have damage level.")
        return false
    end
    
	-- danke StackOverflow
	x, y = playerCell:match("([^,]+),([^,]+)")

	foundLevel = false

	for level=1,#fogGridLimits do
		DebugLog(2, "GetCurrentDamageLevel: " .. tostring(testBR.GetCurrentDamageLevel(level)))
		DebugLog(3, "x == number: " .. tostring(type(tonumber(x)) == "number"))
		DebugLog(3, "y == number: " .. tostring(type(tonumber(y)) == "number"))
		DebugLog(3, "cell only in level: " .. tostring(testBR.IsCellOnlyInLevel({tonumber(x), tonumber(y)}, level)))
		if type(testBR.GetCurrentDamageLevel(level)) == "number" and type(tonumber(x)) == "number" 
		and type(tonumber(y)) == "number" and testBR.IsCellOnlyInLevel({tonumber(x), tonumber(y)}, level) then
			testBR.SetFogDamageLevel(pid, testBR.GetCurrentDamageLevel(level))
			foundLevel = true
			DebugLog(2, "Damage level for PID " .. tostring(pid) .. " is set to " .. tostring(currentFogStage - level))
			break
		end
	end
	
	if not foundLevel then
		testBR.SetFogDamageLevel(pid, 0)
	end
end


testBR.StartFogShrink = function()
    fogGridLimits = testBR.GenerateFogGrid(fogLevelSizes)
    DebugLog(2, "fogGridLimits is an array with " .. tostring(#fogGridLimits) .. " elements")

	currentFogStage = 1

    testBR.StartFogTimer(fogStageDurations[currentFogStage])
end

testBR.StartFogTimer = function(delay)
	tes3mp.LogMessage(2, "Setting shrink timer for " .. tostring(delay) .. " seconds")
	tes3mp.SendMessage(0,fogName .. " shrinking in " .. tostring(delay) .. " seconds.\n", true)
	fogTimer = tes3mp.CreateTimerEx("AdvanceFog", time.seconds(delay), "i", 1)
	tes3mp.StartTimer(fogTimer)
end

-- delay is for how long timer will last
-- init is to tell the function if it is being called for the first time. If not, then assume recursion
testBR.StartShrinkAlertTimer = function(delay)
	tes3mp.LogMessage(2, "Setting shrink timer alert for " .. tostring(delay) .. " seconds")
	shrinkAlertTimer = tes3mp.CreateTimerEx("HandleShrinkTimerAlertTimeout", time.seconds(delay), "i", 1)
	tes3mp.StartTimer(shrinkAlertTimer)
end

-- returns a list of squares that are to be used for fog levels
-- for example: { {{10, 0}, {0, 10}}, {{5, 5}, {5, 5}}, {} }
testBR.GenerateFogGrid = function(fogLevelSizes)	
	tes3mp.LogMessage(2, "Generating fog grid")
	generatedFogGrid = {}

	for level=1,#fogLevelSizes do
		tes3mp.LogMessage(2, "Generating level " .. tostring(level))
		generatedFogGrid[level] = {}
		
		-- handle the first item in the array (double check just to be sure)
		--if type(fogLevelSizes[level]) ~= "number" and fogLevelSizes[level] = "all" then
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
			if fogLevelSizes[level] < previousXLength - 1 and fogLevelSizes[level] < previousYLength - 1 then
				-- all right, looks like it will fit
				-- now we can even try to add "border" that is one cell wide, so that edges of previous level and new level don't touch
				cellBorder = 0
				if fogLevelSizes[level] < previousXLength - 2 and fogLevelSizes[level] < previousYLength - 2 then
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
			availableCornerAreaX = {availableVerticalArea[1], availableVerticalArea[2] - fogLevelSizes[level]}
			-- same for Y
			availableCornerAreaY = {availableHorisontalArea[1], availableHorisontalArea[2] - fogLevelSizes[level]}
			
			-- choose random cell in the available area
			newX = math.random(availableCornerAreaX[1],availableCornerAreaX[2])
			newY = math.random(availableCornerAreaY[1],availableCornerAreaY[2])
			
			-- save bottom left corner
			table.insert(generatedFogGrid[level], {newX, newY})
			-- save top right corner
			table.insert(generatedFogGrid[level], {newX + fogLevelSizes[level], newY + fogLevelSizes[level]})
			DebugLog(2, "" .. tostring(level) .. " goes from " .. tostring(newX) .. ", " .. tostring(newY) .. " to " ..
				tostring(newX + fogLevelSizes[level]) .. ", " .. tostring(newY + fogLevelSizes[level]))
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

testBR.UpdateMap = function()
	tes3mp.LogMessage(2, "Updating map to fog level " .. tostring(currentFogStage))
	tes3mp.ClearMapChanges()

	for levelIndex=1,#fogGridLimits do
		-- at this point I am just banging code together until it works
		-- got lucky with the first condition, added second condition in order to limit logic only to relevant levels
		if levelIndex - currentFogStage < #fogDamageValues and fogDamageValues[currentFogStage - levelIndex] ~= nil then
			DebugLog(2, "Level " .. tostring(levelIndex) .. " gets fog level " .. tostring(fogDamageValues[currentFogStage - levelIndex]))
			
			-- iterate through all cells in this level
			for x=fogGridLimits[levelIndex][1][1],fogGridLimits[levelIndex][2][1] do
				for y=fogGridLimits[levelIndex][1][2],fogGridLimits[levelIndex][2][2] do
					-- actually, instead of using IsCell**Only**InLevel() we can avoid checking cells which obviously are in the level
					-- instead, we just check if cells are not in the next level. Same thing that above mentioned function would do,
					-- but we do it on smaller set of cells
					-- so it's "is this the last level OR (is there next level AND cell is not part of next level)"
					if not fogGridLimits[levelIndex+1] or (fogGridLimits[levelIndex+1] and not testBR.IsCellInLevel({x, y}, levelIndex+1)) then
						tes3mp.LoadMapTileImageFile(x, y, fogFilePaths[currentFogStage - levelIndex])
					end
				end
			end
		end 
	end
end

testBR.GetCurrentDamageLevel = function(level)
	tes3mp.LogMessage(2, "Looking up damage level for level " .. tostring(level))
	if currentFogStage - level > #fogDamageValues then
		return fogDamageValues[#fogDamageValues]
	else
		return fogDamageValues[currentFogStage - level]
	end
end

testBR.StartAirdrop	= function()
    DebugLog(2, "Starting airdrop")
    airmode = 2
	testBR.HandleAirMode()
end

-- make effects get applied to players and set timer if needed
testBR.HandleAirMode = function()
    DebugLog(2, "Handling air mode. Current airmode = " .. tostring(airmode))

    for _, pid in pairs(playerList) do
        testBR.SetAirMode(pid, airmode)
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
testBR.CheckVictoryConditions = function()
	if #playerList == 1 then
		tes3mp.SendMessage(playerList[1], "Winner winner CHIM for dinner\n", false)
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

-- returns true if cell is part of level
testBR.IsCellInLevel = function(cell, level)
	DebugLog(4, "Checking if " .. tostring(cell[1]) .. ", " .. tostring(cell[2]) .. " is in level " .. tostring(level))
	-- check if cell is in level range
	if fogGridLimits[level] and testBR.IsCellInRange(cell, fogGridLimits[level][1], fogGridLimits[level][2]) then
		return true
	end
	return false
end

-- basically same function as above, only with added exclusivity check
-- returns true if cell is part of level
-- TODO: make this by implementing an "isExclusive" argument instead of having two seperate functions
testBR.IsCellOnlyInLevel = function(cell, level)
	DebugLog(2, "Checking if " .. tostring(cell[1]) .. ", " .. tostring(cell[2]) .. " is only in level " .. tostring(level))
	-- check if cell is in level range
	if fogGridLimits[level] and testBR.IsCellInRange(cell, fogGridLimits[level][1], fogGridLimits[level][2]) then
		-- now watch this: check if further levels exist and that cell does not actually belong to that further level
		if fogGridLimits[level+1] and testBR.IsCellInRange(cell, fogGridLimits[level+1][1], fogGridLimits[level+1][2]) then
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

-- ====================== MATCH DEBUG FUNCTIONS ======================

-- debug function
testBR.QuickStart = function()
    DebugLog(2, "Doing QuickStart")
	if debugLevel > 0 then
        for pid, player in pairs(Players) do
            DebugLog(2, "Adding PID " .. tostring(pid))
            testBR.AddPlayer(pid)
            testBR.PlayerConfirmParticipation(pid)
        end		
		testBR.StartMatch()
	end
end

-- end match and send everyone back to the lobby
testBR.EndMatch = function()
    -- Stop the shhrinking timer
    tes3mp.StopTimer(fogTimer)
    playerList = {}
	for _, pid in pairs(playerList) do
		-- remove player from match participants
		--Players[pid].data.BRinfo.inMatch = 0
		-- spawn player in lobby
		testBR.SpawnPlayer(pid, true)
	end
end

testBR.AdminEndMatch = function(pid)
	if Players[pid]:IsAdmin() then
		testBR.EndMatch()
	end
end


testBR.ForceNextFog = function(pid)
	if #fogStageDurations >= currentFogStage + 1 then
		AdvanceFog()
	end
end









































-- ====================== PLAYER-RELATED FUNCTIONS ======================


testBR.AddPlayer = function(pid)
	tes3mp.LogMessage(2, "Setting state for " .. tostring(pid))
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        table.insert(playerList, pid)
        tes3mp.SendMessage(pid,"You joined the next match\n", false)
	end
end


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

testBR.PlayerSpells = function(pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		Players[pid].data.spellbook = {}
		command = "player->addspell feather_power"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
		command = "player->addspell restore_fatigue_power"
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	end
end

testBR.PlayerItems = function(pid)
	testBR.LoadPlayerItems(pid)
end

-- save changes and make items appear on player
testBR.LoadPlayerItems = function(pid)
	tes3mp.LogMessage(2, "Loading items for " .. tostring(pid))
	Players[pid]:Save()
	Players[pid]:LoadInventory()
	Players[pid]:LoadEquipment()
end

--testBR.PlayerJoin = function(pid)
--	tes3mp.LogMessage(2, "Setting state for "  .. tostring(pid))
--	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
--        table.insert(playerList, pid)
--		Players[pid].data.BRinfo.inMatch = 1
--	end
--	tes3mp.SendMessage(pid, color.Yellow .. "Noice. Now you can either propose new match with /newmatch or do /ready when new match is being suggested .\n", false)
--end


-- TODO: for player clothes
testBR.PlayerItems = function(pid)
	
end


testBR.PlayerConfirmParticipation = function(pid)
	--if matchProposalInProgress and Players[pid] ~= nil and Players[pid]:IsLoggedIn() then IsInList(pid, playerList) then
    -- TODO: figure out proper criteria for this
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        table.insert(readyList, pid)
		tes3mp.SendMessage(pid, color.Yellow .. Players[pid].data.login.name .. " is ready.\n", false)
	end
end



-- set airborne-related effects
-- 1 = just slowfall
-- 2 = slowfall and speed
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
		Players[pid]:Save()
        testBR.CheckCellDamageLevel(pid)
	end
end


testBR.SpawnPlayer = function(pid, spawnInLobby)
	tes3mp.LogMessage(2, "Spawning player " .. tostring(pid))
	if spawnInLobby then
		chosenSpawnPoint = {lobbyCell, lobbyCoordinates[1], lobbyCoordinates[2], lobbyCoordinates[3], 0}
	else
		-- TEST: use random spawn point for now
		random_x = math.random(-40000,80000)
		random_y = math.random(-40000,120000)
		tes3mp.LogMessage(2, "Spawning player " .. tostring(pid) .. " at " .. tostring(random_x) .. ", " .. tostring(random_y))
		chosenSpawnPoint = {"1, 1", random_x, random_y, 30000, 0}
	end

	tes3mp.SetCell(pid, chosenSpawnPoint[1])
	tes3mp.SendCell(pid)
	tes3mp.SetPos(pid, chosenSpawnPoint[2], chosenSpawnPoint[3], chosenSpawnPoint[4])
	tes3mp.SetRot(pid, 0, chosenSpawnPoint[5])
	tes3mp.SendPos(pid)
end

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

-- inspired by code from from David-AW (https://github.com/David-AW/tes3mp-safezone-dropitems/blob/master/deathdrop.lua#L134)
-- and from rickoff (https://github.com/rickoff/Tes3mp-Ecarlate-Script/blob/0.7.0/DeathDrop/DeathDrop.lua
testBR.DropItem = function(pid, index, z_offset)
		
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
		if player:IsLoggedIn() then
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











testBR.SendMapToPlayer = function(pid)
	tes3mp.LogMessage(2, "Sending map to PID " .. tostring(pid))
	tes3mp.SendWorldMap(pid)
end

-- TODO: why is this here? Did Was it for removing containers and NPCS/creatures?
testBR.OnCellLoad = function(pid)

end

testBR.ProcessDeath = function(pid)
	if IsInList(pid, playerList) then
		testBR.DropAllItems(pid)
		table.remove(playerList, pid)
		testBR.CheckVictoryConditions(pid)
	end
	testBR.SpawnPlayer(pid, true)
	testBR.SetFogDamageLevel(pid, 0)
	--Players[pid].data.BRinfo.inMatch = 0
	Players[pid]:Save()
end

testBR.VerifyPlayerData = function(pid)
	tes3mp.LogMessage(2, "Verifying player data for " .. tostring(Players[pid]))
	
	if Players[pid].data.BRinfo == nil then
		BRinfo = {}
		BRinfo.matchId = ""
		BRinfo.inMatch = 0 -- 1 = alive, 0 = ded, press F to pay respects
		BRinfo.chosenSpawnPoint = nil
		BRinfo.team = 0
		BRinfo.airMode = 0
		BRinfo.totalKills = 0
		BRinfo.totalDeaths = 0		
		BRinfo.wins = 0
		BRinfo.BROutfit = {} -- used to hold data about player's chosen outfit
		BRinfo.secretNumber = math.random(100000,999999) -- used for verification
		Players[pid].data.BRinfo = BRinfo
		Players[pid]:Save()
	end
end

-- Called from local PlayerInit to reset characters for each new match
testBR.ResetCharacter = function(pid)
	tes3mp.LogMessage(2, "Resetting stats for " .. Players[pid].data.login.name .. ".")

	-- Reset battle royale
	Players[pid].data.BRinfo.team = 0
	--Players[pid].data.BRinfo.inMatch = 1
	
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
end


-- This is basically hijacking OnPlayerTopic event signal for our own purposes
-- OnPlayerTopic because it doesn't play any role in purely PvP gamemode where no NPCs are present
-- TODO: figure out how to add new event without messing up with server core, so that all the code is only in this file
customEventHooks.registerValidator("OnPlayerTopic", function(eventStatus, pid)
	return customEventHooks.makeEventStatus(false,true)
end)

-- TODO: remove because deprecated
customEventHooks.registerHandler("OnPlayerTopic", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.HandleAirMode(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerFinishLogin", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.VerifyPlayerData(pid)
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
customCommandHooks.registerCommand("forcestart", testBR.StartMatch)
customCommandHooks.registerCommand("join", testBR.AddPlayer)
customCommandHooks.registerCommand("ready", testBR.PlayerConfirmParticipation)
customCommandHooks.registerCommand("forcenextfog", AdvanceFog)
customCommandHooks.registerCommand("forceend", testBR.AdminEndMatch)
customCommandHooks.registerCommand("x", testBR.QuickStart)

return testBR
