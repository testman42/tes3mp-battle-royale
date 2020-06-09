mapLogic = {}

zoneAnchors = {}

mapLogic.DistanceBetweenPositions = function(x1, y1, x2, y2)
    return math.sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

-- TODO: rewrite this in a way that can generate hybrid zone array (cell-based + geometry-based)
mapLogic.GenerateZones = function()
    
    for zoneIndex, zoneParameters in pairs(brConfig.zoneSizes) do
        zoneAnchors[zoneIndex] = {}
        zoneRadius = zoneParameters[2]*4096
        if zoneIndex == 1 then
            previousAnchor = {brConfig.mapCentre[1]*8192+4096, brConfig.mapCentre[2]*8192+4096}
        else
            previousAnchor = zoneAnchors[zoneIndex-1]
        end
        
        random_x = math.random(-zoneRadius,zoneRadius)
        -- TODO: learn trigonometry instead of getting your bro Pythagoras to help you cheat
        random_y = (zoneRadius-math.abs(random_x))*math.random(-1,1)
        
        -- make it "snap to grid"
        random_x = random_x - math.fmod(random_x,8192)
        random_y = random_y - math.fmod(random_y,8192)
        
        zoneAnchors[zoneIndex][1] = previousAnchor[1] + random_x
        zoneAnchors[zoneIndex][2] = previousAnchor[2] + random_y
    end
end

mapLogic.GetCellForPosition = function(x, y)
    cell = {}
    cell[1] = math.floor(x/8192)
    cell[2] = math.floor(y/8192)
    return cell
end

-- returns the zone (index) of the smallest zone that cell belongs to
mapLogic.GetZoneForCell = function(x, y)
    -- to take centre of the cell. leave as 0 in order to work with bottom-left corner of the cell
    local centre = 4096
    local x_coordinates = x*8192+centre
    local y_coordinates = y*8192+centre
    local offset = 1000
    -- go through all zones in reverse
    for zone=#zoneAnchors, 1, -1 do
        if mapLogic.DistanceBetweenPositions(x_coordinates, y_coordinates, zoneAnchors[zone][1], zoneAnchors[zone][2]) < (brConfig.zoneSizes[zone][2])*8192+2048 then
            return zone
        end
        -- see if anchor is actually inside cell in question (makes the zones with size 0 still appear)
        anchorCell = mapLogic.GetCellForPosition(zoneAnchors[zone][1], zoneAnchors[zone][2])
        if anchorCell[1] == x and anchorCell[2] == y then
           return zone 
        end
    end
    
    -- cell is outside of the biggest zone
    return 0
end

-- returns all cells that are in zone
mapLogic.GetCellsInZone = function(zone)
    cellsInZone = {}
    brDebug.Log(1, "Getting cells for zone " .. tostring(zone))
    if zone == 0 then
        for x=brConfig.mapBorders[1][1],brConfig.mapBorders[2][1] do
            for y=brConfig.mapBorders[1][2],brConfig.mapBorders[2][2] do
                if mapLogic.GetZoneForCell(x, y) == zone then
                   table.insert(cellsInZone, {x, y}) 
                end
            end
        end
    elseif brConfig.zoneSizes[zone] then
        zoneCentre = mapLogic.GetCellForPosition(zoneAnchors[zone][1], zoneAnchors[zone][2])
        -- TODO: lolwait, am I scanning area 4x too large? Zone takes size as diameter, not as radius. Optimise this
        zoneAreaBottomLeftCorner = {zoneCentre[1]-brConfig.zoneSizes[zone][2], zoneCentre[2]-brConfig.zoneSizes[zone][2]}
        zoneAreaTopRightCorner = {zoneCentre[1]+brConfig.zoneSizes[zone][2], zoneCentre[2]+brConfig.zoneSizes[zone][2]}
        for x=zoneAreaBottomLeftCorner[1],zoneAreaTopRightCorner[1] do
            for y=zoneAreaBottomLeftCorner[2],zoneAreaTopRightCorner[2] do
                if mapLogic.GetZoneForCell(x, y) == zone then
                    table.insert(cellsInZone, {x, y})
                end
            end
        end
    end
    return cellsInZone
