# mwTDM
"Team Deathmatch" for TES3MP v0.6.1.

Lots of customizable settings are available; just open mwTDM.lua and look for **CONFIG/SETTINGS SECTION**.

**PLEASE NOTE**: Not *all* NPCs are properly deleted on map initialization, so admins might want to use the cell data in the **Cleared Cell Data** folder. Just place the files in .../mp-stuff/data/cell or .../PluginExamples/data/cell.
The first map in rotation will typically have all NPCs properly deleted.

# Commands
* /maps (see mwTDM.lua for map rotation options)
* /nextmap (admin-only)
* /restart (admin-only)
* /set equipment <ranged/melee> (admin-only)
* /set <spawnTime/health/magicka/fatigue/score/luck/speed/acrobatics/marksman> <number> (admin-only, requires /restart to take effect)
* /score
* /stats
* /switch
* /teams

# Installation
Download both mwTDM.lua & mwTDMSpawns.lua and place them in your .../mp-stuff/scripts/ (WINDOWS) or .../PluginExamples/scripts (LINUX PACKAGE) folder, then read both sections below.

# Changes to .../scripts/server.lua
Open the existing **server.lua** file in the same folder and make the following changes (use CTRL-F or something similar):

Find **function OnServerInit()** and change the following:
```
function OnServerInit()

    local version = tes3mp.GetServerVersion():split(".") -- for future versions

    if tes3mp.GetServerVersion() ~= "0.6.1" then
        tes3mp.LogMessage(3, "The server or script is outdated!")
        tes3mp.StopServer(1)
    end

    myMod.InitializeWorld()
    myMod.PushPlayerList(Players)

    LoadBanList()
    LoadPluginList()
end
```
to:
```
function OnServerInit()

    local version = tes3mp.GetServerVersion():split(".") -- for future versions

    if tes3mp.GetServerVersion() ~= "0.6.1" then
        tes3mp.LogMessage(3, "The server or script is outdated!")
        tes3mp.StopServer(1)
    end

    myMod.InitializeWorld()
    myMod.PushPlayerList(Players)

    LoadBanList()
    LoadPluginList()
	mwTDM.MatchInit()
end
```

Find **function OnPlayerDeath(pid)** and change the following:
```
	function OnPlayerDeath(pid)
		myMod.OnPlayerDeath(pid)
	end
```
to:
```
	function OnPlayerDeath(pid)
		mwTDM.OnPlayerDeath(pid)
		-- myMod.OnPlayerDeath(pid)
	end
```

Find **function OnDeathTimeExpiration(pid)** and change the following:
```
	function OnDeathTimeExpiration(pid)
		myMod.OnDeathTimeExpiration(pid)
	end
```
to:
```
	function OnDeathTimeExpiration(pid)
		mwTDM.OnDeathTimeExpiration(pid)
		-- myMod.OnDeathTimeExpiration(pid)
	end
```

Find **function OnGUIAction(pid, idGui, data)** and change the following:
```
	function OnGUIAction(pid, idGui, data)
		if myMod.OnGUIAction(pid, idGui, data) then return end -- if myMod.OnGUIAction is called
	end
```
to:
```
	function OnGUIAction(pid, idGui, data)
		if mwTDM.OnGUIAction(pid, idGui, data) then return end
		-- if myMod.OnGUIAction(pid, idGui, data) then return end -- if myMod.OnGUIAction is called
	end
```

Find **OnPlayerCellChange(pid)** and change the following:
```
	function OnPlayerCellChange(pid)
		myMod.OnPlayerCellChange(pid)
	end
```
to:
```
	function OnPlayerCellChange(pid)
		mwTDM.OnPlayerCellChange(pid)
		-- myMod.OnPlayerCellChange(pid)
	end
```

Find **OnPlayerEndCharGen(pid)** and change the following:
```
	function OnPlayerEndCharGen(pid)
		myMod.OnPlayerEndCharGen(pid)
	end
```
to:
```
	function OnPlayerEndCharGen(pid)
		mwTDM.OnPlayerEndCharGen(pid)
		-- myMod.OnPlayerEndCharGen(pid)
	end
```

