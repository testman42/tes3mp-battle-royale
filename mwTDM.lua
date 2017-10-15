-- mwTDM by Texafornian
-- v1710.15 for TES3MP v0.6.1
--
-- Many thanks to:
-- * David (inventory checker & general LUA-fu)
-- * ppsychrite (JSON scripting examples)

-----------------------
-- DO-NOT-TOUCH SECTION
-----------------------

local time = require("time")
require("actionTypes")
require("mwTDMSpawns")

local Methods = {}

math.randomseed(os.time())

mapRotationNum = 0
matchId = ""
teamOneScore = 0
teamTwoScore = 0
	
--------------------------
-- CONFIG/SETTINGS SECTION
--------------------------
 
-- Determines whether the server follows a map rotation or not
-- (NOT IMPLEMENTED)
-- randomMaps = false
 
-- List of "maps" in rotation. Options: Ald-Ruhn, Balmora, Dagoth-Ur
-- (Maps can be repeated in rotation. Ex: {"Balmora", "Balmora", "Ald-Ruhn"})
mapRotation = {"Balmora", "Dagoth-Ur", "Ald-Ruhn"}

-- Number of kills required for either team to win
scoreToWin = 15

-- Determines whether players are allowed to manually switch teams
canSwitchTeams = true

-- Default spawn time in seconds
spawnTime = 5

-- Determines whether suicide & team-killing add spawn delay and its duration
addSpawnDelay = true
spawnDelay = 3

-- Names of the two teams
-- (Change "color.Blue" and "...Brown" in function ProcessDeath)
teamOne = "Blue Team"
teamTwo = "Brown Team"

-- Each team's default uniforms with format: {shirt, pants, shoes}
teamOneUniform = {"expensive_shirt_02", "expensive_pants_02", "expensive_shoes_02"} 
teamTwoUniform = {"expensive_shirt_01", "expensive_pants_01", "expensive_shoes_01"} 

-- Starting equipped items for both teams
playerEquipMelee = {{"steel saber", 1, -1}, {"steel_shield", 1, -1}} -- "Melee"
playerEquipRanged = {{"steel crossbow", 1, -1}, {"bonemold bolt", 75, -1}} -- "Ranged"

-- Chooe "Melee" or "Ranged" for starting equipment, or leave it blank as ""
playerEquipmentType = "Ranged"

-- Starting inventory items for both teams
-- (You can add as many items as you want; simply follow the format {"reference ID", count, charge})
playerInventory =  {{"ingred_bread_01_UNI3", 1, -1}, {"steel shortsword", 1, -1}} 

-- Default stats for players
playerLevel = 1
playerAttributes = 75
playerSkills = 75
playerHealth = 11
playerMagicka = 50
playerFatigue = 170

-- These override the above values for more control over the pace of the game
playerLuck = 50
playerSpeed = 65
playerAcrobatics = 125 -- Ignored when playing the Dagoth-Ur map
playerMarksman = 150

------------------
-- METHODS SECTION
------------------

Methods.MatchInit = function() -- Starts new match, resets matchId, controls map rotation, and clears teams
	local tempAcrobatics = playerAcrobatics
	matchId = os.date("%y%m%d%H%M%S") -- Later used in TeamHandler to determine whether to reset character
	teamOneScore = 0
	teamTwoScore = 0
	
	mapRotationNum = mapRotationNum + 1 -- Iterate the current map number
	
	if mapRotationNum == 0 or mapRotationNum > table.getn(mapRotation) then -- Reset map number to start of rotation if needed
		mapRotationNum = 1
	end
	
	tes3mp.LogMessage(2, "++++ Methods.MatchInit: Starting map " .. mapRotation[mapRotationNum] .. " with ID " .. matchId .. " ++++")
	
    for pid, p in pairs(Players) do -- Iterate through all players and start assigning teams
		
		if p ~= nil and p:IsLoggedIn() then

			if p.data.mwTDM == nil then
				tes3mp.LogMessage(2, "++++ Methods.MatchInit: Pre JSON Check ++++")
				JSONCheck(p.pid)
			end
			
			-- If player is alive, then begin reassign+respawn procedure
			if p.data.mwTDM.status == 1 then
				p.data.mwTDM.team = 0
				TeamHandler(p.pid)
			end
        end
    end
