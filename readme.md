# Downgrade tool for Hogwarts Legacy

This repository contains a script that is used by Epic players to download an older version of Hogwarts Legacy, mainly to use the [HogWarp multiplayer mod](https://www.nexusmods.com/hogwartslegacy/mods/1378) during times when the latest version of the game is incompatible. 
The third party tool [legendary](https://github.com/derrod/legendary) is used.

# Usage

1. [Click here](https://github.com/Cyphs/EpicGamesDowngrader/blob/main/DowngradeEpic.ps1) and then click on the download button to Download raw file.
2. Save the ps1 file to any new folder.
3. Right-click on it and select "Run with PowerShell" then follow the prompts to login with Epic and download the older version to your game folder.



# Common issues

1. The script may instantly close.
   <br> Solution:
    - search powershell in your windows search bar and open it <br>
    - navigate to the folder the script is in, by doing for example ```cd downloads``` or ```cd desktop``` <br>
    - write ```Set-ExecutionPolicy Unrestricted -Scope Process``` and click enter <br>
    - write ```./DowngradeEpic.ps1``` and click enter <br>
2. Make sure your Epic Games account owns Hogwarts Legacy.

Thanks to [whichtwix](https://github.com/whichtwix) for helping and discovering that this is possible and to a user in the Heroic Games Discord which shared the manifest file we needed to downgrade to
