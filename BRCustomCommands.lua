customCommandHooks.registerCommand("newmatch", brDebug.StartMatchProposal)
customCommandHooks.registerCommand("ready", lobbyLogic.PlayerConfirmParticipation)
customCommandHooks.registerCommand("forcestart", brDebug.StartMatch)
customCommandHooks.registerCommand("forcenextfog", matchLogic.ForceAdvanceZoneShrink)
customCommandHooks.registerCommand("forceend", brDebug.AdminEndMatch)
customCommandHooks.registerCommand("x", brDebug.QuickStart)
customCommandHooks.registerCommand("generatemaptiles", brDebug.GenerateMapTiles)
customCommandHooks.registerCommand("showzones", brDebug.ShowZones)
customCommandHooks.registerCommand("s", brDebug.ShowZones)
customCommandHooks.registerCommand("resetmaptiles", brDebug.ResetMapTiles)
customCommandHooks.registerCommand("debugmap", brDebug.DebugMapTiles)