end

Methods.ListTeams = function(pid)
	local teamOneCount = 0
	local teamTwoCount = 0
	local teamOneList = teamOne .. " (" .. teamOneCount .. ") | Score: " .. teamOneScore .. "\n----------"
	local teamTwoList = teamTwo .. " (" .. teamTwoCount .. ") | Score: " .. teamTwoScore .. "\n----------"
	
	tes3mp.LogMessage(2, "++++ Methods.ListTeams: Building list of teams + players. ++++")
    for pid, p in pairs(Players) do 
        
		if p:IsLoggedIn() and p.data.mwTDM ~= nil then
			
			if p.data.mwTDM.team == 0 then
				-- Player is unassigned
			elseif p.data.mwTDM.team == 1 then
				tes3mp.LogMessage(2, "++++ Methods.ListTeams: Adding player " .. p.data.login.name .. " to " .. teamOne .. ". ++++")
				teamOneCount = teamOneCount + 1
				teamOneList = teamOneList .. "\n" .. p.data.login.name .. " | K: " .. p.data.mwTDM.kills .. " | D: " .. p.data.mwTDM.deaths
			elseif p.data.mwTDM.team == 2 then
				tes3mp.LogMessage(2, "++++ Methods.ListTeams: Adding player " .. p.data.login.name .. " to " .. teamTwo .. ". ++++")
				teamTwoCount = teamTwoCount + 1
				teamTwoList = teamTwoList .. "\n" .. p.data.login.name .. " | K: " .. p.data.mwTDM.kills .. " | D: " .. p.data.mwTDM.deaths
			end
        end
	end
	
	tes3mp.MessageBox(pid, -1, teamOneList .. "\n\n" .. teamTwoList)
end

Methods.OnPlayerDeath = function(pid) -- Called whenever player dies. Updates kill and death count

	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		ProcessDeath(pid)
	end
end

Methods.OnDeathTimeExpiration = function(pid)
	
    if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
        tes3mp.Resurrect(pid, actionTypes.resurrect.REGULAR)
		Players[pid].data.mwTDM.spawnSeconds = spawnTime
		Players[pid].data.mwTDM.status = 1 -- Player is now alive and safe for teleporting
		TeamHandler(pid)
    end
end

Methods.OnGUIAction = function(pid, idGui, data)
    data = tostring(data) -- data can be numeric, but we should convert this to string
	
    if idGui == GUI.ID.LOGIN then
	
        if data == nil then
            Players[pid]:Message("Incorrect password!\n")
            GUI.ShowLogin(pid)
            return true
        end

        Players[pid]:Load()

        -- Just in case the password from the data file is a number, make sure to turn it into a string
        if tostring(Players[pid].data.login.password) ~= data then
            Players[pid]:Message("Incorrect password!\n")
            GUI.ShowLogin(pid)
            return true
        end

        -- Is this player on the banlist? If so, store their new IP and ban them
        if tableHelper.containsValue(banList.playerNames, string.lower(Players[pid].accountName)) == true then
            Players[pid]:SaveIpAddress()

            Players[pid]:Message(Players[pid].accountName .. " is banned from this server.\n")
            tes3mp.BanAddress(tes3mp.GetIP(pid))
        else
            Players[pid]:FinishLogin()
            Players[pid]:Message("You have successfully logged in.\n")
			
			if Players[pid].data.mwTDM ~= nil then
				Players[pid].data.mwTDM.team = 0
				Players[pid].data.mwTDM.status = 1
			end
			
			TeamHandler(pid)
        end
    elseif idGui == GUI.ID.REGISTER then
	
        if data == nil then
            Players[pid]:Message("Password can not be empty\n")
            GUI.ShowRegister(pid)
            return true
        end
        Players[pid]:Registered(data)
        Players[pid]:Message("You have successfully registered.\nUse Y by default to chat or change it from your client config.\n")
    end
    return false