end



-- replace the current zone-marking tiles with the normal (vanilla) ones
mapLogic.ResetMapTiles = function(steps, delay)
	tes3mp.LogMessage(2, "Resetting map tiles")
	tes3mp.ClearMapChanges()

	for x=brConfig.mapBorders[1][1],brConfig.mapBorders[2][1] do
	    for y=brConfig.mapBorders[1][2],brConfig.mapBorders[2][2] do
            brDebug.Log(4, "Refreshing tile " .. x .. ", " .. y )
            filePath = tes3mp.GetDataPath() .. "/map/" .. x .. ", " .. y .. ".png"
            tes3mp.LoadMapTileImageFile(x, y, filePath)
        end
    end
end

-- replace the current zone-marking tiles with the normal (vanilla) ones
-- used for debug purposes
mapLogic.ShowZones = function()
	tes3mp.LogMessage(2, "Resetting map tiles")
	tes3mp.ClearMapChanges()
    
    for x=brConfig.mapBorders[1][1],brConfig.mapBorders[2][1] do
	    for y=brConfig.mapBorders[1][2],brConfig.mapBorders[2][2] do
            zone = mapLogic.GetZoneForCell(x, y)
            if zone > 0 then
                brDebug.Log(4, "Colouring tile " .. x .. ", " .. y )
                filePath = tes3mp.GetDataPath() .. "/map/fog" .. tostring(math.fmod(zone,3)+1) .. ".png"
                tes3mp.LoadMapTileImageFile(x, y, filePath)
            end
        end
    end
end

