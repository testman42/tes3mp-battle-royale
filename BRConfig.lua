brConfig = {}

brConfig.scriptName = "TES3MP-Battle-Royale"

brConfig.defaultConfig = {
    
    debugLevel = 0,
    fogWarnFilePath = tes3mp.GetDataPath() .. "/map/fogwarn.png",
    fog1FilePath = tes3mp.GetDataPath() .. "/map/fog1.png",
    fog2FilePath = tes3mp.GetDataPath() .. "/map/fog2.png",
    fog3FilePath = tes3mp.GetDataPath() .. "/map/fog3.png",
    -- TODO: will this even work?
    fogFilePaths = {fogWarnFilePath, fog1FilePath, fog2FilePath, fog3FilePath},
    
    -- default stats for players
    defaultStats = {
        playerLevel = 1,
        playerAttributes = 80,
        playerSkills = 80,
        playerHealth = 200,
        playerMagicka = 100,
        playerFatigue = 300,
        playerLuck = 100,
        playerSpeed = 100,
        playerAcrobatics = 75,
        playerMarksman = 150
    },
    
    -- defines the type and size of each zone
    -- zones are either cell-based or geometry-based. 0 = cell, 1 = geo
    -- size of zone is *diameter* of the zone. One cell unit is 8192 geometry units {type, units}
    -- the last one has size of 0, which results in a single cell (provided cell-centre-based logic)
    zoneSizes = {{0, 14},{0,10},{0,6},{0,3},{0,1},{0,0}}
    
    

}

brConfig.config = DataManager.loadConfiguration(brConfig.scriptName, brConfig.defaultConfig)

-- print out a lot more messages about what script is doing
-- TODO: properly define debug levels
brConfig.debugLevel = 1

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
brConfig.fogWarnFilePath = tes3mp.GetDataPath() .. "/map/fogwarn.png"
brConfig.fog1FilePath = tes3mp.GetDataPath() .. "/map/fog1.png"
brConfig.fog2FilePath = tes3mp.GetDataPath() .. "/map/fog2.png"
brConfig.fog3FilePath = tes3mp.GetDataPath() .. "/map/fog3.png"
brConfig.fogFilePaths = {fogWarnFilePath, fog1FilePath, fog2FilePath, fog3FilePath}