end

Methods.OnPlayerCellChange = function(pid)

	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		CheckCell(pid)
		Players[pid]:SaveStatsDynamic()
		Players[pid]:Save()
	end
end

Methods.OnPlayerEndCharGen = function(pid)

	if Players[pid] ~= nil then
		EndCharGen(pid)
	end
end

Methods.SwitchTeams = function(pid)

	if canSwitchTeams == true then
	
		if Players[pid].data.mwTDM.team == 1 then
			Players[pid].data.mwTDM.team = 2
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamTwo .. ".\n", true)
		elseif Players[pid].data.mwTDM.team == 2 then
			Players[pid].data.mwTDM.team = 1
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamOne .. ".\n", true)
		end
		
		TeamItems(pid)
	elseif canSwitchTeams == false then
		tes3mp.SendMessage(pid, color.Red .. "Changing teams is disabled on this server.\n", false)
	end
end

--------------------
-- FUNCTIONS SECTION
--------------------

function CheckCell(pid)
	local cell = tes3mp.GetCell(pid)
	
	-- This might be unnecessary now
    if Players[pid].data.mapExplored == nil then
        Players[pid].data.mapExplored = {}
    end
	
	if string.lower(mapRotation[mapRotationNum]) == "ald-ruhn" then
		
		if cell ~= "-2, 6" and cell ~= "-2, 7" then
			CellRestricted(pid, cell)
		else
			CellAllowed(pid, cell)
		end
	elseif string.lower(mapRotation[mapRotationNum]) == "balmora" then
		
		if cell ~= "-3, -2" and cell ~= "-3, -3" and cell ~= "-2, -2" then
			CellRestricted(pid, cell)
		else
			CellAllowed(pid, cell)
		end		
	elseif string.lower(mapRotation[mapRotationNum]) == "dagoth-ur" then
		
		if cell ~= "Akulakhan's Chamber" then
			CellRestricted(pid, cell)
		else
			CellAllowed(pid, cell)
		end
	end
end

function CellRestricted(pid, cell)
	local prevPosX = tostring(tes3mp.GetPreviousCellPosX(pid))
	local curPosX = tostring(tes3mp.GetPosX(pid))
	local prevPosY = tostring(tes3mp.GetPreviousCellPosY(pid))
	local curPosY = tostring(tes3mp.GetPosY(pid))
	local prevPosZ = tostring(tes3mp.GetPreviousCellPosZ(pid))

	tes3mp.SetCell(pid, Players[pid].data.location.cell)
	tes3mp.SetPos(pid, prevPosX, prevPosY, prevPosZ)
	tes3mp.SendCell(pid)
	tes3mp.SendPos(pid)
end

function CellAllowed(pid, cell)
	Players[pid].data.location.cell = cell
	Players[pid].data.location.posX = tes3mp.GetPosX(pid)
	Players[pid].data.location.posY = tes3mp.GetPosY(pid)
	Players[pid].data.location.posZ = tes3mp.GetPosZ(pid)
	Players[pid].data.location.rotX = tes3mp.GetRotX(pid)
	Players[pid].data.location.rotZ = tes3mp.GetRotZ(pid)
	
	if tes3mp.IsInExterior(pid) == true then

		if tableHelper.containsValue(Players[pid].data.mapExplored, cell) == false then
			table.insert(Players[pid].data.mapExplored, cell)
		end
	end
end

function EndCharGen(pid)
    Players[pid]:SaveLogin()
    Players[pid]:SaveCharacter()
    Players[pid]:SaveClass()
    Players[pid]:SaveStatsDynamic()
    Players[pid]:SaveEquipment()
    Players[pid]:SaveIpAddress()
    Players[pid]:CreateAccount()

    if config.shareJournal == true then
        WorldInstance:LoadJournal(pid)
    else
        Players[pid]:LoadJournal()
    end

    WorldInstance:LoadTopics(pid)
	TeamHandler(pid)
