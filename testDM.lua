
-- additional game modes by testman
-- v0.4
--
-- Many thanks to:
-- * mwTDM by Texafornian
-- * Atkana for so many LUA scipts that I could steal from
-- * David (inventory checker & general LUA-fu)
-- * ppsychrite (JSON scripting examples)

-- Ok, so how this thing works:
-- * this file and all relevant files go into server/scripts/custom/testDM
-- * "require("custom/testDM/testDM")" goes into customScripts.lua
-- this is the main file, it contains all the logic
-- testDMConfig.lua contains all the configuration and default values
-- testDMMaps.lua contains data about the locations where games are played
-- testDMMatchSettings.lua contains data and configuration about all possible matches.


--[[

I have insane amout of ideas about what could be implemented
Here is an attempt to list them all:
- implement voting for maps and/or game modes
- use urm's lobby
- use drop-on-death script
- make a lua file that contains map data
-- specific time of day and weather for each map
-- make timescale almost 0 so that skybox does not change
-- define in which cells players can move, block access to other cells
- implement deathmatch -- ALREADY DONE OLOLOLOLOLOLOL
- allow players to choose preferred outfit
- implement pickups that respawn after certain time
- implement visible status indicators
-- custom spells that have almost no effect but still have visible animation
-- custom spells that have no visible animation but can be used to indicate a state of the game in player's HUD
- make quick-slots pre-defined
- implement CTF
-- custom record for flag (warhammer with banner mesh)
-- make flags actually be "activated" instead of picked up, so that only players from opposite team can pick it up
-- 10pt light + 1pt fire/frost shield for flag holder
-- drop flag on death or disconnect
-- implement flag return mechanics (pick up by team, timer)
-- maybe red and blue lamp as a secondary objectives or even instead of flag
- implement option to choose between class-based match and everyone-has-the-same-stats match
- construct CTF-Face
- underwater daedric shrine map
- imlement assault game mode
- prevent players from interacting with most doors / contaimers
- implement custom records for doors / containers that players do have the ability to use
- disable manually dropping items
- disable unequipping items
- implement time limit
- implement CTF-matches where teams switch positions at halftime
- make admin command that forces next match
- make admin command that allows admin to choose the next match and then starts it
- Implement last-man-standing gamemode
-- implement score counting down istead of up for LMS mode
-- LMS with 1 life across whole map is basically battle royale 
- handle player disconnect (drop important items, refresh team member count)
- make players in deathmatch wear random clothes
- save player's deathmatch clothen
- allow players in Urm's lobby to change their clothes or even whole appearance


any ideas / help with implementation of those would be appreciated
]]

