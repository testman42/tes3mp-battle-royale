
-- Battle Royale game mode by testman
-- debug module v0.6

debug = {}

-- ====================== UTILITY FUNCTIONS ======================

-- used to easily regulate the level of information when debugging
debug.Log = function(requiredDebugLevel, message)
	if brConfig.debugLevel >= requiredDebugLevel then
		tes3mp.LogMessage(2, message)
	end
end

-- used to easily regulate the level of information when debugging
debug.Message = function(requiredDebugLevel, pid, message)
	if brConfig.debugLevel >= requiredDebugLevel then
		tes3mp.SendMessage(pid, message, true)
	end
end

-- debug function
debug.QuickStart = function()
    debug.Log(2, "Doing QuickStart")
	if brConfig.debugLevel > 0 then
        for pid, player in pairs(Players) do
            if Players[pid]:IsLoggedIn() then
                lobbyLogic.PlayerConfirmParticipation(pid)
            end
        end		
		matchLogic.Start()
	end
end

-- Administrative function to forcefully end match
debug.AdminEndMatch = function(pid)
	if Players[pid]:IsAdmin() then
		testBR.EndMatch()
	end
end

-- force the next stage of shrinking process regardless of the remaining time
debug.ForceNextFog = function(pid)
	if #brConfig.stageDurations >= matchLogic.GetCurrentStage() + 1 then
		matchLogic.ForceAdvanceZoneShrink()
	end
end

-- used to manually clear map
debug.ShowZones = function(pid)
    if brConfig.debugLevel > 0 then
        mapLogic.GenerateZones()
        debug.ResetMapTiles(pid)
        mapLogic.ShowZones()
        playerLogic.SendMapToPlayer(pid)
    end
end

-- used to manually clear map
debug.ResetMapTiles = function(pid)
    if brConfig.debugLevel > 0 then
        mapLogic.ResetMapTiles()
        playerLogic.SendMapToPlayer(pid)
    end
end


return debug