end

function JSONCheck(pid) -- Add TDM info to player JSON files if not present
	tes3mp.LogMessage(2, "++++ Function JSONCheck: Checking player JSON file for " .. Players[pid].data.login.name .. ". ++++")
	
	if Players[pid].data.mwTDM == nil then
		local tdmInfo = {}
		tdmInfo.matchId = ""
		tdmInfo.status = 1 -- 1 = alive
		tdmInfo.team = 0
		tdmInfo.kills = 0
		tdmInfo.deaths = 0
		tdmInfo.spree = 0
		tdmInfo.spawnSeconds = spawnTime
		tdmInfo.totalKills = 0
		tdmInfo.totalDeaths = 0
		Players[pid].data.mwTDM = tdmInfo
	end
end

function ProcessDeath(pid) -- Update player kills/deaths and team scores
	Players[pid].data.mwTDM.status = 0  -- Player is dead and not safe for teleporting
	Players[pid].data.mwTDM.deaths = Players[pid].data.mwTDM.deaths + 1
	Players[pid].data.mwTDM.totalDeaths = Players[pid].data.mwTDM.totalDeaths + 1
	Players[pid].data.mwTDM.spree = 0
	
	local deathReason = tes3mp.GetDeathReason(pid)
	local killCheck = false
	local killerTeam = 0
	
	tes3mp.LogMessage(1, "Original death reason was " .. deathReason)

	if deathReason == "suicide" then
		deathReason = "committed suicide"
		Players[pid].data.mwTDM.kills = Players[pid].data.mwTDM.kills - 1
		
		if addSpawnDelay == true then
			Players[pid].data.mwTDM.spawnSeconds = Players[pid].data.mwTDM.spawnSeconds + spawnDelay
		end
	else
		local playerKiller = deathReason
		
		for pid2, player in pairs(Players) do
		
			if Players[pid2]:IsLoggedIn() then
			
				if string.lower(playerKiller) == string.lower(player.name) then
				
					if Players[pid].data.mwTDM.team == Players[pid2].data.mwTDM.team then
						Players[pid2].data.mwTDM.kills = Players[pid2].data.mwTDM.kills - 1
						Players[pid2].data.mwTDM.totalKills = Players[pid2].data.mwTDM.totalKills - 1
						Players[pid2].data.mwTDM.spree = 0
						
						if Players[pid].data.mwTDM.team == 1 then
							teamOneScore = teamOneScore - 1
						elseif Players[pid].data.mwTDM.team == 2 then
							teamTwoScore = teamTwoScore - 1
						end
						
						if addSpawnDelay == true then
							Players[pid2].data.mwTDM.spawnSeconds = Players[pid2].data.mwTDM.spawnSeconds + spawnDelay
						end
					else 
						Players[pid2].data.mwTDM.kills = Players[pid2].data.mwTDM.kills + 1
						Players[pid2].data.mwTDM.totalKills = Players[pid2].data.mwTDM.totalKills + 1
						Players[pid2].data.mwTDM.spree = Players[pid2].data.mwTDM.spree + 1
						killCheck = true
						killerTeam = Players[pid2].data.mwTDM.team
						
						if Players[pid].data.mwTDM.team == 1 then
							teamTwoScore = teamTwoScore + 1
						elseif Players[pid].data.mwTDM.team == 2 then
							teamOneScore = teamOneScore + 1
						end
					end
					
					if Players[pid2].data.mwTDM.spree == 3 then
						tes3mp.SendMessage(pid, color.Green .. Players[pid2].data.login.name .. " is on a killing spree!\n", true)
					end
					
					break
				end
			end
		end
		
		deathReason = "was killed by " .. deathReason
	end

	local message = ("%s (%d) %s"):format(Players[pid].data.login.name, pid, deathReason)
	
	if killCheck == true then
		
		if Players[pid].data.mwTDM.team == 1 then
			message = color.Brown .. message .. ".\n"
		elseif Players[pid].data.mwTDM.team == 2 then
			message = color.Blue .. message .. ".\n"
		end
		
		tes3mp.SendMessage(pid, message, true)
		ScoreCheck(pid, killerTeam)
	else
		message = message .. ".\n"
		tes3mp.SendMessage(pid, message, true)
	end
	
	tes3mp.SendMessage(pid, color.Yellow .. "Respawning in " .. Players[pid].data.mwTDM.spawnSeconds .. " seconds...\n", false)
	
	local timer = tes3mp.CreateTimerEx("OnDeathTimeExpiration", time.seconds(Players[pid].data.mwTDM.spawnSeconds), "i", pid)
	
	tes3mp.StartTimer(timer)