mapLogic.UpdateMap = function()
    
    tes3mp.ClearMapChanges()
    
    -- TODO: figure out how to limit this to just the zones that changed colour
    for zone=0,#zoneAnchors do
        zoneCells = mapLogic.GetCellsInZone(zone)
        brDebug.Log(3, "Got " .. tostring(#zoneCells) .. ", applying tiles")
        for index, cell in pairs(zoneCells) do
            newDamageLevel = matchLogic.GetDamageLevelForZone(zone)
            if newDamageLevel then --and matchLogic.GetDamageLevelForZone(zone-1) ~= then
                filePath = tes3mp.GetDataPath() .. "/map/fog" .. matchLogic.GetDamageLevelForZone(zone) .. ".png"
                tes3mp.LoadMapTileImageFile(cell[1], cell[2], filePath)
            end
        end
        brDebug.Log(4, "Tiles applied")
    end
    
end

mapLogic.PlaceBorderAroundZone = function(zone)
    
        --mapLogic.PlaceCellBorders(x, y, true, false, false, false)
    
    zoneCells = mapLogic.GetCellsInZone(zone)
    
    -- TODO: find something better than this very ugly barbaric way of converting zone to array

    mappedX = {}
    mappedY = {}
    
    for index, cell in pairs(zoneCells) do
        
        -- this should result in an array where indexes are x coordinate and value is table with all y coords in that row
        -- create row if it does not exist yet
        if not mappedX[cell[1]] then
            mappedX[cell[1]] = {}
        end
        table.insert(mappedX[cell[1]], cell[2])
        
        -- repeat for y
        if not mappedY[cell[2]] then
            mappedY[cell[2]] = {}
        end
        table.insert(mappedY[cell[2]], cell[1])
        
    end
    
    for x, y_list in pairs(mappedX) do
        brDebug.Log(3, "Borders on X "..tostring(x)..": min=" .. tostring(math.min(unpack(y_list))) .. ", max=" .. tostring(math.max(unpack(y_list))))
        -- place bottom borders
        mapLogic.PlaceCellBorders(x, math.min(unpack(y_list)), false, true, false, false)
        -- place top borders
        mapLogic.PlaceCellBorders(x, math.max(unpack(y_list)), true, false, false, false)
    end
    
    for y, x_list in pairs(mappedY) do
        brDebug.Log(3, "Borders on Y "..tostring(y)..": min=" .. tostring(math.min(unpack(x_list))) .. ", max=" .. tostring(math.max(unpack(x_list))))
        -- place left borders
        mapLogic.PlaceCellBorders(math.min(unpack(x_list)), y, false, false, true, false)
        -- place right borders
        mapLogic.PlaceCellBorders(math.max(unpack(x_list)), y, false, false, false, true)
    end
end

mapLogic.RemoveCurrentBorder = function()
    
    if #testBR.trackedObjects["cellBorderObjects"] > 0 then
        for index, entry in pairs(testBR.trackedObjects["cellBorderObjects"]) do
            mapLogic.DeleteObject(testBR.trackedObjects["cellBorderObjects"][index][1], testBR.trackedObjects["cellBorderObjects"][index][2])
        end
    end
end

-- sets border at cell edge if given true
-- TODO: use the enumeration instead of 4 booleans
mapLogic.PlaceCellBorders = function(cell_x, cell_y, top, bottom, left, right)
    if top then
        mapLogic.PlaceBorderBetweenCells(cell_x, cell_y, cell_x, cell_y+1)
    end
    if bottom then
        mapLogic.PlaceBorderBetweenCells(cell_x, cell_y, cell_x, cell_y-1)
    end
    if left then
        mapLogic.PlaceBorderBetweenCells(cell_x, cell_y, cell_x-1, cell_y)
    end
    if right then
        mapLogic.PlaceBorderBetweenCells(cell_x, cell_y, cell_x+1, cell_y)
    end
end

mapLogic.PlaceBorderBetweenCells = function(cell1_x, cell1_y, cell2_x, cell2_y)
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
    
    brDebug.Log(3, "Finding host cell for border between " .. tostring(cell1_x) .. ", " .. tostring(cell1_y) .. " and " .. tostring(cell2_x) .. ", " .. tostring(cell2_y))
    
    local host_cell = nil

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
    
    mapLogic.PlaceObject("fog_border", host_cell_string, x_coordinate, y_coordinate, 4200, 0, 3.14159, rotation, 2.677, testBR.trackedObjects["cellBorderObjects"])
end

-- used for pseudo-statics. For spawning items use mapLogic.PlaceItem, as items require more parameters
mapLogic.PlaceObject = function(object_id, cell, x, y, z, rot_x, rot_y, rot_z, scale, list)
	brDebug.Log(3, "Placing object " .. tostring(object_id) .. " in cell " .. tostring(cell))
    brDebug.Log(3, "x: " .. tostring(x) .. ", y: " .. tostring(y) .. ", z: " .. tostring(z))
	local mpNum = WorldInstance:GetCurrentMpNum() + 1
	local refId = object_id
    local location = {posX = x, posY = y, posZ = z, rotX = rot_x, rotY = rot_y, rotZ = rot_z}
	local refIndex =  0 .. "-" .. mpNum
	
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
	brDebug.Log(2, "Sending object info to players")
	for index, onlinePid in pairs(matchLogic.GetPlayerList()) do
		if Players[onlinePid]:IsLoggedIn() then
			tes3mp.InitializeEvent(onlinePid)
			tes3mp.SetEventCell(cell)
			tes3mp.SetObjectRefId(refId)
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

mapLogic.SpawnLoot = function()
    for _, entry in pairs(brConfig.lootSpawnLocations) do
        -- adjusted for X, Z, Y
        mapLogic.SpawnLootAroundPosition(entry[1], entry[2], entry[4], entry[3], 0)
    end
end

mapLogic.SpawnLootContainerAtPosition = function(cell, x, y, z, rot_z, lootType, lootTier)
    
end

mapLogic.SpawnLootAroundPosition = function(cell, x, y, z, rot_z, lootType, lootTier)
    local amount_of_loot = math.random(4,8)
    local spacing = 50
    local x_offset = 0
    local y_offset = 0
    for i=1,amount_of_loot do
        local object_id = matchLogic.GetRandomLoot()
        mapLogic.PlaceItem(object_id, cell, x+x_offset*spacing, y+y_offset*spacing, z+10, rot_z, testBR.trackedObjects["spawnedItems"], 1, -1)
        x_offset = x_offset + 1
        if x_offset > 3 then
            x_offset = 0
            y_offset = y_offset + 1
        end
    end
   
end

mapLogic.PlaceItem = function(object_id, cell, x, y, z, rot_z, list, item_count, item_charge)
    brDebug.Log(3, "Placing item " .. tostring(object_id) .. " in cell " .. tostring(cell))
    brDebug.Log(3, "x: " .. tostring(x) .. ", y: " .. tostring(y) .. ", z: " .. tostring(z))
	local mpNum = WorldInstance:GetCurrentMpNum() + 1
	local refId = object_id
    local location = {posX = x, posY = y, posZ = z, rotX = 0, rotY = 0, rotZ = rot_z}
	local refIndex =  0 .. "-" .. mpNum
	
	WorldInstance:SetCurrentMpNum(mpNum)
	tes3mp.SetCurrentMpNum(mpNum)

	if LoadedCells[cell] == nil then
		logicHandler.LoadCell(cell)
	end
	LoadedCells[cell]:InitializeObjectData(refIndex, refId)
	LoadedCells[cell].data.objectData[refIndex].location = location
	table.insert(LoadedCells[cell].data.packets.place, refIndex)

    -- add object to the list
    -- this is basically used just to track instances of fog_border
    if list then
        entry = {cell, refIndex}
        table.insert(list, entry)
    end

    -- TODO: ask David about networking. Do we have to send one package for each object placement
    -- or can that be grouped together in some way.
	brDebug.Log(2, "Sending spawned item info to players")
	for index, onlinePid in pairs(matchLogic.GetPlayerList()) do
		if Players[onlinePid]:IsLoggedIn() then
			tes3mp.InitializeEvent(onlinePid)
			tes3mp.SetEventCell(cell)
			tes3mp.SetObjectRefId(refId)
            tes3mp.SetObjectCount(item_count)
            tes3mp.SetObjectCharge(item_charge)
            tes3mp.SetObjectEnchantmentCharge(item_charge)
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

mapLogic.DeleteObject = function(cellName, objectUniqueIndex)
    if cellName and LoadedCells[cellName] then
        LoadedCells[cellName]:DeleteObjectData(objectUniqueIndex)
        logicHandler.DeleteObjectForEveryone(cellName, objectUniqueIndex)
    end
end

-- TODO: implement this after implementing chests / drop-on-death
mapLogic.ResetWorld = function()

    -- removes the last active border
    mapLogic.RemoveCurrentBorder()

    --cleans up items
    --testBR.RemoveAllItems()
    --testBR.ResetCells()
    --testBR.ResetTimeOfDay()
    --testBR.ResetWeather()

    -- TODO: would this be more elegant with functions or is it fine to just brute-force through the list?
    for _, category in pairs(testBR.trackedObjects) do
        for _, list in pairs(category) do
            for index, entry in pairs(list) do
                mapLogic.DeleteObject(entry[1], entry[2])
            end
        end
    end
    
end


-- checks if player is allowed to be in the cell
mapLogic.ValidateCell = function(pid)
    
    brDebug.Log(4, "Checking if PID " .. tostring(pid) .. " is allowed to be in the cell.")
    
    cell = tes3mp.GetCell(pid)

	-- allow player to spawn in lobby	
	if cell == PlayerLobby.config.cell then
		return true
	end

    if not mapLogic.IsCellExternal(cell) then
		tes3mp.LogMessage(2, "Cell is not external and can not be entered")
		Players[pid].data.location.posX = tes3mp.GetPreviousCellPosX(pid)
		Players[pid].data.location.posY = tes3mp.GetPreviousCellPosY(pid)
		Players[pid].data.location.posZ = tes3mp.GetPreviousCellPosZ(pid)
        Players[pid]:LoadCell()
        return false
    end
    
    return true
end

-- check if cell is external
mapLogic.IsCellExternal = function(cell)
    brDebug.Log(3, "Checking if the cell (" .. cell .. ") is external.")
	_, _, cellX, cellY = string.find(cell, patterns.exteriorCell)
    brDebug.Log(3, "cellX: " .. tostring(cellX) .. ", cellY: " .. tostring(cellY))
    if cellX == nil or cellY == nil then
        return false
    end
    return true
end

return mapLogic