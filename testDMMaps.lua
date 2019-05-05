
-- file that contains data about maps and configuration of per-map mechanics
-- this file does NOT affect the way server selects map

-- TODO: describe data format
-- usedCells because it is possible that map contains a cell with no spawin points

testDMMaps = {}

testDMMaps.aldruhn = {}
testDMMaps.aldruhn.usedCells = {"-2, 7", "-2, 6"}
testDMMaps.aldruhn.teamSpawnLocations = {}
testDMMaps.aldruhn.teamSpawnLocations[1] = {
	{"-2, 7", -13092, 57668, 2593, 2.39}, 
	{"-2, 7", -12208, 57532, 2594, 3.11}, 
	{"-2, 7", -11638, 57629, 2593, -2.78}, 
	{"-2, 7", -11352, 56683, 2593, -2.26}, 
	{"-2, 7", -11798, 56952, 2586, -2.73}, 
	{"-2, 7", -12508, 56971, 2583, 3.11}, 
	{"-2, 7", -12970, 56871, 2588, 2.67}
}
testDMMaps.aldruhn.teamSpawnLocations[2] = {
	{"-2, 6", -15047, 51823, 2065, 0.72}, 
	{"-2, 6", -14996, 52449, 2065, 1.06}, 
	{"-2, 6", -14920, 52999, 2176, 1.87}, 
	{"-2, 6", -14301, 52838, 2167, 1.54}, 
	{"-2, 6", -13892, 52524, 2106, 1.21}, 
	{"-2, 6", -13124, 51895, 2111, -0.09}, 
	{"-2, 6", -13763, 51485, 2077, 0.45}
}

testDMMaps.balmora = {}
testDMMaps.balmora.usedCells = {"-3, -2", "-2, -2"}
testDMMaps.balmora.teamSpawnLocations = {}
testDMMaps.balmora.teamSpawnLocations[1] = {
	{"-3, -2", -23981, -15562, 505, -2.77}, 
	{"-3, -2", -24021, -14997, 521, 1.29}, 
	{"-3, -2", -23020, -14227, 505, 1.77}, 
	{"-3, -2", -22975, -13685, 872, 1.82}, 
	{"-3, -2", -23094, -13937, 872, 2.42}, 
	{"-3, -2", -24040, -16020, 505, 1.30}, 
	{"-3, -2", -23216, -16223, 505, 0.60}
}
testDMMaps.balmora.teamSpawnLocations[2] = {
	{"-2, -2", -15632, -15664, 409, -0.65}, 
	{"-2, -2", -15528, -15037, 409, -2.06}, 
	{"-2, -2", -15661, -13679, 401, -0.63}, 
	{"-2, -2", -15470, -12412, 760, -1.96}, 
	{"-2, -2", -15188, -14263, 698, -1.82}, 
	{"-2, -2", -15339, -12904, 401, -1.80}, 
	{"-2, -2", -16135, -14875, 611, -1.44}
}

testDMMaps.caldera = {}
testDMMaps.caldera.teamSpawnLocations = {}
testDMMaps.caldera.teamSpawnLocations[1] = {}
testDMMaps.caldera.teamSpawnLocations[2] = {}

testDMMaps.dagothur = {}
testDMMaps.dagothur.usedCells = {"Akulakhan's Chamber"}
testDMMaps.dagothur.teamSpawnLocations = {}
testDMMaps.dagothur.teamSpawnLocations[1] = { 
	{"Akulakhan's Chamber", 667, 1714, 1724, 0.29}, 
	{"Akulakhan's Chamber", -221, 1333, 1732, 0.31}, 
	{"Akulakhan's Chamber", -486, 1625, 1735, 0.46}, 
	{"Akulakhan's Chamber", 84, 1548, 1727, 0.90}, 
	{"Akulakhan's Chamber", 402, 1246, 1726, 0.38}, 
	{"Akulakhan's Chamber", -84, 1915, 1730, 0.70}, 
	{"Akulakhan's Chamber", -471, 1410, 1735, 0.56}
}
testDMMaps.dagothur.teamSpawnLocations[2] = {
	{"Akulakhan's Chamber", -3661, 6115, 1784, 2.13}, 
	{"Akulakhan's Chamber", -3945, 5559, 1784, 2.93}, 
	{"Akulakhan's Chamber", -3342, 6331, 1784, 1.81}, 
	{"Akulakhan's Chamber", -2890, 6476, 1785, 1.56}, 
	{"Akulakhan's Chamber", -2698, 6919, 1768, 1.52}, 
	{"Akulakhan's Chamber", -2384, 7127, 1762, 1.72}, 
	{"Akulakhan's Chamber", -3420, 6126, 1784, -2.90}
}

return testDMMaps