end

function ResetCharacter(pid) -- Called from Methods.TeamHandler to reset characters for each new match
	-- Reset mwTDM info
	Players[pid].data.mwTDM.kills = 0
	Players[pid].data.mwTDM.deaths = 0
	Players[pid].data.mwTDM.spree = 0
	Players[pid].data.mwTDM.spawnSeconds = spawnTime
	
	-- Reset player level
	Players[pid].data.stats.level = playerLevel
	Players[pid].data.stats.levelProgress = 0
	
	-- Reset player attributes
    for name in pairs(Players[pid].data.attributes) do
        Players[pid].data.attributes[name] = playerAttributes
    end

	Players[pid].data.attributes.Speed = playerSpeed
	Players[pid].data.attributes.Luck = playerLuck
	
	-- Reset player skills
    for name in pairs(Players[pid].data.skills) do
        Players[pid].data.skills[name] = playerSkills
        Players[pid].data.skillProgress[name] = 0
    end

	if string.lower(mapRotation[mapRotationNum]) == "dagoth-ur" then
		Players[pid].data.skills.Acrobatics = 125
	else
		Players[pid].data.skills.Acrobatics = playerAcrobatics
	end
	
	Players[pid].data.skills.Marksman = playerMarksman
	
    for name in pairs(Players[pid].data.attributeSkillIncreases) do
        Players[pid].data.attributeSkillIncreases[name] = 0
    end

	-- Reset player stats
	Players[pid].data.stats.healthBase = playerHealth
	Players[pid].data.stats.healthCurrent = playerHealth
	Players[pid].data.stats.magickaBase = playerMagicka
	Players[pid].data.stats.magickaCurrent = playerMagicka
	Players[pid].data.stats.fatigueBase = playerFatigue
	Players[pid].data.stats.fatigueCurrent = playerFatigue
	
	-- Reload player with reset information
	Players[pid]:Save()
	Players[pid]:LoadLevel()
	Players[pid]:LoadAttributes()
	Players[pid]:LoadSkills()
	Players[pid]:LoadStatsDynamic()
end

function ScoreCheck(pid, teamNumber) -- Called from function OnPlayerDeath, checks whether team has won
	local message = ""
	
	if teamNumber == 1 then
		
		if teamOneScore == (scoreToWin - 5) then
			tes3mp.SendMessage(pid, color.Yellow .. "The " .. teamOne .. " need five kills to win!\n", true)
		end
	elseif teamNumber == 2 then
	
		if teamTwoScore == (scoreToWin - 5) then
			tes3mp.SendMessage(pid, color.Yellow .. "The " .. teamTwo .. " need five kills to win!\n", true)
		end
	end

	if teamOneScore >= scoreToWin or teamTwoScore >= scoreToWin then
		
		if teamOneScore >= scoreToWin then
			message = color.Yellow .. "The " .. teamOne .. " have won the game!\n\nStarting new match...\n"
		elseif teamTwoScore >= scoreToWin then
			message = color.Yellow .. "The " .. teamTwo .. " have won the game!\n\nStarting new match...\n"
		end
		
		tes3mp.SendMessage(pid, message, true)
		Methods.MatchInit()
	end
end