-- default stats for players
brConfig.defaultStats = {
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


-- defines the type and size of each zone
-- zones are either cell-based or geometry-based. 0 = cell, 1 = geo
-- size of zone is *diameter* of the zone. One cell unit is 8192 geometry units {type, units}
-- the last one has size of 0, which results in a single cell (provided cell-centre-based logic)
brConfig.zoneSizes = {{0, 14},{0,10},{0,6},{0,3},{0,1},{0,0}}

-- Actual attempt
brConfig.stageDurations = {500, 400, 240, 120, 90, 60, 30, 30, 30, 0}
-- Debug durations, first one for automatic quick iteration, second one for manual control
--stageDurations = {10, 10, 10, 10, 10, 10, 10, 10, 10, 10}
--brConfig.stageDurations = {9000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 9000, 0}

-- determines the order of how levels increase damage
-- TODO: Would it make more sense to abandon this and instead map values to integers
-- have -1 be "nothing", 0 would be warning, and then positive integers
-- but that would make whole thing less customisable
-- let's keep it like this for now
brConfig.stageDamageLevels = {"warn", 1, 2, 3}

-- TODO: Deprecate
-- used to determine the cell span on which to use the fog logic
-- {{min_X, min_Y},{max_X, max_Y}}
brConfig.mapBorders = {{-15,-15}, {25,25}}


-- used to determine the centre cell for zone-generating logic
brConfig.mapCentre = {5,5}

-- used to determine how many cells away from centre does play area reach
brConfig.mapSize = 20

-- determines how the process for starting the match goes
-- if true, then server periodically proposes new match and starts it if criteria is met (just /ready)
-- if false, then players are in control of proposing a new match (/newmatch then /ready)
brConfig.automaticMatchmaking = true

-- how many seconds does match proposal last
--brConfig.matchProposalTime = 60
brConfig.matchProposalTime = 20

-- ID of the cell that is used for lobby
-- remember that this is case sensitive
brConfig.lobbyCell = "ToddTest"

-- position in lobby cell where player spawns
brConfig.lobbyCoordinates = {2177.776367, 653.002380, -184.874023}

-- how the shrinking zone is called in game
-- start with uppercase because it's at the start of the sentence
brConfig.fogName = "Blight storm" 
--fogName = "Blizzard"

-- how long does each stage last, in seconds
-- 15 is about how much time it takes to fall from spawn to the top of Red Mountain. 
-- 30 should be enough to fall to any ground safely
-- - apparenlty it is not because of some networking / performance thing. 40 should really be enough though
-- code assumes this config is valid, so don't mess it up
-- airDropStages[stage] = {duration, playerSpeed, enableSlowfall}
brConfig.airDropStages = {}
brConfig.airDropStages[1] = {25, 3000, true}
brConfig.airDropStages[2] = {40, -1, true}

-- loot tables
-- "loot tables" in vanilla game: https://en.uesp.net/wiki/Morrowind:Leveled_Lists
brConfig.lootTables = {
armor = {},
weapons = {},
potions = {},
scrolls = {},
ingredients = {}
}

brConfig.lootTables.armor[1] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
brConfig.lootTables.armor[2] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
brConfig.lootTables.armor[3] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
brConfig.lootTables.armor[4] = {"netch_leather_boiled_cuirass","netch_leather_cuirass", "chitin cuirass", "nordic_ringmail_cuirass", "bonemold_cuirass"}
brConfig.lootTables.weapons[1] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
brConfig.lootTables.weapons[2] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
brConfig.lootTables.weapons[3] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
brConfig.lootTables.weapons[4] = {"iron dagger", "iron flameblade", "silver staff", "silver vipersword", "steel katana", "silver sparkaxe"}
brConfig.lootTables.potions[1] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
brConfig.lootTables.potions[2] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
brConfig.lootTables.potions[3] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
brConfig.lootTables.potions[4] = {"p_restore_health_b", "p_feather_c", "p_frost_shield_c"}
brConfig.lootTables.scrolls[1] = {"sc_frostguard", "sc_firstbarrier"}
brConfig.lootTables.scrolls[2] = {"sc_frostguard", "sc_firstbarrier"}
brConfig.lootTables.scrolls[3] = {"sc_frostguard", "sc_firstbarrier"}
brConfig.lootTables.scrolls[4] = {"sc_frostguard", "sc_firstbarrier"}
brConfig.lootTables.ingredients[1] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
brConfig.lootTables.ingredients[2] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
brConfig.lootTables.ingredients[3] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}
brConfig.lootTables.ingredients[4] = {"ingred_bread_01", "ingred_bonemeal_01", "ingred_fire_salts_01"}


