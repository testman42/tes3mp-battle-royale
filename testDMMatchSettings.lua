
-- file that contains configuration for each possible match
-- variable names must be the same as in the testDMConfig.lua in order to take effect

-- 
-- name is human-readable description of match
-- gameMode tells testDM.lua how to handle game logic
-- map holds the map data from testDMMaps.lua
-- scoreLimit determines the score victory condition
-- defaultEquipment determines if players will start with default equipment or with 
-- additionalEquipment is a list of equipment to be added to player
-- itemsOnMap is a list of items that appear on map

testDMmaps = require("custom/testDM/testDMMaps")

testDMMatchSettings = {}

-- Ald-ruhn

-- deathmatch in Ald-ruhn
testDMMatchSettings.aldruhn_dm = {}
testDMMatchSettings.aldruhn_dm.name = "Ald-ruhn (deathmatch)"
testDMMatchSettings.aldruhn_dm.gameMode = "dm"
testDMMatchSettings.aldruhn_dm.map = testDMMaps.aldruhn
testDMMatchSettings.aldruhn_dm.scoreLimit = 10
testDMMatchSettings.aldruhn_dm.additionalEquipment = {}
testDMMatchSettings.aldruhn_dm.itemsOnMap = {}

-- deathmatch in Ald-ruhn
testDMMatchSettings.aldruhn_2t_tdm = {}
testDMMatchSettings.aldruhn_2t_tdm.name = "Ald-ruhn (team deathmatch, 2 teams)"
testDMMatchSettings.aldruhn_2t_tdm.gameMode = "tdm"
testDMMatchSettings.aldruhn_2t_tdm.numberOfTeams = 2
testDMMatchSettings.aldruhn_2t_tdm.map = testDMMaps.aldruhn
testDMMatchSettings.aldruhn_2t_tdm.scoreLimit = 15
testDMMatchSettings.aldruhn_2t_tdm.additionalEquipment = {}
testDMMatchSettings.aldruhn_2t_tdm.itemsOnMap = {}

-- deathmatch in Balmora
testDMMatchSettings.balmora_dm = {}
testDMMatchSettings.balmora_dm.name = "Balmora (deathmatch)"
testDMMatchSettings.balmora_dm.gameMode = "dm"
testDMMatchSettings.balmora_dm.map = testDMMaps.balmora
testDMMatchSettings.balmora_dm.scoreLimit = 10
testDMMatchSettings.balmora_dm.additionalEquipment = {}
testDMMatchSettings.balmora_dm.itemsOnMap = {}

-- team deathmatch with 2 teams in Balmora
testDMMatchSettings.balmora_2t_tdm = {}
testDMMatchSettings.balmora_2t_tdm.name = "Balmora (team deathmatch, 2 teams)"
testDMMatchSettings.balmora_2t_tdm.gameMode = "tdm"
testDMMatchSettings.balmora_2t_tdm.numberOfTeams = 2
testDMMatchSettings.balmora_2t_tdm.map = testDMMaps.balmora
testDMMatchSettings.balmora_2t_tdm.scoreLimit = 15

-- team deathmatch with 3 teams in Balmora
testDMMatchSettings.balmora_3t_tdm = {}
testDMMatchSettings.balmora_3t_tdm.name = "Balmora (team deathmatch, 3 teams)"
testDMMatchSettings.balmora_3t_tdm.gameMode = "tdm"
testDMMatchSettings.balmora_3t_tdm.numberOfTeams = 3
testDMMatchSettings.balmora_3t_tdm.map = testDMMaps.balmora
testDMMatchSettings.balmora_3t_tdm.scoreLimit = 15

-- capture the flag with 2 teams in balmora
testDMMatchSettings.balmora_2t_ctf = {}
testDMMatchSettings.balmora_2t_ctf.name = "Balmora (capture the flag, 2 teams)"
testDMMatchSettings.balmora_2t_ctf.gameMode = "ctf"
testDMMatchSettings.balmora_2t_ctf.numberOfTeams = 2
testDMMatchSettings.balmora_2t_ctf.map = testDMMaps.balmora
testDMMatchSettings.balmora_2t_ctf.scoreLimit = 3

-- last man standing in Balmora
testDMMatchSettings.balmora_lms = {}
testDMMatchSettings.balmora_lms.name = "Balmora (last man standing)"
testDMMatchSettings.balmora_lms.numberOfLives = 5

-- deathmatch in Dagoth Ur
testDMMatchSettings.dagothur_dm = {}
testDMMatchSettings.dagothur_dm.name = "Dagoth Ur (deathmatch)"
testDMMatchSettings.dagothur_dm.gameMode = "dm"
testDMMatchSettings.dagothur_dm.map = testDMMaps.dagothur
testDMMatchSettings.dagothur_dm.scoreLimit = 10
testDMMatchSettings.dagothur_dm.additionalEquipment = {}
testDMMatchSettings.dagothur_dm.itemsOnMap = {}

return testDMMatchSettings