function TeamHandler(pid) -- Called from Methods.OnPlayerEndCharGen, Methods.OnGUIAction, and Methods.OnDeathTimeExpiration
	local teamOneCounter = 0
	local teamTwoCounter = 0
	
	JSONCheck(pid) -- Check if player has TDM info added to their JSON file
	
	tes3mp.LogMessage(2, "++++ Function TeamHandler: Checking matchId of player " .. Players[pid].data.login.name .. " against matchId #" .. matchId .. ". ++++")
	
	-- Check player's last matchId to determine whether to reset their character
	if Players[pid].data.mwTDM.matchId == matchId then
		tes3mp.LogMessage(2, "++++ Function TeamHandler: matchId is the same. ++++")
	else -- Player's latest match ID doesn't equal that of current match
	
		if Players[pid].data.mwTDM.matchId == nil then
			-- New character so no need to wipe it
		else -- Character was created prior to current match so we reset it
			tes3mp.LogMessage(2, "++++ Function TeamHandler: matchId is different -- Calling ResetCharacter(). ++++")
			ResetCharacter(pid) -- Reset character
		end
		
		tes3mp.LogMessage(2, "++++ Function TeamHandler: Assigning new matchId to player. ++++")
		Players[pid].data.mwTDM.matchId = matchId -- Set player's match ID to current match ID
	end
	
	-- Iterate through all players to get # of players on each team (when player joins match in progress)
    for pid, p in pairs(Players) do 
        
		tes3mp.LogMessage(2, "++++ Function TeamHandler: Counting # of players on each team. ++++")
		if p:IsLoggedIn() and p.data.mwTDM ~= nil then
			
			if p.data.mwTDM.team == 0 then
				-- Player is unassigned, so counter doesn't increase
			elseif p.data.mwTDM.team == 1 then
				tes3mp.LogMessage(2, "++++ Function TeamHandler: Adding player " .. p.data.login.name .. " to " .. teamOne .. ". ++++")
				teamOneCounter = teamOneCounter + 1
			else
				tes3mp.LogMessage(2, "++++ Function TeamHandler: Adding player " .. p.data.login.name .. " to " .. teamTwo .. ". ++++")
				teamTwoCounter = teamTwoCounter + 1
			end
        end
		
		tes3mp.LogMessage(2, "++++ Function TeamHandler: # of players on team one: " .. teamOneCounter .. " | # of players on team two: " .. teamTwoCounter .. " ++++")
    end
	
	local tempTeam = Players[pid].data.mwTDM.team
	
	-- Team assigning + auto-balancing checks
	if tempTeam == 0 then
		
		if ( teamOneCounter - teamTwoCounter ) < 1 then
			Players[pid].data.mwTDM.team = 1
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamOne .. ".\n", true)
		elseif ( teamOneCounter - teamTwoCounter ) >= 1 then
			Players[pid].data.mwTDM.team = 2
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamTwo .. ".\n", true)
		end
	elseif tempTeam == 1 then
		
		if ( teamOneCounter - teamTwoCounter ) > 1 then
			Players[pid].data.mwTDM.team = 2
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamTwo .. ".\n", true)
		end
	elseif tempTeam == 2 then
	
		if ( teamOneCounter - teamTwoCounter ) < -1 then
			Players[pid].data.mwTDM.team = 1
			tes3mp.SendMessage(pid, color.Gray .. Players[pid].data.login.name .. " is now on the " .. teamOne .. ".\n", true)
		end
	end
	
	TeamItems(pid)
end

