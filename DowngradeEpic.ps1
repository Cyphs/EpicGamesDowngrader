# This script downgrades the Epic Games version to the previous live one using the 3rd party client Legendary
# 1. Download Legendary
# 2. Install with the provided manifest
# 3. Optionally update a registry key for HogWarp

$ErrorActionPreference = 'Continue'

	Write-Host -BackgroundColor Red "Downloading Legendary, please wait..."

	# Download Legendary (Heroic official build) - try with revocation check first
	curl.exe -L -o legendary.exe https://github.com/Heroic-Games-Launcher/legendary/releases/latest/download/legendary_windows_x86_64.exe

	# Check if download succeeded (file exists and has content)
	if (-not (Test-Path ".\legendary.exe") -or (Get-Item ".\legendary.exe").Length -eq 0) {
		Write-Host -ForegroundColor Yellow "Initial download failed, retrying without TLS revocation checks..."
		Remove-Item ".\legendary.exe" -ErrorAction SilentlyContinue
		
		curl.exe --ssl-no-revoke -L -o legendary.exe https://github.com/Heroic-Games-Launcher/legendary/releases/latest/download/legendary_windows_x86_64.exe
	}

	# Final check
	if (-not (Test-Path ".\legendary.exe") -or (Get-Item ".\legendary.exe").Length -eq 0) {
		Write-Host -ForegroundColor Red "Failed to download Legendary executable."
		Write-Host -ForegroundColor Red "Possible causes:"
		Write-Host -ForegroundColor Red "  - Network connectivity issues"
		Write-Host -ForegroundColor Red "  - Corporate firewall/proxy blocking GitHub"
		Write-Host -ForegroundColor Red "  - TLS certificate revocation check blocked"
		Write-Host -ForegroundColor Red "  - HTTPS inspection interfering with downloads"
		Write-Host ""
		Write-Host -ForegroundColor Yellow "Try downloading manually from:"
		Write-Host -ForegroundColor Yellow "https://github.com/Heroic-Games-Launcher/legendary/releases/latest"
		Write-Host -ForegroundColor Yellow "and place legendary.exe in this folder, then re-run the script."
		
		try {
			Write-Host -ForegroundColor Cyan "Press any key to exit..."
			$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
		} catch {
			Read-Host "Press Enter to exit"
		}
		exit 1
	}

	# Download the manifest early so we can use it later (override)
	$manifestUrl = 'https://github.com/Cyphs/egs-manifests/raw/refs/heads/main/fa4240e57a3c46b39f169041b7811293/manifests/fa4240e57a3c46b39f169041b7811293_Windows_1420267.manifest'
	if (-not (Test-Path .\hogwarp.manifest)) {
		Write-Host "Downloading manifest..."
		Invoke-WebRequest -Uri $manifestUrl -UseBasicParsing -OutFile hogwarp.manifest
	}

	# Check whether Legendary already has saved credentials; prefer parsing JSON output from `status`
	$statusJson = & .\legendary status --json 2>$null
	$loggedIn = $false
	if ($statusJson) {
		try {
			$statusObj = $statusJson | ConvertFrom-Json -ErrorAction Stop
			if ($null -ne $statusObj) {
				if ($statusObj.PSObject.Properties.Name -contains 'logged_in') {
					$loggedIn = [bool]$statusObj.logged_in
				} elseif ($statusObj.PSObject.Properties.Name -contains 'username') {
					$loggedIn = -not [string]::IsNullOrEmpty($statusObj.username)
				}
			}
		} catch {
			# parsing failed; treat as not logged in
			$loggedIn = $false
		}
	}

	if (-not $loggedIn) {
		Write-Host -BackgroundColor Yellow "No saved Legendary credentials detected - launching interactive login (system browser)..."
		& .\legendary auth --disable-webview
		if ($LASTEXITCODE -ne 0) {
			Write-Host -ForegroundColor Red "Legendary login failed. Aborting."
			exit 1
		}
	}

	# After folder selection, we'll prime CDN metadata, then run the manifest-based install into the chosen folder.

	Write-Host "done"
	Write-Host -BackgroundColor Red "Select a folder to download Hogwarts Legacy to."

	# Prompt the user to select the game folder (GUI)
	Add-Type -AssemblyName System.Windows.Forms
	$folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
	$folderDialog.Description = "Select a download folder"
	$folderDialog.ShowNewFolderButton = $true
	if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$GameFolder = $folderDialog.SelectedPath
	} else {
		Write-Host -ForegroundColor Red "No folder selected - aborting script."
		exit 1
	}

	# If user selected the HogwartsLegacy folder itself, use its parent as the base path
	if ($GameFolder -like "*HogwartsLegacy" -or (Split-Path -Leaf $GameFolder) -eq "HogwartsLegacy") {
		$GameFolder = Split-Path -Parent $GameFolder
		Write-Host -ForegroundColor Yellow "Detected HogwartsLegacy folder selection - using parent folder as base path."
	}

	Write-Host -ForegroundColor Green "Opening: $GameFolder"
	explorer.exe "$GameFolder"

	# Before installing, check if the app is already installed (idempotent)
	$alreadyInstalled = $false
	$installedJson = & .\legendary list-installed --json 2>&1
	if ($LASTEXITCODE -ne 0) {
		# treat as no installed apps found
		$installedJson = $null
	}
	if ($installedJson) {
		try {
			$installed = $installedJson | ConvertFrom-Json -ErrorAction Stop
			foreach ($item in $installed) {
				$idCandidates = @($item.app, $item.app_name, $item.name)
				if ($idCandidates -contains 'fa4240e57a3c46b39f169041b7811293') { $alreadyInstalled = $true; break }
			}
		} catch { }
	}

	if ($alreadyInstalled) {
		Write-Host -ForegroundColor Green "App already installed according to Legendary. You can re-run install to resume if needed."
	} else {
		# Prime CDN metadata by running a non-manifest install first, as the original flow did
		Write-Host -ForegroundColor Cyan "Priming CDN metadata (no files will be downloaded)..."
		# Run an analysis-only install to populate CDN metadata without downloading any files (stream output)
		& .\legendary install fa4240e57a3c46b39f169041b7811293 --abort-if-any-installed --base-path "$GameFolder" --download-only --prefix "__NO_MATCH__" -y
		if ($LASTEXITCODE -ne 0) {
			Write-Host -ForegroundColor Yellow "Priming step returned code $LASTEXITCODE. Continuing to manifest install."
		}

		Write-Host -ForegroundColor Cyan "Installing using manifest under base path: $GameFolder (progress will be shown)"
		# Install under the selected base path (Legendary will create the subfolder), stream output for progress
		& .\legendary install fa4240e57a3c46b39f169041b7811293 --manifest hogwarp.manifest --base-path "$GameFolder" -y
		if ($LASTEXITCODE -ne 0) {
			Write-Host -ForegroundColor Red "Legendary install exited with code $LASTEXITCODE."
		}
	}

	# Offer to update HogWarp registry entries for Hogwarts Legacy
	$updateReg = Read-Host "Update HogWarp path in the registry for Hogwarts Legacy with this folder? (Y/N)"
	if ($updateReg -match '^[Yy]') {
		# Use the expected HogwartsLegacy install layout under the chosen base path
		$expectedExeDir = Join-Path $GameFolder 'HogwartsLegacy\Phoenix\Binaries\Win64'
		$expectedExePath = Join-Path $expectedExeDir 'HogwartsLegacy.exe'
		if (-not (Test-Path $expectedExePath)) {
			Write-Host -ForegroundColor Yellow "Expected executable not found yet at $expectedExePath. Setting registry values anyway."
		}
		$regPath = 'HKCU:\Software\TiltedPhoques\WarpSpeed\Hogwarts Legacy'
		New-Item -Path $regPath -Force | Out-Null
		New-ItemProperty -Path $regPath -Name 'TitleExe' -Value $expectedExePath -PropertyType String -Force | Out-Null
		New-ItemProperty -Path $regPath -Name 'TitlePath' -Value $expectedExeDir -PropertyType String -Force | Out-Null
		Write-Host -ForegroundColor Green "Registry updated:"
		Write-Host -ForegroundColor Green "TitleExe = $expectedExePath"
		Write-Host -ForegroundColor Green "TitlePath = $expectedExeDir"
	}

	# Copy Epic (no-space) saves to Steam-style (space) saves for HogWarp
	Write-Host -BackgroundColor Red "Syncing Epic saves to HogWarp location..."
	$srcBase = Join-Path $env:LOCALAPPDATA 'HogwartsLegacy\Saved\SaveGames'
	$destBase = Join-Path $env:LOCALAPPDATA 'Hogwarts Legacy\Saved\SaveGames'

	if (-not (Test-Path $srcBase)) {
		Write-Host -ForegroundColor Yellow "Source saves folder not found: $srcBase"
	} else {
		# Find the 32-character user folder (pick most recently modified if multiple)
		$subDirs = Get-ChildItem -Path $srcBase -Directory -ErrorAction SilentlyContinue
		$matchDirs = $subDirs | Where-Object { $_.Name -match '^[0-9A-Za-z]{32}$' } | Sort-Object LastWriteTime -Descending
		$srcUserDir = $null
		if ($matchDirs -and $matchDirs.Count -gt 0) { $srcUserDir = $matchDirs[0].FullName }
		elseif ($subDirs -and $subDirs.Count -gt 0) { $srcUserDir = $subDirs[0].FullName }

		if (-not $srcUserDir) {
			Write-Host -ForegroundColor Yellow "No save subfolder found under: $srcBase"
		} else {
			# Ensure destination exists
			New-Item -ItemType Directory -Path $destBase -Force | Out-Null
			# Copy all .sav files except SaveGameList.sav, overwriting if present
			$savFiles = Get-ChildItem -Path $srcUserDir -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
			foreach ($f in $savFiles) {
				Copy-Item -Path $f.FullName -Destination (Join-Path $destBase $f.Name) -Force
			}
			# Delete SaveGameList.sav in destination if present
			$destList = Join-Path $destBase 'SaveGameList.sav'
			if (Test-Path $destList) {
				Remove-Item $destList -Force -ErrorAction SilentlyContinue
				Write-Host -ForegroundColor Yellow "Removed stale SaveGameList.sav in destination."
			}
			Write-Host -ForegroundColor Green "Saved files synced to: $destBase"
		}
	}

	# Pause so the window doesn't close immediately
	try {
		Write-Host -ForegroundColor Cyan "Press any key to exit..."
		$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
	} catch {
		# Fallback for hosts without RawUI
		Read-Host "Press Enter to exit"
	}

	# End of script
