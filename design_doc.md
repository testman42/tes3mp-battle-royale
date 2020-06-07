Usually I like to plan out project development, but this time I went directly into the code and I got lost very quickly in a mess of concepts.
So with this we are taking a step back and defining some things that can help make sense of this mess of a code below.

Match start logic:

There are two stages of the lobby process.

First one is when there is nothing happening. Players are in the lobby, they can move around, also they can fight and kill each other without consequences.
They respawn in lobby if killed. At this stage, it is possible to initiate second stage.
The second stage is used to determine if match can be started and which players will be participating in said match.
The variable in the configuration section of this script determines if the players are in control of initiating the second stage or if it is controlled by server.
The second stage lasts for the determined amount of time and at the end of that period the server checks if criteria for start of the match is met.
Criteria 
If initiation of second stage is controlled by the server, then the stage starts as soon as the second player logs in.

maybe TODO: draw flowchart for this process using http://asciiflow.com/

Overall logic:

players spawn in lobby (currently modified ToddTest) by default, where they can sign up for next round and wait until it starts
once round starts, players get teleported to exterior, timers for parachuting logic and also timer for fog shrinking starts.
From that point on we differentiate between players in lobby and players in game. Well, players who are in lobby stay like they were and
players who are in round get to do battle royale stuff until they get killed or round ends. After that they get flagged as out of round and 
spawn in lobby with rest of players.

fog - the thing that battle royale games have. It shrinks over time and damages players who stand in it. Most other games call it "storm" if I am not mistaken.

fogGridLimits - an array that contains the bottom left (min X and min Y) and top right (max X and max Y) for each level

fog grid - Currently used logic is square-based, but same principle could easily work for other shapes, preferably circle (https://en.wikipedia.org/wiki/Midpoint_circle_algorithm)
Whole area gets segmented when the match starts, so that it doesn't have to determine each new zone when fog starts shrinking
Below example is for grid with 4 levels. Each time fog shrinks, it moves one level in. and all cells in that area start dealing damage to player

+------------------------------#
| 1                            |
|  +------------------#        |
|  | 2    +---------# |        |
|  |      | 3       | |        |
|  |      | +--#    | |        |
|  |      | | 4|    | |        |
|  |      | #--+    | |        |
|  |      #---------+ |        |
|  |                  |        |
|  |                  |        |
|  #------------------+        |
|                              |
|                              |
#------------------------------+
(# represents the coordinates that are saved in array, + and the lines are extrapolated from the given two cells)

fogZone - one set of cells. It is used to easily determine if cell that player entered should cause damage to player or not.
-- TODO: this needs to be renamed to "zone" or something like it, because overuse of the term "level" in this script is getting out of hand

fogStage - basically index of fog progress