function TeamItems(pid)
	local race = string.lower(Players[pid].data.character.race)

	tes3mp.LogMessage(2, "++++ Function TeamItems: Starting... ++++")
	Players[pid].data.inventory = {}
	Players[pid].data.equipment = {}
	
	if race ~= "argonian" and race ~= "khajiit" then
	
		if Players[pid].data.mwTDM.team == 1 then
			Players[pid].data.equipment[7] = { refId = teamOneUniform[3], count = 1, charge = -1 }
		elseif Players[pid].data.mwTDM.team == 2 then
			Players[pid].data.equipment[7] = { refId = teamTwoUniform[3], count = 1, charge = -1 }
		end
	end
	
	if Players[pid].data.mwTDM.team == 1 then
		Players[pid].data.equipment[8] = { refId = teamOneUniform[1], count = 1, charge = -1 }
		Players[pid].data.equipment[9] = { refId = teamOneUniform[2], count = 1, charge = -1 }
	elseif Players[pid].data.mwTDM.team == 2 then
		Players[pid].data.equipment[8] = { refId = teamTwoUniform[1], count = 1, charge = -1 }
		Players[pid].data.equipment[9] = { refId = teamTwoUniform[2], count = 1, charge = -1 }
	end
	
	if string.lower(playerEquipmentType) == "melee" then
		Players[pid].data.equipment[16] = { refId = playerEquipMelee[1][1], count = playerEquipMelee[1][2], charge = playerEquipMelee[1][3] }
		Players[pid].data.equipment[17] = { refId = playerEquipMelee[2][1], count = playerEquipMelee[2][2], charge = playerEquipMelee[2][3] }
	elseif string.lower(playerEquipmentType) == "ranged" then
		Players[pid].data.equipment[16] = { refId = playerEquipRanged[1][1], count = playerEquipRanged[1][2], charge = playerEquipRanged[1][3] }
		Players[pid].data.equipment[18] = { refId = playerEquipRanged[2][1], count = playerEquipRanged[2][2], charge = playerEquipRanged[2][3] }
	end
	
    for i,item in pairs(playerInventory) do
        local itemRef = { refId = item[1], count = item[2], charge = item[3] }
        table.insert(Players[pid].data.inventory, itemRef)
    end
	
	-- Players[pid]:Save() -- Why did I include this line?
	Players[pid]:LoadInventory()
	Players[pid]:LoadEquipment()
	
	TeamSpawner(pid)
end

function TeamSpawner(pid)
	math.random(1, 7) -- Improves RNG? LUA's random isn't great
	math.random(1, 7) 
	local rando = math.random(1, 7)
	
	local teamSpawnT = {}
	
	if string.lower(mapRotation[mapRotationNum]) == "ald-ruhn" then
	
		if Players[pid].data.mwTDM.team == 1 then
			teamSpawnT = mwTDMSpawns.aldruhn.teamOne
		elseif Players[pid].data.mwTDM.team == 2 then
			teamSpawnT = mwTDMSpawns.aldruhn.teamTwo
		end
	elseif string.lower(mapRotation[mapRotationNum]) == "balmora" then
		
		if Players[pid].data.mwTDM.team == 1 then
			teamSpawnT = mwTDMSpawns.balmora.teamOne
		elseif Players[pid].data.mwTDM.team == 2 then
			teamSpawnT = mwTDMSpawns.balmora.teamTwo
		end
	elseif string.lower(mapRotation[mapRotationNum]) == "dagoth-ur" then
		
		if Players[pid].data.mwTDM.team == 1 then
			teamSpawnT = mwTDMSpawns.dagothUr.teamOne
		elseif Players[pid].data.mwTDM.team == 2 then
			teamSpawnT = mwTDMSpawns.dagothUr.teamTwo
		end
	end
	
	if Players[pid].data.mwTDM.team == 1 then
		tes3mp.LogMessage(2, "++++ Spawning player at Team One spawnpoint #" .. rando .. " ++++")
	else
		tes3mp.LogMessage(2, "++++ Spawning player at Team Two spawnpoint #" .. rando .. " ++++")
	end
	tes3mp.SetCell(pid, teamSpawnT[rando][1])
	tes3mp.SendCell(pid)
	tes3mp.SetPos(pid, teamSpawnT[rando][2], teamSpawnT[rando][3], teamSpawnT[rando][4])
	tes3mp.SetRot(pid, 0, teamSpawnT[rando][5])
	tes3mp.SendPos(pid)
end

return Methods