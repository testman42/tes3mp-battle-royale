# TES3MP Battle Royale Design Document

Terminology:
 - Fog - The area of the map that deals damage to players who are inside it. In other battle royale games it is called "Storm" (I had no better idea for how to call it.)
 - Damage level - Penalty that player receives for being outside of the safe zone. Penalty gets higher further away player is.
 - Zone - Group of cells that share the same damage level.
 - Safe zone - All the zones that do not have damage level yet.
 - Stage - Phase of process where safe zone shrinks over time. 
 - Border - A visual indicator of where the safe zone ends.
 - Air-drop - Process of spawning players high above the map and managing their stats / spells in a way that allows them to land safely on the ground.
 - Loot - items that spawn across the map at the start of the match

## Pre-match logic

Currently new match proposal is handled automatically.
Server checks how many players are on the server. If more than two, then it proposes a new match.
While in lobby, players can move around and also fight and kill each other without consequences.
Players who wish to join the match enter `/ready` command in chat window.
If more than two players are ready when match proposal ends, the match will start.
If match was not started, then server will propose new match.

## Match start logic

### Generate zones
Zones take a shape of [rasterised cirlce](https://en.wikipedia.org/wiki/Midpoint_circle_algorithm). Each subsequent zone is located entirely within the previous zone.
This is achieved by taking coordinates of previous zone centre and it's radius. Subtracting radius of next zone from the radius of current zone gives us a radius of the circle within which the centre of next zone can be located.
Process is repeated for each diameter given in the config file.
Config file takes diameter as opposed to radius because that way it's easier to visualise the size of the zone on the map.
### Spawn loot
Loot gets spawned according to the following parameters given in the config file:
 - Loot tables - contain items sorted into categories and further sorted into tiers of usefulness (1 to 4, higher is better)
 - Loot positions - contains coordinates and rotations of possible spawn positions. Sorted into categories and further into tiers (positions that can spawn highest tier are usually most difficult to reach)
 - Whether unique items are enabled - if yes, items that are considered unique can spawn, but only one instance.
### Spawn players
Position match participants high above the ground and start the process of "air drop".
Slowfall (5 pts) is enabled all the time during this process. In the first stage of air drop players get very increased speed, so that they can travel large distances during this time. In the second stage, player speed returns to default, but they still have slowfall enabled. After that stage slowfall gets disabled and process of airdrop is finished.
Timing is important here. Current configuration is set up so that speed is reset around the time any player would reach the top of Red Mountain and slowfall gets disabled shortly after any player would land in water.
### Start shrink timer
Start a timer for first zone shrink. Should give players enough time to explore and gather some gear.

## Logic during match
### Zone shrink logic
Process of zone shrink goes into next stage each time a timer for previous stage runs out.
Stage durations are determined by the values in the config file.
Each new stage makes the following occur:

 - Damage level update - The most outer zone that is still safe will become a "warning zone". The zone that is currently "warning zone" starts causing damage of level 1 to players that are still in it. Zones that are already dealing damage get their damage level increased, unless they are already at highest level. There are 3 damage levels, higher level deals more damage. 
 - Map update - Tiles that reflect the current state of the map get sent to participants.
 - Border update - If there are both fog and safe zone present, the border gets placed between them.
 - Informaton display - Messsage in text chat window informs players of new stage, the duration of said stage and how many players are still left in game.

### Player death
Participants leave a container with all their equipment in it when they die.
Each time a participant dies the server checks the number of remaining participants. If there is only one participant left, they are declared a winner and match is finished. Winning player gets moved to lobby as well and whole server is informed of their victory.
