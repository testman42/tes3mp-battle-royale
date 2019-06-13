
-- Battle Royale game mode by testman
-- v0.1

-- TODO:
-- untangle all the spaghetti code
-- figure out how the zone-shrinking logic should actually work
-- implement said decent zone-shrinking logic
--- make shrinking take some time instead of being an instant event
--- make zone circle-shaped
-- make players unable to open doors
-- make players unable to open vanilla containers
-- implement victory condition logic
-- implement custom containers that can be opened by players
-- make players start taking damage if they are in a cell that turned into a non-safe cell

-- Idea for some parts of zone-shrinking logic:
-- use 5, 5 as center instead of 0, 0 for fog logic because it is much more fitting when it comes to Vvardenfel's geography
-- Fog progression (% = x_cells, y_cells)
-- 100% = 40, 40 // 20 per side
-- 60% = 30, 30 // 15 per side
-- 20% = 20, 20 // 10 per side
-- 6% = 3, 3 // 4 per side
-- 2% = 1, 1  // 1 per side
-- 0% = 0, 0  // 0 per side

time = require("time")

-- used for generation of random numbers
math.randomseed(os.time())

-- find a decent name for overall project
testBR = {}

-- unique identifier for the round
roundID = nil

-- indicates if there is currently an active match going on
roundInProgress = 0

-- how fast time passes
-- you will most likely want this to be very low in order to have skybox remain the same
timeScale = 0.1

-- determines defaulttime of day for maps that do not have it specified
timeOfDay = 9

-- determines default weather
weather = 0

-- Determines if the effects from player's chosen race get applied
allowRacePowers = false

-- Determines if the effects from player's chosen celestial sign get applied
allowSignPowers = false

-- Determines if it is possible to use different presets of equipment / stats 
allowClasses = true

-- define image files for map
fog1FilePath = tes3mp.GetDataPath() .. "/map/fog1.png"
fog3FilePath = tes3mp.GetDataPath() .. "/map/fog3.png"

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

-- config that determines how the fog will behave 
-- { {areaSize, duration}, ... }
-- end with {0, 0} because of bad fog-advancing logic
fogStages = {{20, 6000}, {15, 3000}, {10, 240}, {4, 120}, {2, 120}, {1, 60}, {0, 60}, {0, 0}}
--fogStages = {{20, 20}, {15, 10}, {10, 10}, {4, 10}, {2, 10}, {1, 10}, {0, 10}, {0, 0}}
currentFogStage = 1
currentCenter = {5, 5}

-- used to track cells that cause damage
-- will consist of two lists, one for fogdamage1 and one for fogdamage3
-- cells will go from safe to fogdamage1 and then to fogdamage3
fogCellList = {
safe = {},
fog1 = {},
fog3 = {}
}

weaponList = {}
armorList = {}

playerList = {}