-- RANT: Can we please switch to Python? dudes who made LUA couldn't make a simple iteration over list work without complicating things.
-- Either we have to use indexes instead of values or we need to do some ipairs() wizardry to get value as variable :(
-- Also we can't var += 1 :(

-----------------------
-- DO-NOT-TOUCH SECTION
-----------------------

time = require("time")
--Ask David: Why do I need to write relative path here while other scripts are happy just with filename?
testDMConfig = require("custom/testDM/testDMConfig")
testDMmaps = require("custom/testDM/testDMMaps")
testDMMatchSettings = require("custom/testDM/testDMMatchSettings")

-- find a decent name for overall project
testDM = {}

-- TODO: find out if this is even legal
-- If it's illegal, then hide from David
config.customMenuIds.voteMenu = 9004

-- used for generation of random numbers
math.randomseed(os.time())

-- used to determine the way server handles the selection of next match
-- (0 = random, 1 = rotation, 2 = vote)
matchselectionmethod = testDMConfig.matchSelectionMethod

-- used as counter for match rotation
matchRotationIndex = 1

-- holds the data about the current match
currentMatch = testDMMatchSettings.balmora_dm

-- used to hold data about the next match
nextMatch = nil

-- unique identifier for match
matchId = nil

-- holdsthe list of all match-specific variables
matchSettings = nil

-- determines match mechanics
gameMode = nil

-- used to track the score for each team
teamScores = nil

-- used to track the number of players on each team
teamCounters = nil

-- tracks which player was the last one to get a score increase
lastScoringPlayer = nil

-- tracks which team was the last one to get a score increase
lastScoringTeam = nil


-- TODO: move to relevant files
-- >inb4 hurr global variables
--------------------------
-- CONFIG/SETTINGS SECTION
--------------------------
 
-- Determines whether the server follows a map rotation or not
-- (NOT IMPLEMENTED)
-- randomMaps = false

-- Number of kills required for either team to win
scoreLimit = 6

-- Determines whether players are allowed to manually switch teams
canSwitchTeams = true

-- Default spawn time in seconds
spawnTime = 5

-- Determines whether suicide & team-killing add spawn delay and its duration
addSpawnDelay = true
spawnDelay = 3

-- Names of the two teams
-- (Change "color.Blue" and "...Brown" in --ProcessDeath)
numberOfTeams = nil

-- Starting inventory items for both teams
-- (You can add as many items as you want; simply follow the format {"reference ID", count, charge})
playerInventory = {{"ingred_bread_01_UNI3", 1, -1}, {"steel shortsword", 1, -1}} 

-- Default stats for players
playerLevel = 1
playerAttributes = 75
playerSkills = 75
playerHealth = 15
playerMagicka = 50
playerFatigue = 300

-- These override the above values for more control over the pace of the game
playerLuck = 50
playerSpeed = 50
playerAcrobatics = 30 -- Ignored when playing the Dagoth-Ur map
playerMarksman = 150

-- TODO: implement sanity checking
-- TODO: find an elegant way of checking all these values. A list + for loop looks the best option for now
-- check if all variables and tables are of correct size / have corresponding elementes
-- otherwise warn server owner that something is wrong with configuration
-- TODO: should server just quit if incorrect value is found?
testDM.SanityCheck = function()
	
	-- check if all values in config file are fine
	-- TODO: find a proper name for this variable lol
	allIsFine = true

	-- values to be checked. List structure is {variable, comparisonOperation, expectedValue}
	local configChecks = {
	{testDMConfig.matchSelectionMethod, "<", 2} --,
	--{}
	}
	
	-- run the checks
	-- TODO: implement additional checks
	-- this would be more elegant if done with loadstring function
	for entryIndex=1,#configChecks do
		if configChecks[entryIndex][2] == "<" then
			if not (configChecks[entryIndex][1] < configChecks[entryIndex][3]) then
				allIsFine = false
			end 
		elseif configChecks[entryIndex][2] == ">" then
			if not (configChecks[entryIndex][1] > configChecks[entryIndex][3]) then
				allIsFine = false
			end 
		elseif configChecks[entryIndex][2] == "==" then
			if not (configChecks[entryIndex][1] == configChecks[entryIndex][3]) then
				allIsFine = false
			end 
		elseif configChecks[entryIndex][2] == "~=" then
			if not (configChecks[entryIndex][1] ~= configChecks[entryIndex][3]) then
				allIsFine = false
			end 
		end
	end
	
	-- check if there are all required variables set up for all the matches that are listed in config file
	for entryIndex=1,#testDMMatchSettings do
		-- check if match even has a human-readable name
		if testDMMatchSettings[entryIndex].name == nil then
			allIsFine = false
		end
		-- check if map that match intends to use is suitable for the intended number of teams
		if testDMMatchSettings[entryIndex].gameMode == "tdm" or testDMMatchSettings[entryIndex].gameMode == "ctf" then
			-- check if there are spawn locations designated for each team
			if #testDMMatchSettings[entryIndex].map.teamSpawnLocations < testDMMatchSettings[entryIndex].numberOfTeams then
				allIsFine = false
			end
			-- check if there is uniform for each team available
			if #testDMConfig.teamUniforms < testDMMatchSettings[entryIndex].numberOfTeams then
				allIsFine = false
			end
		end
	end


	if allIsFine == false then
		-- TODO: find a way to store the names of the values that did not pass the checks
		tes3mp.LogMessage(3, "WARNING: something seems to have an unexpected value. Check your configuration my dude.")
		-- TODO: find a way to stop the server the proper way
		tes3mp.quit()
	end
end


-- Starts the match with the currently existing configuration
-- This does not change any configuration. All the changes to configuration are done in EndMatch(), which gets called at the end of each match
testDM.MatchInit = function() -- Starts new match, resets matchId, controls map rotation, and clears teams

	matchId = os.date("%y%m%d%H%M%S") -- Later used in TeamHandler to determine whether to reset character
	
	if nextMatch ~= nil then
		currentMatch = nextMatch
	end


	-- Handle match data

	-- Load default settings
	matchSettings = testDMConfig.defaultSettings

	-- Check if any match settings override the default settings and apply them
	for key,value in pairs(matchSettings) do
		
		-- check if custom value exists
		if currentMatch[key] ~= nil then

			-- override the default value
			matchSettings[key] = currentMatch[key]
			
			tes3mp.LogMessage(2, "++++ Setting " .. key .. " to value " .. currentMatch[key] .. " ++++")
		end
	end

	-- set skybox and lighting
	tes3mp.SetHour(testDMConfig.timeOfDay)

	-- determine how fast skybox changes
	tes3mp.SetTimeScale(testDMConfig.timeScale)
	
	-- set game mode variable
	gameMode = currentMatch.gameMode
	
	-- reset match stats
	lastScoringPlayer = 0
	lastScoringTeam = 0

	-- if game mode is team-based, then handle team data
	if gameMode == "tdm" or gameMode == "ctf" then
		
		numberOfTeams = currentMatch.numberOfTeams

		-- reset team stats
		teamScores = {}
		teamCounters = {}
	
		for teamIndex=1,numberOfTeams do
			teamScores[teamIndex] = 0
			teamCounters[teamIndex] = 0
		end
		
	end
	
	--tes3mp.LogMessage(2, currentMatch.name)
	tes3mp.LogMessage(2, "++++ local MatchInit: Starting a new " .. currentMatch.name .. " match with ID " .. matchId .. " ++++")
	
	for pid, p in pairs(Players) do -- Iterate through all players and start assigning teams
		if p ~= nil and p:IsLoggedIn() then

			if p.data.mwTDM == nil then
				tes3mp.LogMessage(2, "++++ local MatchInit: Pre JSON Check ++++")
				testDM.JSONCheck(p.pid)
			end
			
			-- If player is alive, then begin reassign+respawn procedure
			if p.data.mwTDM.status == 1 then
				p.data.mwTDM.team = 0
				testDM.PlayerInit(p.pid)
				tes3mp.SendMessage(pid, color.Yellow .. "NEW ROUND: " .. currentMatch.name .. "\n", false)
			end
		end
	end
end

-- make player ready to be spawned in game
testDM.PlayerInit = function(pid)

	tes3mp.LogMessage(2, "++++ Initialising PID ", pid)
	
	testDM.JSONCheck(pid) -- Check if player has TDM info added to their JSON file -- from what I see in fuction, this doesn't just check, this makes sure that there is data to work with
	
	tes3mp.LogMessage(2, "++++ --PlayerInit: Checking matchId of player " .. Players[pid].data.login.name .. " against matchId #" .. matchId .. ". ++++")
	
	-- Check player's last matchId to determine whether to reset their character
	if Players[pid].data.mwTDM.matchId == matchId then
		tes3mp.LogMessage(2, "++++ --PlayerInit: matchId is the same. ++++")
	else -- Player's latest match ID doesn't equal that of current match
	
		if Players[pid].data.mwTDM.matchId == nil then
			-- New character so no need to wipe it
		else -- Character was created prior to current match so we reset it
			tes3mp.LogMessage(2, "++++ --PlayerInit: matchId is different -- Calling ResetCharacter(). ++++")
			testDM.ResetCharacter(pid) -- Reset character
		end
		
		tes3mp.LogMessage(2, "++++ --PlayerInit: Assigning new matchId to player. ++++")
		Players[pid].data.mwTDM.matchId = matchId -- Set player's match ID to current match ID

		-- handle team assigment only for the first time in a match (so that team-sorting logic does not happen at every respawn)
		if gameMode == "tdm" or gameMode == "ctf" then
			testDM.TeamHandler(pid)
		end
	end
	
	-- handle teams
	--if gameMode == "tdm" or gameMode == "ctf" then
	--	testDM.TeamHandler(pid)
	--end
	
	testDM.PlayerItems(pid)
	testDM.PlayerSpawner(pid)
end

-- display the state of the game appropriately for each game mode
testDM.ShowScore = function(pid)


	-- handle score display for deathmatch
	if gameMode ==  "dm" then

		local playerList = ""
		local newline = ""
		for pid, p in pairs(Players) do 
			if p:IsLoggedIn() and p.data.mwTDM ~= nil then
				tes3mp.LogMessage(2, "++++ local ShowScore: Adding player " .. p.data.login.name .. ". ++++")
				playerList = playerList .. newline .. p.data.login.name .. " | K: " .. p.data.mwTDM.kills .. " | D: " .. p.data.mwTDM.deaths
				-- this removes the leading newline for first entry but sets it for all following entries
				newline = "\n"
			end
		end
		tes3mp.MessageBox(pid, -1, playerList)

	-- handle score display for team deathmatch and capture the flag
	elseif gameMode == "tdm" or gameMode == "ctf" then

		-- clear values from previous lookup
		local teamLists = {}
		for teamIndex=1,numberOfTeams do
			teamLists[teamIndex] = 0
		end
		
		tes3mp.LogMessage(2, "++++ local ListTeams: Building list of teams + players. ++++")
		local teamList = ""
		
		for teamIndex=1,numberOfTeams do
			teamLists[teamIndex] = testDMConfig.teamColors[teamIndex] .. testDMConfig.teamNames[teamIndex] .. " (" .. teamCounters[teamIndex] .. ") " .. color.Yellow .."| Score: " .. teamScores[teamIndex]
			for pid, p in pairs(Players) do 
				
				if p:IsLoggedIn() and p.data.mwTDM ~= nil then
					
					if p.data.mwTDM.team == teamIndex then
						tes3mp.LogMessage(2, "++++ local ListTeams: Adding player " .. p.data.login.name .. " to " .. testDMConfig.teamNames[teamIndex] .. ". ++++")
						teamLists[teamIndex] = teamLists[teamIndex] .. "\n" .. p.data.login.name .. ": " .. p.data.mwTDM.kills
					end
				end
			end
			-- sup dawg, heard you like teams. And maybe some lists
			teamList = teamList .. teamLists[teamIndex]
			-- append seperator if there are more teams to be displayed
			if teamIndex ~= numberOfTeams then
				teamList = teamList .. "\n---------------\n"
			end
		end
		
		-- TODO: find better format to display teams
		-- the "list" interface would probably be better, as it can be easily closed instead of being displayed for a fixed amout of time
		tes3mp.MessageBox(pid, -1, teamList)
	end
end


testDM.OnDeathTimeExpiration = function(pid)
	--tes3mp.LogMessage(2, "++++ Got pid: ", pid)
	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		tes3mp.LogMessage(2, "++++ Respawning pid: ", pid)
		tes3mp.Resurrect(pid, 0)
		Players[pid].data.mwTDM.spawnSeconds = spawnTime
		Players[pid].data.mwTDM.status = 1 -- Player is now alive and safe for teleporting
		testDM.PlayerSpawner(pid)
		--testDM.PlayerInit(pid)
	end
end

testDM.OnPlayerCellChange = function(pid)

	if Players[pid] ~= nil and Players[pid]:IsLoggedIn() then
		testDM.CheckCell(pid)
		Players[pid]:SaveStatsDynamic()
		Players[pid]:Save()
	end
end

testDM.OnPlayerEndCharGen = function(pid)

	if Players[pid] ~= nil then
		tes3mp.LogMessage(2, "++++ Newly created: ", pid)
		testDM.EndCharGen(pid)
	end
end



-- TODO: make it so that function can take integer for switching to desired team
-- if no int is given, then switch player to team with next index
testDM.SwitchTeams = function(pid)
	
	if gameMode == "dm" then

		tes3mp.SendMessage(pid, color.Red .. "Curent game mode does not have teams. You are playing against everyone.\n", false)

	else
		if canSwitchTeams then
			
			-- move player to next team, or move player to first team if there are no next teams
			if Players[pid].data.mwTDM.team == numberOfTeams then
				Players[pid].data.mwTDM.team = 1
			else
				Players[pid].data.mwTDM.team = Players[pid].data.mwTDM.team + 1
			end
			
			local teamColor = testDMConfig.teamColors[Players[pid].data.mwTDM.team]
			tes3mp.SendMessage(pid, "" .. teamColor .. Players[pid].data.login.name .. color.Yellow .. " is now on " .. teamColor .. testDMConfig.teamNames[Players[pid].data.mwTDM.team] .. "\n", true)
			-- makes player respawn in order for team reasignment to take effect
			testDM.TeamItems(pid)
		else
			tes3mp.SendMessage(pid, color.Red .. "Changing teams is disabled on this server.\n", false)
		end
	end
end

-- TODO: does this even affect gameplay?
testDM.CheckCell = function(pid)
	cell = tes3mp.GetCell(pid)
	
	-- This might be unnecessary now
	if Players[pid].data.mapExplored == nil then
		Players[pid].data.mapExplored = {}
	end
	
	
	-- check if at least one of the cells is allowed
	--local cellIsAllowed = false
	--local usedCellCuunt = table.getn(testDMMaps[currentMap].usedcells)
	local usedCellCuunt = #testDMMatchSettings[currentMatch].map.usedcells
	for cellIndxe=1,usedCellCount do
		if cell == testDMMatchSettings[currentMatch].map.usedcells[cellIndex] then
			testDM.CellAllowed(pid, cell)
			return
		end
	end
	testDM.CellRestricted(pid, cell)
	
end


testDM.CellRestricted = function(pid, cell)
	prevPosX = tostring(tes3mp.GetPreviousCellPosX(pid))
	curPosX = tostring(tes3mp.GetPosX(pid))
	prevPosY = tostring(tes3mp.GetPreviousCellPosY(pid))
	curPosY = tostring(tes3mp.GetPosY(pid))
	prevPosZ = tostring(tes3mp.GetPreviousCellPosZ(pid))

	tes3mp.SetCell(pid, Players[pid].data.location.cell)
	tes3mp.SetPos(pid, prevPosX, prevPosY, prevPosZ)
	tes3mp.SendCell(pid)
	tes3mp.SendPos(pid)
end


testDM.CellAllowed = function(pid, cell)
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


testDM.EndCharGen = function(pid)
	Players[pid]:SaveLogin()
	Players[pid]:SaveCharacter()
	Players[pid]:SaveClass()
	Players[pid]:SaveStatsDynamic()
	Players[pid]:SaveEquipment()
	Players[pid]:SaveIpAddress()
	Players[pid]:CreateAccount()

	testDM.PlayerInit(pid)
end

-- Add TDM info to player JSON files if not present
testDM.JSONCheck = function(pid)
	tes3mp.LogMessage(2, "++++ --JSONCheck: Checking player JSON file for " .. Players[pid].data.login.name .. ". ++++")
	
	if Players[pid].data.mwTDM == nil then
		tdmInfo = {}
		tdmInfo.matchId = ""
		tdmInfo.status = 1 -- 1 = alive
		tdmInfo.team = 0
		tdmInfo.kills = 0
		tdmInfo.deaths = 0
		tdmInfo.spree = 0
		tdmInfo.spawnSeconds = spawnTime
		tdmInfo.totalKills = 0
		tdmInfo.totalDeaths = 0
		tdmInfo.DMOutfit = {} -- used to hold data about player's outfit in non-team games
		Players[pid].data.mwTDM = tdmInfo
		Players[pid]:Save()
	end
end

-- TODO: properly seperate handling for deathmatch and team deathmatch
-- Update player kills/deaths and team scores
testDM.ProcessDeath = function(pid)
	Players[pid].data.mwTDM.status = 0	-- Player is dead and not safe for teleporting
	Players[pid].data.mwTDM.deaths = Players[pid].data.mwTDM.deaths + 1
	Players[pid].data.mwTDM.totalDeaths = Players[pid].data.mwTDM.totalDeaths + 1
	Players[pid].data.mwTDM.spree = 0
	
	local deathReason = tes3mp.GetDeathReason(pid)
	
	-- Start with suicide / teamkill scenario. 
	-- This will get overriden in case player was killed by player of the opposite team
	local killerTeam = Players[pid].data.mwTDM.team

	-- determines if score should be increased or decreased
	local scoreChange = 0	
	local message = ""

	-- use silver (light grey) for names in deathmatch but then override this variable in case of team-based game mode
	local playerNameColor = color.Silver
	
	tes3mp.LogMessage(1, "Original death reason was " .. deathReason)

	if deathReason == Players[pid].data.login.name then
		-- leading space because this will be part of a constructed message
		deathReason = " committed suicide"
		Players[pid].data.mwTDM.kills = Players[pid].data.mwTDM.kills - 1
		scoreChange = -1
		
		if addSpawnDelay == true then
			Players[pid].data.mwTDM.spawnSeconds = Players[pid].data.mwTDM.spawnSeconds + spawnDelay
		end
	else
		local playerKiller = deathReason

		for pid2, player in pairs(Players) do
		
			if Players[pid2]:IsLoggedIn() and string.lower(playerKiller) == string.lower(player.name) then
				
				-- handle teamkilling (players are on same team)
				-- decrease player's tracked stats and set score of pid2's team to also decrease
				if (gameMode == "tdm" or gameMode == "ctf") and Players[pid].data.mwTDM.team == Players[pid2].data.mwTDM.team then
					-- should player's accumulated score in stat-tracking go down because of teamkill?
					--Players[pid2].data.mwTDM.totalKills = Players[pid2].data.mwTDM.totalKills - 1
					Players[pid2].data.mwTDM.spree = 0
					scoreChange = -1
					
					if addSpawnDelay == true then
						Players[pid2].data.mwTDM.spawnSeconds = Players[pid2].data.mwTDM.spawnSeconds + spawnDelay
					end
					playerNameColor = testDMConfig.teamColors[Players[pid].data.mwTDM.team]

				-- increase player's tracked stats and set score of pid2's team to increase
				else 
					Players[pid2].data.mwTDM.totalKills = Players[pid2].data.mwTDM.totalKills + 1
					Players[pid2].data.mwTDM.spree = Players[pid2].data.mwTDM.spree + 1
					killerTeam = Players[pid2].data.mwTDM.team
					scoreChange = 1
					
					-- make player's name appear in the color of his team
					if gameMode ~= "dm" then
						playerNameColor = testDMConfig.teamColors[Players[pid2].data.mwTDM.team]
					end
					
					
					if Players[pid2].data.mwTDM.spree == 3 then
						tes3mp.SendMessage(pid, color.GreenYellow .. Players[pid2].data.login.name .. " is on a killing spree!\n", true)
					end
					

				end

				-- leading space because this will be part of a constructed message
				deathReason = " was killed by " .. playerNameColor .. playerKiller
				
				-- apply score change to the player
				Players[pid2].data.mwTDM.kills = Players[pid2].data.mwTDM.kills + scoreChange
				
				break
			end
		end
	end
	
	-- player kills affect team score only in team deathmatch
	if gameMode == "tdm" then
		teamScores[killerTeam] = teamScores[killerTeam] + scoreChange
	end
	
	-- make player's name appear in the color of his team (this time for pid instead of pid2)
	-- this is not is the if statement above because this should also happen for other team-based game modes
	if gameMode ~= "dm" then
		playerNameColor = testDMConfig.teamColors[Players[pid].data.mwTDM.team]
	end
	message = "" .. playerNameColor .. Players[pid].data.login.name .. color.Yellow .. deathReason .. ".\n"
	tes3mp.SendMessage(pid, message, true)
	
	-- only check for victory conditions if score has gone up
	-- doing this within the above if statement would cause some duplicated code				
	if scoreChange == 1 then
		testDM.ScoreCheckOld(pid, killerTeam)
	end
		
	tes3mp.SendMessage(pid, color.Yellow .. "Respawning in " .. Players[pid].data.mwTDM.spawnSeconds .. " seconds...\n", false)
	
	timer = tes3mp.CreateTimerEx("OnDeathTimeExpiration", time.seconds(Players[pid].data.mwTDM.spawnSeconds), "i", pid)
	
	tes3mp.StartTimer(timer)
	
end

-- Called from local PlayerInit to reset characters for each new match
testDM.ResetCharacter = function(pid)
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


	Players[pid].data.skills.Acrobatics = playerAcrobatics

	
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


-- Called from OnPlayerDeath, checks whether victory condition was met and messages players about the state of the victory condition
testDM.ScoreCheckOld = function(pid, teamIndex)
	message = ""
	
	-- handle per-player scoring
	-- TODO: optimise this. Find a way to make just one check (ie. did the player who just killed this dude reach the score limit) instead of checking ALL the players if one of them reached a score limit.
	-- TODO: potential way of doing this is implementing global "lastScorePID" and "lastScoreTeam" to 
	if gameMode == "dm" then
		-- check if any of the players has won the game
		for pid2, player in pairs(Players) do
			if Players[pid2].data.mwTDM.kills >= scoreLimit then

				-- send message to allplayer about 
				message =  color.Yellow .. Players[pid2].data.login.name .. " has won the match!\n\nStarting new match...\n"
				tes3mp.SendMessage(pid, message, true)
				testDM.EndMatch()
			end
		end

	-- handle team-based scoring
	else
		-- check if team has score that triggers a server-wide message
		for i=1,#testDMConfig.scoreNotifications do
			if testDMConfig.scoreNotifications[i] == (scoreLimit - teamScores[teamIndex]) then
				-- grammer fix'z
				local plural = "s"
				if testDMConfig.scoreNotifications[i] == 1 then
					plural = ""
				end
				tes3mp.SendMessage(pid, color.Yellow .. "The " .. testDMConfig.teamNames[teamIndex] .. " needs ".. testDMConfig.scoreNotifications[i] .. " kill" .. plural .." to win!\n", true)
			end
		end

		-- check if either team has won the game
		if teamScores[teamIndex] >= scoreLimit then
			-- send message to player about 
			message =  color.Yellow .. "The " .. testDMConfig.teamColors[teamIndex] .. testDMConfig.teamNames[teamIndex] .. color.Yellow .. " won the game!\n\nStarting new match...\n"
			tes3mp.SendMessage(pid, message, true)
			testDM.EndMatch()
		end
	end
end

-- check if victory condition was reached
-- game-mode-agnositc
testDM.ScoreCheck = function(pid, teamIndex)
	
end

-- Called from local OnPlayerEndCharGen, local OnGUIAction, and local OnDeathTimeExpiration
testDM.TeamHandler = function(pid)
	tes3mp.LogMessage(2, "++++ Handling team for: ", pid)
	
	-- TODO: so this reset actually worked
	--teamCounters = {}
	--for teamIndex=1,numberOfTeams do
	--	teamCounters[teamIndex] = 0
	--end
	
	--[[
	testDM.JSONCheck(pid) -- Check if player has TDM info added to their JSON file -- from what I see in fuction, this doesn't just check, this makes sure that there is data to work with
	
	tes3mp.LogMessage(2, "++++ --TeamHandler: Checking matchId of player " .. Players[pid].data.login.name .. " against matchId #" .. matchId .. ". ++++")
	
	-- Check player's last matchId to determine whether to reset their character
	if Players[pid].data.mwTDM.matchId == matchId then
		tes3mp.LogMessage(2, "++++ --TeamHandler: matchId is the same. ++++")
	else -- Player's latest match ID doesn't equal that of current match
	
		if Players[pid].data.mwTDM.matchId == nil then
			-- New character so no need to wipe it
		else -- Character was created prior to current match so we reset it
			tes3mp.LogMessage(2, "++++ --TeamHandler: matchId is different -- Calling ResetCharacter(). ++++")
			testDM.ResetCharacter(pid) -- Reset character
		end
		
		tes3mp.LogMessage(2, "++++ --TeamHandler: Assigning new matchId to player. ++++")
		Players[pid].data.mwTDM.matchId = matchId -- Set player's match ID to current match ID
	end
	]]
	
	
	-- TODO: filter this for non-DM game modes
	-- TODO: why again are we calcuating teams from scratch every time this is called? Why not just make it go +1 / -1 at relevant events?
	
	-- Iterate through all players to get # of players on each team (when player joins match in progress)
	-- For now this will become the "join the team with least players regardless of what you have in data"
	-- TODO: restore the functionality of allowing player to join the team in player's data
	
	if Players[pid]:IsLoggedIn() and Players[pid].data.mwTDM ~= nil then
		
		if testDMConfig.ensureTeamBalance then
			-- team's current power level
			local lowestPlayerCount = 9001
			-- if there are no teams with less players than team 1, then add player to that team
			local lowestPlayerCountTeam = 1
			for teamIndex,playerCount in pairs(teamCounters) do
				if playerCount < lowestPlayerCount then
					lowestPlayerCount = playerCount
					lowestPlayerCountTeam = teamIndex
				end
			end
			
			tes3mp.LogMessage(2, "++++ --TeamHandler: Adding player " .. Players[pid].data.login.name .. " to " .. testDMConfig.teamNames[lowestPlayerCountTeam] .. ". ++++")
			Players[pid].data.mwTDM.team = lowestPlayerCountTeam
			teamCounters[lowestPlayerCountTeam] = teamCounters[lowestPlayerCountTeam] + 1
		end
	end
	
	local countLog = "++++ --TeamHandler: "
	for teamIndex=1,numberOfTeams do
		countLog = countLog .. "# of players on team " .. teamIndex .. ": " ..  teamCounters[teamIndex] .. " | "
	end
	tes3mp.LogMessage(2, countLog)
	
	testDM.TeamItems(pid)
end


testDM.PlayerItems = function(pid)
	race = string.lower(Players[pid].data.character.race)
	Players[pid].data.inventory = {}
	Players[pid].data.equipment = {}
	
	-- if match is not team based equip player with 
	if gameMode == "dm" or gameMode == "lms" then
		local DMOutfit = Players[pid].data.mwTDM.DMOutfit
		if #DMOutfit == 0 then
			-- assign new random outfit for player
			testDM.PlayerAssignRandomOutfit(pid)
		else
			-- In this case beast races should have DMOutfit with 2 elements while other races with 3 elements
			-- So for loop should assign thing nicely. If player with beast race has 3 elements here then something went wrong somewhere
			-- equipmentIndexList must me in that order because it was saved in that order in PlayerAssignRandomOutfit
			local equipmentIndexList = {8, 9, 7}
			for i=1,#DMOutfit do
				Players[pid].data.equipment[equipmentIndexList[i]] = { refId = DMOutfit[i], count = 1, charge = -1 }
			end
		end

		-- TODO: implement proper weapon selection
		Players[pid].data.equipment[16] = { refId = testDMConfig.playerEquipRanged[1][1], count = testDMConfig.playerEquipRanged[1][2], charge = testDMConfig.playerEquipRanged[1][3] }
		Players[pid].data.equipment[18] = { refId = testDMConfig.playerEquipRanged[2][1], count = testDMConfig.playerEquipRanged[2][2], charge = testDMConfig.playerEquipRanged[2][3] }

	elseif gameMode == "tdm" or gameMode == "ctf" then
		testDM.TeamItems(pid)
	end

	-- give items to player's inventory (will not be equipped)
	for i,item in pairs(matchSettings.playerInventory) do
		itemRef = { refId = item[1], count = item[2], charge = item[3] }
		table.insert(Players[pid].data.inventory, itemRef)
	end

	testDM.LoadPlayerItems(pid)
end

-- save changes and make items appear on player
testDM.LoadPlayerItems = function(pid)

	Players[pid]:Save()
	Players[pid]:LoadInventory()
	Players[pid]:LoadEquipment()

end

-- gives player new outfit
testDM.PlayerAssignRandomOutfit = function(pid)
	local randomOutfit = {} -- {shirt, pants, shoes}
	Players[pid].data.equipment[7] = nil
	Players[pid].data.equipment[8] = nil
	Players[pid].data.equipment[9] = nil

	-- equipmentIndexList needs to be in that order because LUA has no "continue" in for loops, so we need to use "break"
	-- and since "break" stops the whole loop, we want to do it after shirt and pants were already added
	local equipmentIndexList = {8, 9, 7}
	for i=1,3 do
		if (i == 3 and race == "argonian") or (i == 3 and race == "khajiit") then
			break
		end
		local randomIndex = math.random(1,#testDMConfig.possibleClothing[i])
		Players[pid].data.equipment[equipmentIndexList[i]] = { refId = testDMConfig.possibleClothing[i][randomIndex], count = 1, charge = -1 }
		randomOutfit[i] = testDMConfig.possibleClothing[i][randomIndex]	
	end
	
	Players[pid].data.mwTDM.DMOutfit = randomOutfit
	Players[pid]:Save()
end

testDM.TeamItems = function(pid)
	-- do we need this again? Should it be global variable? Is it global variable already?
	race = string.lower(Players[pid].data.character.race)

	tes3mp.LogMessage(2, "++++ --TeamItems: Starting... ++++")
	--Players[pid].data.inventory = {}
	--Players[pid].data.equipment = {}

	for teamIndex=1,numberOfTeams do
		if Players[pid].data.mwTDM.team == teamIndex then

			-- give non-beast races shoes / boots
			if race ~= "argonian" and race ~= "khajiit" then
				Players[pid].data.equipment[7] = { refId = testDMConfig.teamUniforms[teamIndex][3], count = 1, charge = -1 }
			end
			-- give shirt
			Players[pid].data.equipment[8] = { refId = testDMConfig.teamUniforms[teamIndex][1], count = 1, charge = -1 }
			--give pants
			Players[pid].data.equipment[9] = { refId = testDMConfig.teamUniforms[teamIndex][2], count = 1, charge = -1 }
			
			-- give equipment
			-- TODO: implement classes
			-- if playerClass = "ranged" then
			Players[pid].data.equipment[16] = { refId = testDMConfig.playerEquipRanged[1][1], count = testDMConfig.playerEquipRanged[1][2], charge = testDMConfig.playerEquipRanged[1][3] }
			Players[pid].data.equipment[18] = { refId = testDMConfig.playerEquipRanged[2][1], count = testDMConfig.playerEquipRanged[2][2], charge = testDMConfig.playerEquipRanged[2][3] }
		end
	end
	
	-- Players[pid]:Save() -- Why did I include this line? -- I don't know, why did you :^)
	--Players[pid]:LoadInventory()
	--Players[pid]:LoadEquipment()
	
	--testDM.PlayerSpawner(pid)
end

-- allows player to request new random outfit
testDM.PlayerRequestNewOutfit = function(pid)

	if gameMode == "dm" or gameMode == "lms" then
		testDM.PlayerAssignRandomOutfit(pid)
		testDM.LoadPlayerItems(pid)
		tes3mp.SendMessage(pid, color.Yellow .. "Hope you like your new look.\n", false)
	else
		tes3mp.SendMessage(pid, color.Red .. "You can not change your appearance in this game mode.\n", false)
	end

end

-- determines player's spawn location
testDM.PlayerSpawner = function(pid)
	math.random(1, 7) -- Improves RNG? LUA's random isn't great
	math.random(1, 7) 
	randomLocationIndex = math.random(1, 7)
	local possibleSpawnLocations = {}

	if gameMode == "dm" then
		-- spawns player in any of map's possible locations, regardless of which team it belongs to
		randomTeamIndex = math.random(1, 2)
		possibleSpawnLocations = currentMatch.map.teamSpawnLocations[randomTeamIndex]
		tes3mp.LogMessage(2, "++++ Spawning player at team ".. randomTeamIndex .. " spawnpoint #" .. randomLocationIndex .. " ++++")
	else
		-- find which team player belongs to and set spawn location to one of team's possible locations
		for teamIndex=1,numberOfTeams do
			if Players[pid].data.mwTDM.team == teamIndex then
				possibleSpawnLocations = currentMatch.map.teamSpawnLocations[teamIndex]
				tes3mp.LogMessage(2, "++++ Spawning player at team ".. teamIndex .. " spawnpoint #" .. randomLocationIndex .. " ++++")
			end
		end
	end
	
	tes3mp.SetCell(pid, possibleSpawnLocations[randomLocationIndex][1])
	tes3mp.SendCell(pid)
	tes3mp.SetPos(pid, possibleSpawnLocations[randomLocationIndex][2], possibleSpawnLocations[randomLocationIndex][3], possibleSpawnLocations[randomLocationIndex][4])
	tes3mp.SetRot(pid, 0, possibleSpawnLocations[randomLocationIndex][5])
	tes3mp.SendPos(pid)
end

-- this starts proces of determining variables for the next match
-- TODO: implement voting mechanic (for admin and for players)
-- TODO: figure out how to make this thing work with timer, so that players have 30 seconds to vote before next match starts
testDM.EndMatch = function()
	--voteTimer = tes3mp.CreateTimer("testDM.MatchInit", time.seconds(5))
	--tes3mp.StartTimer(voteTimer)

	-- determine which match will be played next round
	if testDMConfig.matchSelectionMethod == 0 then
		-- TODO: find a way to remove the possibility of repeating the just-played match
		randomMatchIndex = math.random(1, #testDMConfig.matchList)
		nextMatch = testDMConfig.matchList[randomMatchIndex]
	elseif testDMConfig.matchSelectionMethod == 1 then
		-- go to the first match if there are no further matches
		matchRotationIndex = matchRotationIndex + 1
		if matchRotationIndex == 0 or matchRotationIndex > #testDMConfig.matchList then
			matchRotationIndex = 1
		end
		local nextMatchIndex = testDMConfig.matchList[matchRotationIndex]
		nextMatch = testDMMatchSettings[nextMatchIndex]
	end
		
	testDM.MatchInit()
end

-- TODO: write help
testDM.ShowHelpDialog = function()
	
end

-- opens interface that allows admin to configure next match and then ends current match
testDM.AdminSetNextMatch = function(pid)
	-- if match in testDMConfig.matchList then
		-- yep, that's cool, nextMatch = match
	-- end
	testDM.EndMatch()
end

testDM.AdminEndMatch = function(pid)
	if Players[pid]:IsAdmin() then
		testDM.EndMatch()
	end
end


-- custom validators

customEventHooks.registerValidator("OnPlayerDeath", function(eventStatus, pid)
	-- this makes it so that default resurrect for player does not happen but custom handler for player death does get executed
	return customEventHooks.makeEventStatus(false,true)
end)

customEventHooks.registerValidator("OnDeathTimeExpiration", function(eventStatus, pid)
	-- this makes it so that default resurrect for player does not happen but custom handler for player death does get executed
	return customEventHooks.makeEventStatus(false,true)
end)


-- custom handlers

customEventHooks.registerHandler("OnServerPostInit", function()
	testDM.SanityCheck()
	testDM.MatchInit()
end)


customEventHooks.registerHandler("OnPlayerFinishLogin", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testDM.PlayerInit(pid)
	end
end)

customEventHooks.registerHandler("OnPlayerDeath", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testDM.ProcessDeath(pid)
	end
end)

customEventHooks.registerHandler("OnDeathTimeExpiration", function(eventStatus, pid)
	if eventStatus.validCustomHandlers then --check if some other script made this event obsolete
		testDM.OnDeathTimeExpiration(pid)
	end
end)



customEventHooks.registerHandler("OnPlayerEndCharGen", function(eventstatus, pid)
	if Players[pid] ~= nil then
		tes3mp.LogMessage(2, "++++ Newly created: ", pid)
		testDM.EndCharGen(pid)
	end
end)

customCommandHooks.registerCommand("forceend", testDM.AdminEndMatch)
customCommandHooks.registerCommand("switch", testDM.SwitchTeams)
customCommandHooks.registerCommand("score", testDM.ShowScore)
customCommandHooks.registerCommand("newoutfit", testDM.PlayerRequestNewOutfit)

--customCommandHooks.registerCommand("help", testDM.ShowHelpDialog)

return testDM
