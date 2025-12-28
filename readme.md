# Downgrade tool for Hogwarts Legacy

This repository contains a PowerShell script that is used by Epic players to download an older version of Hogwarts Legacy, mainly to use the [HogWarp multiplayer mod](https://www.nexusmods.com/hogwartslegacy/mods/1378) during times when the latest version of the game is incompatible. 
The third party tool [legendary](https://github.com/derrod/legendary) is used.

The version of the game that this script is currently downloading is `1420267` from the manifest archive [located here](https://github.com/Cyphs/egs-manifests).

After the script downloads the game, a quick way to check, is by opening the `DA_Version.txt` file in "`\HogwartsLegacy\Phoenix\Content\Data\Version`"

# Usage

1. [Click here](https://github.com/Cyphs/EpicGamesDowngrader/blob/main/DowngradeEpic.ps1) and then click on the download button to Download raw file.
2. Save the ps1 file to any new folder.
3. Right-click on it and select "Run with PowerShell" then follow the prompts to login with Epic and download the older version to your game folder.

Video here if needed: https://www.youtube.com/watch?v=c_4zX11z8d4


# Common issues

1. Try moving the ps1 file to a different location.

2. The script may instantly close due to execution-policy blocking or antivirus software.
   <br> Solution:
    - Search powershell in your windows search bar and open it <br>
    - Navigate to the folder the script is in, by doing for example: ```cd downloads``` or ```cd desktop``` <br>
      - You can also hold the Shift key and right-click into empty space of the File Explorer window, then click "Open PowerShell window here"
    - Type ```powershell -NoProfile -ExecutionPolicy Bypass -File .\DowngradeEpic.ps1``` and press Enter <br>

    
3. Make sure your Epic Games account owns Hogwarts Legacy.


Thanks to [whichtwix](https://github.com/whichtwix) for helping and discovering that this is possible and to a user in the Heroic Games Discord which shared the manifest file we needed for downgrading.

⚠ This might break in the near future when Epic changes their download policy with huge changes to their backend and CDN server logic.
