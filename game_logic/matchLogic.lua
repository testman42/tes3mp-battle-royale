matchLogic = {}

matchID = nil

-- indicates if there is currently an active match going on
matchInProgress = false

-- keep track of which players are in a match
-- used in actual match logic
playerList = {}

-- used to track the fog progress
-- 1 = no damage or warning zones
-- 2 = outside of zone 1 is warning
-- 3 = outside of zone 1 is damage level 1, zone 1 is warning
-- 4 = zone 2 is warning, zone 1 is damage level 1, outside is damage level 2
currentFogStage = 1

-- for warnings about time remaining until fog shrinks
fogShrinkRemainingTime = 0

-- used for handling the stages of player movement at the start of the match
airmode = 0

-- Used to initiate next step of the air-drop process
function HandleAirTimerTimeout()
    brDebug.Log(2, "AirTimer Timeout")
    matchLogic.HandleAirMode()
end

matchLogic.Start = function()
    matchID = os.time()
    matchInProgress = true
    tes3mp.LogMessage(2, "Starting a battle royale match with ID " .. tostring(matchID))
    tes3mp.SendMessage(0, "Match has started.\n", true)
    
    -- copy readylist into playerlist
    for key, value in pairs(lobbyLogic.GetReadyList()) do
        table.insert(playerList, value)
    end

    mapLogic.GenerateZones()

    matchLogic.StartZoneShrinkProcess()

    mapLogic.ResetMapTiles()

    mapLogic.SpawnLoot()

    brDebug.Log(2, "playerList has " .. tostring(#playerList) .. " PIDs in it")
    
    matchLogic.RemoveOfflinePlayersFromPlayerList()
    
    playerLogic.InitPlayers(playerList)

    -- has to be after for loop, otherwise PlayerInit resets the initial speed given by first stage of Airdrop
    matchLogic.StartAirdrop()
end

-- check if player is last one
-- this can be modified in case teams get implemented
matchLogic.CheckVictoryConditions = function()
    tes3mp.LogMessage(2, "Checking if victory conditions are met")
    brDebug.Log(1, "#playerList: " .. tostring(#playerList))
    
    -- TODO: find less barbaric way of getting table length
    remainingPlayers = 0
    for key, value in pairs(playerList) do
        if value then
            remainingPlayers = remainingPlayers + 1
        end
    end
    
	if remainingPlayers == 1 then
        matchLogic.End()
	end
end

matchLogic.End = function()
    tes3mp.LogMessage(2, "Ending match with ID " .. tostring(matchID))
    matchInProgress = false
    tes3mp.SendMessage(playerList[1], color.Yellow .. Players[playerList[1]].data.login.name .. " has won the match\n", true)
    tes3mp.MessageBox(playerList[1], -1, "Winner winner CHIM for dinner")
    Players[playerList[1]].data.BRinfo.wins = Players[playerList[1]].data.BRinfo.wins + 1
    -- respawn player in lobby
    playerLogic.PlayerInit(playerList[1], true)
    Players[playerList[1]]:Save()
    
    -- clear playerList only *after* all the player-relates stuff above is handled
    playerList = {}
    
    if brConfig.automaticMatchmaking then
        lobbyLogic.StartMatchProposal()
    end
end

matchLogic.IsMatchInProgress = function()
  return matchInProgress
end

matchLogic.IsPlayerInMatch = function(pid)
  return tableHelper.containsValue(playerList, pid)
end

matchLogic.RemovePlayerFromPlayerList = function(pid)
    --tablehelper does not work in this case, so we do it the barbaric way
    --tableHelper.removeValue(playerList, pid)
    for index, pidInList in ipairs(playerList) do
        if pidInList == pid then
            table.remove(playerList, index)
        end
    end
end

matchLogic.RemoveOfflinePlayersFromPlayerList = function()
    for index, pid in pairs(playerList) do
        if not Players[pid]:IsLoggedIn() then
            matchLogic.RemovePlayerFromPlayerList(pid)
        endis
    end
end

matchLogic.StartAirdrop = function()
    brDebug.Log(3, "Starting airdrop")
    airmode = 1
	matchLogic.HandleAirMode()
    tes3mp.SendMessage(playerList[1], "You have " .. tostring(brConfig.airDropStages[1][1]) .. " seconds of speed boost.\n", true)
end

matchLogic.HandleAirMode = function()
    if brConfig.airDropStages[airmode] and brConfig.airDropStages[airmode][1] then
        for _, pid in pairs(playerList) do
            if Players[pid]:IsLoggedIn() then
                playerLogic.SetAirMode(pid, airmode)
            end
        end
        if brConfig.airDropStages[airmode][1] ~= -1 then
            airTimer = tes3mp.CreateTimerEx("HandleAirTimerTimeout", time.seconds(brConfig.airDropStages[airmode][1]), "i", 1)
            tes3mp.StartTimer(airTimer)
        end
    else
        -- if there are no more stages, return players to default
        for _, pid in pairs(playerList) do
            if Players[pid]:IsLoggedIn() then
                playerLogic.SetSpeed(pid, -1)
                playerLogic.SetSlowFall(pid, false)
            end
        end
    end
    airmode = airmode + 1
end

matchLogic.StartZoneShrinkProcess = function()
    currentFogStage = 1
    matchLogic.StartZoneShrinkTimerForStage(currentFogStage)
end

matchLogic.StartZoneShrinkTimerForStage = function(stage)
    delay = brConfig.stageDurations[stage]
    if delay then
	    tes3mp.SendMessage(0, brConfig.fogName .. " will be shrinking in " .. tostring(delay) .. " seconds.\n", true)
	    fogTimer = tes3mp.CreateTimerEx("AdvanceZoneShrink", time.seconds(delay), "i", 1)
	    tes3mp.StartTimer(fogTimer)
    end
end


matchLogic.GetDamageLevelForZone = function(zone)
    damageLevel = brConfig.stageDamageLevels[currentFogStage-zone-1]
    if currentFogStage-zone-1 > #brConfig.stageDamageLevels then
        return 3
    end
    if damageLevel then
        return damageLevel
    end
end

matchLogic.GetDamageLevelForCell = function(x, y)
    zone = mapLogic.GetZoneForCell(x,y)
    return matchLogic.GetDamageLevelForZone(zone)
end

-- for debug purposes
matchLogic.ForceAdvanceZoneShrink = function()
    AdvanceZoneShrink()
end

matchLogic.GetCurrentStage = function()
    return currentFogStage
end

matchLogic.GetPlayerList = function()
  return playerList
end

matchLogic.PrintRemainingPlayers = function()
    
end

matchLogic.InformPlayersAboutStageProgress = function(pid, damageLevel)
    message = "Zone shrink stage " .. color.Yellow .. tostring(currentFogStage) .. 
        color.White .. "/" .. tostring(#brConfig.stageDurations) .. ". " .. color.Yellow .. 
        tostring(#playerList) .. color.White .. " players still alive.\n"
    tes3mp.SendMessage(playerList[1], message, true)
end

matchLogic.UpdateZoneBorder = function()
    
    if currentFogStage > 2 then
    
        mapLogic.RemoveCurrentBorder()
        
        mapLogic.PlaceBorderAroundZone(currentFogStage-2)
    
    end
    
end

-- TODO: fix this abomination, make it account for empty tables
matchLogic.GetRandomLoot = function(loot_type, loot_tier)
    if not loot_type then
        -- lol I'm sorry, I thought this was a decent programming language
        -- I miss Python
        --loot_type = math.random(#lootTables)
        loot_types = {"armor", "weapons", "potions", "scrolls", "ingredients"}
        loot_type = loot_types[math.random(1,5)]
    end

    if not loot_tier then
        brDebug.Log(3, "loot_type: " .. tostring(loot_type))
        loot_tier = math.random(1,#brConfig.lootTables[loot_type])
    end
    
    return brConfig.lootTables[loot_type][loot_tier][math.random(#brConfig.lootTables[loot_type][loot_tier])]
end

function AdvanceZoneShrink()
    
    currentFogStage = currentFogStage + 1
    
    matchLogic.InformPlayersAboutStageProgress()
    
    brDebug.Log(3, "Updating map")
    mapLogic.UpdateMap()
    
    brDebug.Log(3, "Updating zone border")
    matchLogic.UpdateZoneBorder()
    
    brDebug.Log(3, "Handling player stuff")
    for _, pid in pairs(playerList) do
		if Players[pid]:IsLoggedIn() then
			-- send new map state to player
			playerLogic.SendMapToPlayer(pid)
			-- apply fog effects to players in cells that are now in fog
			playerLogic.UpdateDamageLevel(pid)
		end
	end
    brDebug.Log(3, "Starting timer for next shrink")
    matchLogic.StartZoneShrinkTimerForStage(currentFogStage)
end

return matchLogic