-- x, z, y so spawning function has to be adjusted
brConfig.lootSpawnLocations = {
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
{"7, 22", 61849.34765625, 255.99046325684, 182278.78125},
{"0, 14", 4626.0517578125, 1408.0218505859, 119571.8828125},
{"10, 14", 85083.53125, 2880.0217285156, 119760.7734375},
{"10, 14", 85832.0859375, 3449.5373535156, 117540.546875},
{"10, 1", 87194.7890625, 1080.2800292969, 14753.048828125},
{"10, 3", 86753.828125, 691.79339599609, 27729.44140625},
{"10, 4", 84277.7890625, 911.61804199219, 37115.34375},
{"-10, 9", -78044.2109375, 2258.2902832031, 76328.953125},
{"1, 0", 9721.9716796875, 1732.4459228516, 4565.2729492188},
{"-11, 11", -85084.1796875, 1567.6384277344, 96355.5625},
{"-11, 11", -87164.8671875, 1381.3288574219, 90736.1328125},
{"11, 14", 94923.4453125, 1708.6723632812, 115626.6328125},
{"-11, 15", -86263.2734375, 379.10455322266, 126823.3359375},
{"11, 16", 94940.484375, 839.20935058594, 133209.671875},
{"1, -13", 13103.549804688, 728.02185058594, -101753.7109375},
{"1, -13", 10591.33203125, 1330.3106689453, -100695.265625},
{"11, -5", 97481.765625, 7692.6323242188, -36582.2734375},
{"-1, 18", -4109.646484375, 2328.0217285156, 151715.234375},
{"12, 13", 99182.0859375, 740.09234619141, 114344.59375},
{"12, 13", 99306.3125, 400.69577026367, 113075.0390625},
{"1, 21", 12004.000976562, 1894.4530029297, 173421.09375},
{"12, -8", 104782.5, 1427.3609619141, -57674.57421875},
{"13, 14", 110121.9375, 384.31188964844, 119272.7109375},
{"13, 14", 108239.546875, 538.63916015625, 119698.0546875},
{"13, -1", 109572.078125, 552.02185058594, -3734.91796875},
{"13, -8", 110613.703125, 2048.0205078125, -62216.56640625},
{"13, -8", 106818.9375, 768.02185058594, -61923.95703125},
{"-1, -3", -5475.6279296875, 1081.1600341797, -19337.31640625},
{"-1, -3", -4281.4272460938, 1057.3898925781, -18196.736328125},
{"14, -13", 118970.40625, 289.11779785156, -102814.3828125},
{"14, -4", 114736.6796875, 6735.3979492188, -30178.232421875},
{"15, -13", 125841.9765625, 809.03942871094, -102468.0859375},
{"15, -13", 124877.7890625, 660.73724365234, -105489.953125},
{"15, 1", 125221.421875, 208.03457641602, 14846.461914062},
{"15, 5", 126861.8203125, 638.29418945312, 47447.85546875},
{"1, -5", 13980.947265625, 680.02185058594, -33181.9765625},
{"19, -4", 159159.09375, 4349.927734375, -28898.56640625},
{"-2, -10", -11293.911132812, 139.07205200195, -74209.2734375},
{"2, -13", 17976.40234375, 322.31060791016, -102003.0390625},
{"-2, 2", -11544.216796875, 1259.6948242188, 17644.41015625},
{"-2, 2", -11316.564453125, 1680.0218505859, 21162.345703125},
{"-2, 2", -8745.00390625, 1120.0218505859, 19635.12890625},
{"2, 4", 20679.322265625, 1264.0218505859, 39557.83203125},
{"2, 4", 20696.732421875, 1264.0218505859, 40445.16015625},
{"-2, 5", -13750.610351562, 2547.4348144531, 44132.70703125},
{"-2, 5", -13916.772460938, 2525.1730957031, 41651.5625},
{"-2, 6", -14714.905273438, 2064.0217285156, 52021.40625},
{"-2, 6", -12480.114257812, 2584.0217285156, 56731.9765625},
{"-2, 6", -8769.7685546875, 2760.0217285156, 55051.48046875},
{"2, -6", 20661.822265625, 709.99163818359, -43025.3515625},
{"2, -7", 20196.5, 648.02185058594, -53684.44921875},
{"2, 8", 19788.68359375, 11618.70703125, 69588.5703125},
{"2, 8", 20117.140625, 11596.4375, 69503.453125},
{"-3, 12", -22025.28515625, 2167.44140625, 104204.40625},
{"-3, 12", -19057.91796875, 2309.1696777344, 102971.71875},
{"3, 1", 27575.69140625, 691.66461181641, 11874.083984375},
{"3, 8", 25486.263671875, 14178.421875, 66704.265625},
{"4, -11", 40956.203125, 576.02185058594, -84434.078125},
{"-4, 18", -27897.521484375, 699.44299316406, 150345.265625},
{"4, -3", 37109.515625, 1374.0218505859, -20839.912109375},
{"5, 2", 44446.10546875, 1648.0218505859, 17965.19140625},
{"-5, -5", -35829.2734375, 1883.4163818359, -37046.3125},
{"-5, 9", -35692.71484375, 1744.0218505859, 79766.65625},
{"6, 18", 53309.18359375, 1780.42578125, 151967.4375},
{"-6, -1", -45308.41015625, 2304.0217285156, -4244.1899414062},
{"-6, -5", -46957.8671875, 216.12516784668, -37850.078125},
{"6, -7", 54344.46875, 1216.2891845703, -56075.5703125},
{"7, 2", 63797.51953125, 2753.4462890625, 23185.228515625},
{"-7, -5", -49338.59375, 68.534469604492, -39932.4765625},
{"7, 6", 58856.26171875, 1309.8502197266, 53344.9140625},
{"8, 0", 69316.296875, 1177.6519775391, 7013.9189453125},
{"8, 0", 68859.59375, 2053.212890625, 1801.1075439453},
{"-8, 16", -64678.3515625, 1045.9168701172, 135575.3125},
{"-8, 3", -60262.6015625, 208.84143066406, 26959.671875},
{"8, 5", 69492.359375, 1630.1107177734, 46688.23046875},
{"9, 0", 79764.9296875, 1194.8857421875, 1795.9587402344},
{"9, 10", 77181.2734375, 848.02185058594, 84885.5703125},
{"-9, 16", -67428.125, 139.75389099121, 139234.140625},
{"9, 2", 75223.6796875, 1888.0200195312, 18418.4140625},
{"-9, 4", -70712.8828125, 332.77035522461, 39130.1171875},
{"-9, 5", -67935.21875, 1728.0217285156, 47476.55859375},
{"9, 6", 76006.2578125, 1600.0218505859, 51942.7890625},
{"9, -7", 77170.859375, 1354.6248779297, -53641.90625},
{"0, 0", 983.84887695312, 391.35415649414, 2654.4116210938}, 
{"0, 0", 3683.7124023438, 786.45483398438, 4311.7827148438}, 
{"0, -2", 3152.4169921875, 3727.4130859375, -15420.609375}, 
{"0, 9", 1090.6829833984, 4432.6103515625, 80522.296875}, 
{"10, -4", 85433.6328125, 2006.0893554688, -28818.18359375}, 
{"1, 10", 9047.9609375, 10527.334960938, 86203.3828125}, 
{"11, -5", 93838.2421875, 6279.4536132812, -39302.46484375}, 
{"-1, -2", -2214.60546875, 2496.0200195312, -13477.768554688}, 
{"14, -7", 116492.65625, 1025.2457275391, -52447.76171875}, 
{"-1, 4", -4096.6967773438, 966.88684082031, 37524.83984375}, 
{"1, -5", 11363.657226562, 52.676551818848, -38391.60546875}, 
{"16, -2", 136294.203125, 1042.8221435547, -10694.607421875}, 
{"16, -6", 133498.625, 157.51359558105, -45795.37109375}, 
{"17, -3", 141671.46875, 145.46464538574, -19310.5}, 
{"17, -5", 142379.765625, 909.48718261719, -34999.94140625}, 
{"17, -5", 142630.875, 1494.6187744141, -33859.55078125}, 
{"17, -6", 142908.40625, 2544.5385742188, -44737.55859375}, 
{"19, -5", 160172.625, 81.737319946289, -36198.23828125}, 
{"19, -6", 157692.0625, 2224.4631347656, -44567.80078125}, 
{"-2, 10", -14549.290039062, 3805.0014648438, 83586.8046875}, 
{"2, -11", 24571.5625, 576.02191162109, -85885.9765625}, 
{"2, 11", 20960.923828125, 9566.875, 95987.2734375}, 
{"3, -11", 29804.3515625, 768.02185058594, -83255.7109375}, 
{"3, -12", 26073.453125, 576.02178955078, -93145.890625}, 
{"3, -14", 32688.65625, 1956.9766845703, -106785.7578125}, 
{"-3, 1", -22781.060546875, 948.79321289062, 9561.8291015625}, 
{"-3, 1", -23442.57421875, 1473.3894042969, 12223.057617188}, 
{"3, -3", 27255.7421875, 1042.9165039062, -19602.80859375}, 
{"3, -6", 29557.97265625, 693.03149414062, -46258.07421875}, 
{"3, -9", 31392.82421875, 910.31262207031, -72181.5234375}, 
{"4, -10", 35753.78515625, 84.775726318359, -74684.4375}, 
{"4, -12", 32784.1796875, 2048.0219726562, -92337.2734375}, 
{"4, -14", 32878.2890625, 1956.9766845703, -106775.828125}, 
{"4, 15", 37006.109375, 864.98571777344, 130225.234375}, 
{"4, 15", 35905.04296875, 872.02185058594, 129272.625}, 
{"4, -5", 34152.71875, 656.08093261719, -38287.59375}, 
{"4, -8", 37998.26171875, 129.49569702148, -57628.5546875}, 
{"5, 15", 45109.40625, 863.22045898438, 129768.5}, 
{"5, 15", 45012.96875, 1196.6385498047, 127782.1015625}, 
{"5, -3", 44413.9453125, 120.02185058594, -19126.873046875}, 
{"8, -4", 71175.84375, 763.47595214844, -31903.5546875}
}

return brConfig
