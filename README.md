# TES3MP Deathmatch
Deathmatch and Team Deathmatch for TES3MP 0.7.0-alpha.

Lots of customizable settings are available; just open testDM.lua and look for **CONFIG/SETTINGS SECTION**.

**PLEASE NOTE**: There's a possibility that not *all* NPCs will be properly deleted on map initialization, so admins might want to use the cell data in the **Cleared Cell Data** folder. Just place the files in `.../server/data/cell`.

# Demo
You can look for the server named "Deathmatch" in the server browser and connect to it to try this out and frag some n'wahs.

# Commands
* /newoutfit (changes your outfit in deathmatch)
* /switch (makes you switch teams in team deathmatch)
* /score (shows score)
* /forceend (admin-only command that forces next match to start)

# Installation
Create a directory named `testDM` in `/server/scripts/custom/`
Download all .lua files and place them in  `.../server/scripts/custom/testDM`
Edit `customScripts.lua` to include a following line:
```
require("custom/testDM/testDM")
```

# Thanks to
* Texafornian for making the initial TDM script and leaving it in the open for me to steal.
* David and Koncord for all the tech wizardry that was required to develop TES3MP.
* All OpenMW dudes for all the free and open source lines of code.
* My parents for all the food that I was able to steal from the refrigerator while writing this spaghetti code.