Find the following block:
```
        elseif (cmd[1] == "greentext" or cmd[1] == "gt") and cmd[2] ~= nil then
            local message = myMod.GetChatName(pid) .. ": " .. color.GreenText .. ">" .. tableHelper.concatenateFromIndex(cmd, 2) .. "\n"
            tes3mp.SendMessage(pid, message, true)

        else
            local message = "Not a valid command. Type /help for more info.\n"
            tes3mp.SendMessage(pid, color.Error..message..color.Default, false)
        end
```
and change it to:
```
        elseif (cmd[1] == "greentext" or cmd[1] == "gt") and cmd[2] ~= nil then
            local message = myMod.GetChatName(pid) .. ": " .. color.GreenText .. ">" .. tableHelper.concatenateFromIndex(cmd, 2) .. "\n"
            tes3mp.SendMessage(pid, message, true)
			
		elseif string.lower(cmd[1]) == "set" and cmd[2] and cmd[3] ~= nil and admin then
			
			if type(tonumber(cmd[3])) ~= "number" then
				
				if string.lower(cmd[2]) == "equipment" then
			
					if string.lower(cmd[3]) == "melee" or string.lower(cmd[3]) == "ranged" then
						tes3mp.SendMessage(pid, color.Yellow .. "Changing default equipment type to " .. cmd[3] .."...\n", true)
						playerEquipmentType = cmd[3]
					end
				else
					local message = "Not valid. Are you inputting a string instead of a number? Or vice versa?\n"
					tes3mp.SendMessage(pid, color.Error..message..color.Default, false)
					return false
				end
			else
			
				if string.lower(cmd[2]) == "spawntime" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default spawn time to " .. cmd[3] .. " seconds...\n", true)
					spawnTime = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "health" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Health value to " .. cmd[3] .. "...\n", true)
					playerHealth = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "magicka" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Magicka value to " .. cmd[3] .. "...\n", true)
					playerMagicka = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "fatigue" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Fatigue value to " .. cmd[3] .. "...\n", true)
					playerFatigue = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "luck" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Luck value to " .. cmd[3] .. "...\n", true)
					playerLuck = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "speed" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Speed to " .. cmd[3] .. "...\n", true)
					playerSpeed = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "acrobatics" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Acrobatics level to " .. cmd[3] .. "...\n", true)
					playerAcrobatics = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "marksman" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing default Marksman level to " .. cmd[3] .. "...\n", true)
					playerMarksman = tonumber(cmd[3])
				elseif string.lower(cmd[2]) == "score" and cmd[3] ~= nil then
					tes3mp.SendMessage(pid, color.Yellow .. "Changing score to win to: " .. cmd[3] .."...\n", true)
					scoreToWin = tonumber(cmd[3])
				else
					local message = "Not valid. Are you inputting a string instead of a number? Or vice versa?\n"
					tes3mp.SendMessage(pid, color.Error..message..color.Default, false)
					return false
				end
			end
			
		elseif cmd[1] == "nextmap" and admin then
			tes3mp.SendMessage(pid, color.Yellow .. "Switching to the next map...\n", true)
			mwTDM.MatchInit()
		
		elseif cmd[1] == "restart" and admin then
			tes3mp.SendMessage(pid, color.Yellow .. "Restarting the current map...\n", true)
			mapRotationNum = mapRotationNum - 1
			mwTDM.MatchInit()
		
		elseif cmd[1] == "maps" then
			local maplist = ""
			
			for index,item in pairs(mapRotation) do
				maplist = maplist .. mapRotation[index] .. " "
			end
			
			tes3mp.SendMessage(pid, color.Yellow .. "MAP ROTATION: \n" .. maplist .. "\n", false)
			
		elseif cmd[1] == "score" then
			tes3mp.SendMessage(pid, color.Yellow .. "SCORES: \n" .. teamOne .. ": " .. teamOneScore .. "\n" .. teamTwo .. ": " .. teamTwoScore .. "\n", false)
		
		elseif cmd[1] == "stats" then
			tes3mp.SendMessage(pid, color.Yellow .. "YOUR STATS: \nKills: " .. Players[pid].data.mwTDM.kills .. " | Deaths: " .. Players[pid].data.mwTDM.deaths .. "\nLifetime Kills: " .. Players[pid].data.mwTDM.totalKills .. " | Lifetime Deaths " .. Players[pid].data.mwTDM.totalDeaths .. "\n", false)
		
		elseif cmd[1] == "switch" then
			mwTDM.SwitchTeams(pid)
		
		elseif cmd[1] == "teams" then
			mwTDM.ListTeams(pid)

        else
            local message = "Not a valid command. Type /help for more info.\n"
            tes3mp.SendMessage(pid, color.Error..message..color.Default, false)
        end
```

# Changes to .../scripts/cell/base.lua
Go to the folder "base" in the scripts folder then open the **base.lua** file. Make the following changes (use CTRL-F or something similar):

Find **function BaseCell:SaveActorList(pid)** and change the following:
```
function BaseCell:SaveActorList(pid)

    tes3mp.ReadLastActorList()
    tes3mp.LogMessage(1, "Saving ActorList from " .. myMod.GetChatName(pid) .. " about " .. self.description)

    for actorIndex = 0, tes3mp.GetActorListSize() - 1 do

        local refIndex = tes3mp.GetActorRefNumIndex(actorIndex) .. "-" .. tes3mp.GetActorMpNum(actorIndex)
        local refId = tes3mp.GetActorRefId(actorIndex)

        self:InitializeObjectData(refIndex, refId)
        tes3mp.LogAppend(1, "- " .. refIndex .. ", refId: " .. refId)

        tableHelper.insertValueIfMissing(self.data.packets.actorList, refIndex)
    end

    self:Save()

    self.isRequestingActorList = false
end
```
to:
```
function BaseCell:SaveActorList(pid)

    tes3mp.ReadLastActorList()
    tes3mp.LogMessage(1, "Saving ActorList from " .. myMod.GetChatName(pid) .. " about " .. self.description)

    for actorIndex = 0, tes3mp.GetActorListSize() - 1 do

        local refIndex = tes3mp.GetActorRefNumIndex(actorIndex) .. "-" .. tes3mp.GetActorMpNum(actorIndex)
        local refId = tes3mp.GetActorRefId(actorIndex)

        self:InitializeObjectData(refIndex, refId)
        tes3mp.LogAppend(1, "- " .. refIndex .. ", refId: " .. refId)

        tableHelper.insertValueIfMissing(self.data.packets.actorList, refIndex)
		
		for arrayIndex, refIndex in pairs(self.data.packets.actorList) do

			if tableHelper.containsValue(self.data.packets.delete, refIndex) == false then
				tes3mp.LogMessage(1, "++++ Deleting NPC with refIndex = " .. refIndex .. " ++++")
				table.insert(self.data.packets.delete, refIndex)
			end
		end

		for index, visitorPid in pairs(self.visitors) do
			self:SendObjectsDeleted(visitorPid)
		end
    end

    self:Save()

    self.isRequestingActorList = false
end
```