testBR.StartRound = function(pid)
	tes3mp.LogMessage(2, "Starting a battle royale round")
	if Players[pid]:IsAdmin() then

		playerList = {}
		fogCellList = {
		safe = {},
		fog1 = {},
		fog3 = {}
		}

		-- initially declare all cells as safe
		for x = -15,25 do
			for y = -15,25 do
				currentCell = {x, y}
				--tes3mp.LogMessage(2, "Adding cell " .. tostring(currentCell[1]) .. ", " .. tostring(currentCell[2]))
				table.insert(fogCellList.safe, currentCell)
			end
		end
		tes3mp.SendMessage(pid, tostring(#fogCellList.safe) .. " safe cells at start\n", false)


		currentFogStage = 1

		testBR.ResetWorld()

		for pid2, player in pairs(Players) do
			testBR.PlayerInit(pid2)
		end

		AdvanceFog()
	end
end

testBR.PlayerInit = function(pid)
	tes3mp.LogMessage(2, "Starting initial setup for PID ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() and Players[pid].data.BRinfo.inMatch == 1 then
		testBR.ResetCharacter(pid)
		--tes3mp.LogMessage(2, "Finished character reset")
		testBR.SpawnPlayer(pid)
		--tes3mp.LogMessage(2, "Finished spawning")
		testBR.PlayerItems(pid)
		--tes3mp.LogMessage(2, "Finished giving items")
		Players[pid].data.spellbook = {}
		testBR.SetFogDamageLevel(pid, 0)
		Players[pid].data.BRinfo.airMode = 3
		testBR.HandleAirMode(pid)
		--tes3mp.LogMessage(2, "Finished air mode")
	end
end

testBR.PlayerJoin = function(pid)
	tes3mp.LogMessage(2, "Setting state for ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		Players[pid].data.BRinfo.inMatch = 1
	end
	tes3mp.SendMessage(pid, color.Yellow .. Players[pid].data.login.name .. " is ready.\n", false)
end

--
testBR.ProcessCellChange = function(pid)
	tes3mp.LogMessage(2, "Processing cell change for PID ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		testBR.CheckCell(pid)
		Players[pid]:SaveStatsDynamic()
		Players[pid]:Save()
	end
end

testBR.OnPlayerEndCharGen = function(pid)
	if Players[pid] ~= nil then
		tes3mp.LogMessage(2, "++++ Newly created PID: ", pid)
		testBR.EndCharGen(pid)
	end
end


-- TODO: use some enumeration thing or something that merges these three loops into one
testBR.CheckCell = function(pid)
	tes3mp.LogMessage(2, "Checking new cell for PID ", pid)
	playercell = Players[pid].data.location.cell

	for index, list in pairs(fogCellList) do
		tes3mp.LogMessage(2, "Checking if cell is in " .. index)
		for i=1,#list do
			-- tes3mp.LogMessage(2, "Checking if " .. playercell ..  " == " .. tostring(list[i][1]) .. ", " .. tostring(list[i][2]) )
			if playercell == tostring(list[i][1]) .. ", " .. tostring(list[i][2]) then
				if index == "safe" then
					testBR.SetFogDamageLevel(pid, 0)
				elseif index == "fog1" then
					testBR.SetFogDamageLevel(pid, 1)
				elseif index == "fog3" then
					testBR.SetFogDamageLevel(pid, 3)
				end
			end
		end
	end
end

testBR.ResetWorld = function()

end

testBR.PlayerItems = function(pid)

end

testBR.SetFogDamageLevel = function(pid, level)
	tes3mp.LogMessage(2, "Setting damage level for PID ", pid)
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


-- TODO: properly describe fog progression logic
function AdvanceFog()
	tes3mp.LogMessage(2, "Advancing fog")
	
	if currentFogStage < #fogStages then

		currentCenter = testBR.ReturnNewRandomCenter(currentCenter, fogStages[currentFogStage][1], fogStages[currentFogStage+1][1])
		
		testBR.UpdateCellList(currentCenter, fogStages[currentFogStage][1])
		
		tes3mp.SendMessage(0, color.Yellow .. "Deadly blight shrinking in " .. tostring(fogStages[currentFogStage][2]) .. " seconds\n", false)
		
		tes3mp.LogMessage(2, "Sending debug message about grid")
		tes3mp.SendMessage(0, "Safe: " .. tostring(#fogCellList.safe) .. " | fog1: " .. tostring(#fogCellList.fog1) .. " | fog3: " .. tostring(#fogCellList.fog3) .. "\n", false)
		--[[
		if #fogCellList.safe > 0 then
			tes3mp.SendMessage(0, "Safe cells left:" .. tostring(#fogCellList.safe) .. "\n", false)
			tes3mp.SendMessage(0, color.Yellow .. "(" .. tostring(currentCenter[1]) .. ", " .. tostring(currentCenter[2]) 
			.. ") s=" .. tostring(fogStages[currentFogStage+1][1]) .. " | " .. tostring(fogCellList.safe[1][1]) .. ", " .. tostring(fogCellList.safe[1][2]) 
			.. " - " .. tostring(fogCellList.safe[#fogCellList.safe][1]) .. ", " .. tostring(fogCellList.safe[#fogCellList.safe][2]) .. "\n", false)
		else
			tes3mp.SendMessage(0, color.Yellow .. "No more safe cells left\n", false)
		end
		]]
		
		tes3mp.LogMessage(2, "Sending new map to all players")
		for pid, player in pairs(Players) do
			if player ~= nil and player:IsLoggedIn() then
				testBR.UpdateMap(pid)
			end
		end

		currentFogStage = currentFogStage + 1
		fogTimer = tes3mp.CreateTimerEx("AdvanceFog", time.seconds(fogStages[currentFogStage][2]), "i", 1)
		tes3mp.StartTimer(fogTimer)
	end
end

-- return list of cells that that fog will take over
-- takes coordinate of center
testBR.UpdateCellList = function(center, size)
	tes3mp.LogMessage(2, "Updating cell list")

	-- TODO: Implement this: https://en.wikipedia.org/wiki/Midpoint_circle_algorithm
	-- GenerateCircle(center, size)
	safeSquare = testBR.GenerateSquare(center, size)

	-- advance fog damage level
	
	tes3mp.LogMessage(2, "Moving all fog1 cells to fog3")
	if #fogCellList.fog1 > 0 then
		for i=1,#fogCellList.fog1 do
			table.insert(fogCellList.fog3, fogCellList.fog1[i])
			fogCellList.fog1[i] = nil
		end
	end
	
	-- check if cell can stay on the list of safe cells
	tes3mp.LogMessage(2, "Checking which cells stay safe")
	if #fogCellList.safe > 0 then
		for i=1,#fogCellList.safe do
			
			--tes3mp.LogMessage(2, "doing the for loop")
			isStillSafe = false
			for j=1,#safeSquare do	
				if fogCellList.safe[i][1] == safeSquare[j][1] and fogCellList.safe[i][2] == safeSquare[j][2] then
					isStillSafe = true
				end
			end
			
			-- move cell from list of safe cells to list of damage-dealing cells
			if not isStillSafe then
				-- lol this is a bad array hacking
				tempCell = fogCellList.safe[i]
				
				--tes3mp.LogMessage(2, "tempCell is now " .. tostring(tempCell[1]) .. ", " .. tostring(tempCell[2]))
				--tes3mp.LogMessage(2, "Moving cell " .. tostring(tempCell[1]) .. ", " .. tostring(tempCell[2]) .. " to fog1")
				fogCellList.safe[i] = nil
				--tes3mp.LogMessage(2, "fogCellList.safe is now of the size " .. tostring(#fogCellList.safe))
				table.insert(fogCellList.fog1, tempCell)
			end
		end
	end
	
	-- thanks discordpeter for reminding me that this exists
	tableHelper.cleanNils(fogCellList.safe)
	tableHelper.cleanNils(fogCellList.fog1)
end

testBR.GenerateSquare = function(center, size)
	tes3mp.LogMessage(2, "Generating square of size " .. tostring(size) .. " with center at " .. tostring(center[1]) .. ", " .. tostring(center[2]))

	size = size - 1
	newGrid = {}

	if size == 1 then
		-- needs to brackets because of logic in UpdateCellList
		return {{center[1], center[2]}}
	elseif size == 0 then
		return newGrid
	end

	-- declare the coordinates of all cells in the new square
	for x = -size,size do
		for y = -size,size do
			-- appy offset and add to the list
			table.insert(newGrid, {x+center[1], y+center[2]})
		end
	end

	return newGrid
end


testBR.ReturnNewRandomCenter = function(center, currentSize, nextSize)
	tes3mp.LogMessage(2, "Giving new random center")
	-- because we are working with square we can use same limit for x and y
	-- -1 in order to prevent overlap with edge of previous area
	if nextSize == 0 then
		return center
	else
		newArea = currentSize - nextSize - 1
		newX = math.random(-newArea,newArea)
		newY = math.random(-newArea,newArea)
	end
	
	-- apply translation when returning the new center
	return {newX+center[1], newY+center[2]}
end


testBR.UpdateMap = function(pid)
	tes3mp.LogMessage(2, "Updating map for ", pid)
	tes3mp.ClearMapChanges()

	for index, list in pairs(fogCellList) do
		for i=1,#list do
			if index == "fog1" then
				tes3mp.LoadMapTileImageFile(list[i][1], list[i][2], fog1FilePath)
			elseif index == "fog3" then
				tes3mp.LoadMapTileImageFile(list[i][1], list[i][2], fog3FilePath)
			end
		end
	end

	tes3mp.SendWorldMap(pid)
end

-- save changes and make items appear on player
testBR.LoadPlayerItems = function(pid)
	tes3mp.LogMessage(2, "Loading items for ", pid)
	Players[pid]:Save()
	Players[pid]:LoadInventory()
	Players[pid]:LoadEquipment()

end

testBR.ProcessDeath = function(pid)
	testBR.SpawnPlayer(pid, true)
	testBR.SetFogDamageLevel(pid, 0)
	Players[pid].data.BRinfo.inMatch = 0
	Players[pid]:Save()
end

-- spawn player either in the chosen point on the battlefield or in the lobby
testBR.SpawnPlayer = function(pid, spawnInLobby)
	tes3mp.LogMessage(2, "Spawning player ", pid)
	if spawnInLobby then
		chosenSpawnPoint = {"toddtest", 2177.776367, 653.002380, -184.874023, 0}
	else
		-- TEST: use random spawn point for now
		random_x = math.random(-40000,80000)
		random_y = math.random(-40000,120000)
		tes3mp.LogMessage(2, "Spawning player " .. tostring(pid) .. " at " .. tostring(random_x) .. ", " .. tostring(random_y))
		--chosenSpawnPoint = {"-2, 7", -13092, 57668, 2593, 2.39}
		chosenSpawnPoint = {"0, 0", random_x, random_y, 30000, 0}
		--chosenSpawnPoint = Players[pid].data.BRinfo.chosenSpawnPoint
		Players[pid].data.BRinfo.airmode = 2
	end
	tes3mp.SetCell(pid, chosenSpawnPoint[1])
	tes3mp.SendCell(pid)
	tes3mp.SetPos(pid, chosenSpawnPoint[2], chosenSpawnPoint[3], chosenSpawnPoint[4])
	tes3mp.SetRot(pid, 0, chosenSpawnPoint[5])
	tes3mp.SendPos(pid)
end

-- handles the timers and parameters for SetAirMode
testBR.HandleAirMode = function(pid)
	tes3mp.LogMessage(2, "Running air mode handling logic for ", pid)
	airmode = Players[pid].data.BRinfo.airMode
	
	--tes3mp.SendMessage(pid, color.Yellow .. "Setting airmode to " .. tostring(airmode) .. ".\n", false)
	testBR.SetAirMode(pid, airmode)
	if airmode > 0 then
		airmode = airmode - 1
		Players[pid].data.BRinfo.airMode = airmode
		Players[pid]:Save()

		-- start a timer that will disable high speed for every player
		-- TODO: figure out how to make it so that there is only one instance of timer instead of having a seperate timer for each player
		Players[pid].airTimer = tes3mp.CreateTimerEx("OnPlayerTopic", time.seconds((15*airmode)+3), "i", pid)
		tes3mp.StartTimer(Players[pid].airTimer)
	end
end

-- set airborne-related effects
-- count from 2 to avoid math gymnastics in HandleAirTime
-- 2 = just slowfall
-- 3 = slowfall and speed
testBR.SetAirMode = function(pid, mode)
	tes3mp.LogMessage(2, "Setting air mode for ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		if mode == 3 then
			testBR.SetSlowFall(pid, true)
			Players[pid].data.attributes["Speed"].base = 3000
		elseif mode == 2 then
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
	tes3mp.LogMessage(2, "Setting slowfall mode for PID ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		if boolean then
			command = "player->addspell slowfall_power"
		else
			command = "player->removespell slowfall_power"
		end
		logicHandler.RunConsoleCommandOnPlayer(pid, command)
	end
end

testBR.VerifyPlayerData = function(pid)
	tes3mp.LogMessage(2, "++++ --JSONCheck: Checking player data for " .. Players[pid].data.login.name .. ". ++++")
	
	if Players[pid].data.BRinfo == nil then
		BRinfo = {}
		BRinfo.matchId = ""
		BRinfo.inMatch = 0 -- 1 = alive, 0 = ded, press F to pay respects
		BRinfo.chosenSpawnPoint = nil
		BRinfo.team = 0
		BRinfo.airMode = 0
		BRinfo.totalKills = 0
		BRinfo.totalDeaths = 0
		BRinfo.BROutfit = {} -- used to hold data about player's chosen outfit
		Players[pid].data.BRinfo = BRinfo
		Players[pid]:Save()
	end
end

-- Called from local PlayerInit to reset characters for each new match
testBR.ResetCharacter = function(pid)
	tes3mp.LogMessage(2, "Resetting stats for " .. Players[pid].data.login.name .. ".")

	-- Reset battle royale
	Players[pid].data.BRinfo.team = 0
	Players[pid].data.BRinfo.inMatch = 1
	
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
	tes3mp.LogMessage(2, "Ending character generation for ", pid)
	Players[pid]:SaveLogin()
	Players[pid]:SaveCharacter()
	Players[pid]:SaveClass()
	Players[pid]:SaveStatsDynamic()
	Players[pid]:SaveEquipment()
	Players[pid]:SaveIpAddress()
	Players[pid]:CreateAccount()
	testBR.VerifyPlayerData(pid)
	--testBR.PlayerInit(pid)
end

testBR.isInternalCell = function(cellDescription)
	return
end

testBR.QuickStart = function(pid)
	testBR.PlayerJoin(pid)
	testBR.StartRound(pid)
end

-- end match and send everyone back to the lobby
testBR.EndMatch = function()
	for pid, player in pairs(Players) do
		-- remove player from round participants
		Players[pid].data.BRinfo.inMatch = 0
		-- spawn player in lobby
		testBR.SpawnPlayer(pid, true)
	end
end

testBR.AdminEndMatch = function(pid)
	if Players[pid]:IsAdmin() then
		testBR.EndMatch()
	end
end


-- custom handlers
--config.defaultSpawnCell = "-3, -2"
--config.defaultSpawnPos = {-23894.0, -15079.0, 505}
--config.defaultSpawnRot = {0, 1.2}

customEventHooks.registerHandler("OnServerPostInit", function()

end)

-- This is basically hijacking OnPlayerTopic event signal for our own purposes
-- OnPlayerTopic because it doesn't play any role in purely PvP gamemode where no NPCs are present
-- TODO: figure out how to add new event without messing up with server core, so that all the code is only in this file
customEventHooks.registerValidator("OnPlayerTopic", function(eventStatus, pid)
	return customEventHooks.makeEventStatus(false,true)
end)

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

customEventHooks.registerHandler("OnPlayerCellChange", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.ProcessCellChange(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerBounty", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testBR.ProcessCellChange(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerEndCharGen", function(eventstatus, pid)
	if Players[pid] ~= nil then
		tes3mp.LogMessage(2, "++++ Newly created: ", pid)
		testBR.EndCharGen(pid)
	end
end)

-- custom validator for cell change
customEventHooks.registerValidator("OnPlayerCellChange", function(eventStatus, pid)
	tes3mp.LogMessage(2, "Player " .. pid .. " trying to enter cell " .. tostring(tes3mp.GetCell(pid)))

	-- allow player to spawn in lobby	
	if tes3mp.GetCell(pid) == "ToddTest" then
		return customEventHooks.makeEventStatus(true,true)
	end

	_, _, cellX, cellY = string.find(tes3mp.GetCell(pid), patterns.exteriorCell)
    if cellX == nil or cellY == nil then
		tes3mp.LogMessage(2, "Cell is not external and can not be entered")
		Players[pid].data.location.posX = tes3mp.GetPreviousCellPosX(pid)
		Players[pid].data.location.posY = tes3mp.GetPreviousCellPosY(pid)
		Players[pid].data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
		Players[pid]:LoadCell()
        return customEventHooks.makeEventStatus(false,true)
    end
end)

customCommandHooks.registerCommand("startround", testBR.StartRound)
customCommandHooks.registerCommand("join", testBR.PlayerJoin)
customCommandHooks.registerCommand("forceend", testBR.AdminEndMatch)
customCommandHooks.registerCommand("x", testBR.QuickStart)

return testBR
