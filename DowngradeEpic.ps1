# This script downgrades the Epic Games version to a previous version using the 3rd party client Legendary
# 1. Download Legendary
# 2. Install with the provided manifest
# 3. Optionally update a registry key for HogWarp
# 4. If this script instantly closes after running, open the path that contains this file in PowerShell and run: powershell -NoProfile -ExecutionPolicy Bypass -File .\DowngradeEpic.ps1

$ErrorActionPreference = 'Continue'

	Write-Host -BackgroundColor Red "Downloading Legendary, please wait..."

	# Download Legendary (Heroic Games Launcher fork) - try with revocation check first
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

	# Detect if the HogwartsLegacy subfolder is present under the selected base path.
	# If not present, warn the user and offer to reselect the folder or continue.
	$expectedSubfolder = Join-Path $GameFolder 'HogwartsLegacy'
	if (-not (Test-Path $expectedSubfolder)) {
		Write-Host -BackgroundColor Yellow "HogwartsLegacy folder not detected in the selected location."
		Write-Host -ForegroundColor Yellow "If you continue, you might need to manually replace the downloaded files in the game folder later."
		while ($true) {
			$choice = Read-Host "Press 1 to continue or 2 to select folder again"
			if ($choice -eq '1') {
				break
			} elseif ($choice -eq '2') {
				if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
					$GameFolder = $folderDialog.SelectedPath
					# If user selected the HogwartsLegacy folder itself, use its parent as the base path
					if ($GameFolder -like "*HogwartsLegacy" -or (Split-Path -Leaf $GameFolder) -eq "HogwartsLegacy") {
						$GameFolder = Split-Path -Parent $GameFolder
						Write-Host -ForegroundColor Yellow "Detected HogwartsLegacy folder selection - using parent folder as base path."
					}
					Write-Host -ForegroundColor Green "Opening: $GameFolder"
					explorer.exe "$GameFolder"
					$expectedSubfolder = Join-Path $GameFolder 'HogwartsLegacy'
					if (Test-Path $expectedSubfolder) {
						Write-Host -ForegroundColor Green "Detected HogwartsLegacy subfolder in the selected location."
						break
					} else {
						Write-Host -ForegroundColor Yellow "HogwartsLegacy folder still not detected in the selected location."
					}
				} else {
					Write-Host -ForegroundColor Yellow "No folder selected."
				}
			} else {
				Write-Host -ForegroundColor Yellow "Please enter 1 or 2."
			}
		}
	}

	# Final confirmation before proceeding with download/install into the selected base path
	while ($true) {
		$confirm = Read-Host "Legendary will download files here: $GameFolder`nDo you wish to proceed? (Y/N)"
		if ($confirm -match '^[Yy]$') {
			break
		} elseif ($confirm -match '^[Nn]$') {
			if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
				$GameFolder = $folderDialog.SelectedPath
				if ($GameFolder -like "*HogwartsLegacy" -or (Split-Path -Leaf $GameFolder) -eq "HogwartsLegacy") {
					$GameFolder = Split-Path -Parent $GameFolder
					Write-Host -ForegroundColor Yellow "Detected HogwartsLegacy folder selection - using parent folder as base path."
				}
				Write-Host -ForegroundColor Green "Opening: $GameFolder"
				explorer.exe "$GameFolder"
				$expectedSubfolder = Join-Path $GameFolder 'HogwartsLegacy'
				if (-not (Test-Path $expectedSubfolder)) {
					Write-Host -ForegroundColor Yellow "HogwartsLegacy folder not detected in the selected location."
				}
			} else {
				Write-Host -ForegroundColor Yellow "No folder selected."
			}
		} else {
			Write-Host -ForegroundColor Yellow "Please answer Y or N."
		}
	}

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
		# Provide post-install maintenance options
		while ($true) {
			Write-Host ""
			Write-Host -BackgroundColor DarkBlue "Select an option:"
			Write-Host "1. Move save games from original EPIC location to HogWarp location."
			Write-Host "2. Move save games from HogWarp location to original EPIC location."
			Write-Host "3. Update HogWarp path in the registry for Hogwarts Legacy (select executable)."
			Write-Host "4. Delete Legendary config to try again from scratch."
			Write-Host "Q. Quit this menu (exit the script)"
			$opt = Read-Host "Enter 1-4 or Q"

			$exitMenu = $false

			# Common paths
			$epicBase = Join-Path $env:LOCALAPPDATA 'HogwartsLegacy\Saved\SaveGames'
			$hogBase = Join-Path $env:LOCALAPPDATA 'Hogwarts Legacy\Saved\SaveGames'
			# Script root for backups
			$scriptRoot = $PSScriptRoot
			if (-not $scriptRoot) {
				$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
				if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path }
			}
			$epicBackupRoot = Join-Path $scriptRoot 'Epic saves'
			$hogBackupRoot = Join-Path $scriptRoot 'HogWarp saves'
			New-Item -ItemType Directory -Path $epicBackupRoot -Force | Out-Null
			New-Item -ItemType Directory -Path $hogBackupRoot -Force | Out-Null
			$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
			$epicBackupDir = Join-Path $epicBackupRoot $ts
			$hogBackupDir = Join-Path $hogBackupRoot $ts

			switch ($opt) {
				'1' {
					# EPIC -> HogWarp (with backups)
					New-Item -ItemType Directory -Path $epicBackupDir -Force | Out-Null
					New-Item -ItemType Directory -Path $hogBackupDir -Force | Out-Null
					if (-not (Test-Path $epicBase)) {
						Write-Host -ForegroundColor Yellow "Epic saves base not found: $epicBase"
						break
					}
					# Find EPIC user folder
					$epicDirs = Get-ChildItem -Path $epicBase -Directory -ErrorAction SilentlyContinue
					$epicUserDir = ($epicDirs | Where-Object { $_.Name -match '^[0-9A-Za-z]{32}$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
					if (-not $epicUserDir) { $epicUserDir = ($epicDirs | Select-Object -First 1).FullName }
					if (-not $epicUserDir) {
						Write-Host -ForegroundColor Yellow "No Epic user save folder found under: $epicBase"
						break
					}
					New-Item -ItemType Directory -Path $hogBase -Force | Out-Null
					# Backups
					$savEpic = Get-ChildItem -Path $epicUserDir -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
					foreach ($f in $savEpic) { Copy-Item -Path $f.FullName -Destination (Join-Path $epicBackupDir $f.Name) -Force }
					$savHog = Get-ChildItem -Path $hogBase -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
					foreach ($f in $savHog) { Copy-Item -Path $f.FullName -Destination (Join-Path $hogBackupDir $f.Name) -Force }
					# Move saves EPIC -> HogWarp
					$destList = Join-Path $hogBase 'SaveGameList.sav'
					if (Test-Path $destList) { Remove-Item $destList -Force -ErrorAction SilentlyContinue }
					foreach ($f in $savEpic) { Move-Item -Path $f.FullName -Destination (Join-Path $hogBase $f.Name) -Force }
					Write-Host -ForegroundColor Green "Moved Epic saves to HogWarp. Backups: $epicBackupDir and $hogBackupDir"
				}
				'2' {
					# HogWarp -> EPIC (with backups)
					New-Item -ItemType Directory -Path $epicBackupDir -Force | Out-Null
					New-Item -ItemType Directory -Path $hogBackupDir -Force | Out-Null
					New-Item -ItemType Directory -Path $epicBase -Force | Out-Null
					# Determine target EPIC user dir
					$epicDirs = Get-ChildItem -Path $epicBase -Directory -ErrorAction SilentlyContinue
					$epicUserDir = ($epicDirs | Where-Object { $_.Name -match '^[0-9A-Za-z]{32}$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
					if (-not $epicUserDir) {
						$epicUserDir = Join-Path $epicBase ([Guid]::NewGuid().ToString('N'))
						New-Item -ItemType Directory -Path $epicUserDir -Force | Out-Null
					}
					# Backups
					$savEpicDest = Get-ChildItem -Path $epicUserDir -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
					foreach ($f in $savEpicDest) { Copy-Item -Path $f.FullName -Destination (Join-Path $epicBackupDir $f.Name) -Force }
					$savHogSrc = Get-ChildItem -Path $hogBase -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
					foreach ($f in $savHogSrc) { Copy-Item -Path $f.FullName -Destination (Join-Path $hogBackupDir $f.Name) -Force }
					# Move saves HogWarp -> EPIC
					$destListEpic = Join-Path $epicUserDir 'SaveGameList.sav'
					if (Test-Path $destListEpic) { Remove-Item $destListEpic -Force -ErrorAction SilentlyContinue }
					foreach ($f in $savHogSrc) { Move-Item -Path $f.FullName -Destination (Join-Path $epicUserDir $f.Name) -Force }
					Write-Host -ForegroundColor Green "Moved HogWarp saves to Epic. Backups: $epicBackupDir and $hogBackupDir"
				}
				'3' {
					# Registry update via selecting HogwartsLegacy.exe (root or Win64)
					Add-Type -AssemblyName System.Windows.Forms
					$openDialog = New-Object System.Windows.Forms.OpenFileDialog
					$openDialog.Title = "Select HogwartsLegacy.exe (root or Phoenix\\Binaries\\Win64)"
					$openDialog.Filter = "HogwartsLegacy.exe|HogwartsLegacy.exe|Executable Files|*.exe|All Files|*.*"
					$openDialog.Multiselect = $false
					if ($openDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
						$selPath = $openDialog.FileName
						$expectedExeDir = $null
						if ($selPath -match "\\HogwartsLegacy\\Phoenix\\Binaries\\Win64\\HogwartsLegacy.exe$") {
							$expectedExeDir = Split-Path -Parent $selPath
						} else {
							# Attempt to find root HogwartsLegacy directory and build expected Win64 path
							$parent = Split-Path -Parent $selPath
							while ($parent -and -not ($parent -match "\\HogwartsLegacy$")) { $parent = Split-Path -Parent $parent }
							if ($parent) {
								$expectedExeDir = Join-Path $parent 'HogwartsLegacy\Phoenix\Binaries\Win64'
							} else {
								# Fallback: use the directory of the selected file
								$expectedExeDir = Split-Path -Parent $selPath
							}
						}
						$expectedExePath = Join-Path $expectedExeDir 'HogwartsLegacy.exe'
						$regPath = 'HKCU:\Software\TiltedPhoques\WarpSpeed\Hogwarts Legacy'
						New-Item -Path $regPath -Force | Out-Null
						New-ItemProperty -Path $regPath -Name 'TitleExe' -Value $expectedExePath -PropertyType String -Force | Out-Null
						New-ItemProperty -Path $regPath -Name 'TitlePath' -Value $expectedExeDir -PropertyType String -Force | Out-Null
						Write-Host -ForegroundColor Green "Registry updated:"
						Write-Host -ForegroundColor Green "TitleExe = $expectedExePath"
						Write-Host -ForegroundColor Green "TitlePath = $expectedExeDir"
					} else {
						Write-Host -ForegroundColor Yellow "No file selected."
					}
				}
				'4' {
					# Delete Legendary config (auto-detect common locations) with confirmation and restart
					$paths = @()
					if ($env:USERPROFILE) { $paths += (Join-Path $env:USERPROFILE '.config\legendary') }
					if ($env:APPDATA) { $paths += (Join-Path $env:APPDATA 'legendary') }
					if ($env:LOCALAPPDATA) { $paths += (Join-Path $env:LOCALAPPDATA 'legendary') }
					$existing = $paths | Where-Object { Test-Path $_ }
					if (-not $existing -or $existing.Count -eq 0) {
						Write-Host -ForegroundColor Yellow "Legendary config not found in common locations."
					} else {
						Write-Host -ForegroundColor Yellow "The following Legendary config paths were found:"
						foreach ($p in $existing) { Write-Host " - $p" }
						$confirmDel = Read-Host "Are you sure you want to clean up Legendary's config and start over? This will restart the script. (Y/N)"
						if ($confirmDel -match '^[Yy]$') {
							foreach ($p in $existing) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
							Write-Host -ForegroundColor Green "Legendary config deleted. Restarting script..."
							$scriptPath = $PSCommandPath
							if (-not $scriptPath -and $MyInvocation.MyCommand.Path) { $scriptPath = $MyInvocation.MyCommand.Path }
							if ($scriptPath -and (Test-Path $scriptPath)) {
								$workDir = Split-Path -Parent $scriptPath
								Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$scriptPath`"" -WorkingDirectory $workDir
							} else {
								Write-Host -ForegroundColor Yellow "Could not determine script path for restart. Please run it again manually."
							}
							$exitMenu = $true
						} else {
							Write-Host -ForegroundColor Yellow "Deletion cancelled."
						}
					}
				}
				'Q' { $exitMenu = $true }
				default { Write-Host -ForegroundColor Yellow "Please enter 1-4 or Q." }
			}

			if ($exitMenu) {
				Write-Host -ForegroundColor Cyan "Exiting script at your request."
				exit 0
			}
		}
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

	# Optional save sync prompt (Epic -> HogWarp) with backups
	$doSync = Read-Host "Sync Epic saves to HogWarp location now? (Y/N)"
	if ($doSync -match '^[Yy]$') {
		$epicBase = Join-Path $env:LOCALAPPDATA 'HogwartsLegacy\Saved\SaveGames'
		$hogBase = Join-Path $env:LOCALAPPDATA 'Hogwarts Legacy\Saved\SaveGames'
		# Prepare backups
		$scriptRoot = $PSScriptRoot; if (-not $scriptRoot) { $scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path; if (-not $scriptRoot) { $scriptRoot = (Get-Location).Path } }
		$epicBackupRoot = Join-Path $scriptRoot 'Epic saves'
		$hogBackupRoot = Join-Path $scriptRoot 'HogWarp saves'
		New-Item -ItemType Directory -Path $epicBackupRoot -Force | Out-Null
		New-Item -ItemType Directory -Path $hogBackupRoot -Force | Out-Null
		$ts = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
		$epicBackupDir = Join-Path $epicBackupRoot $ts
		$hogBackupDir = Join-Path $hogBackupRoot $ts
		New-Item -ItemType Directory -Path $epicBackupDir -Force | Out-Null
		New-Item -ItemType Directory -Path $hogBackupDir -Force | Out-Null

		if (-not (Test-Path $epicBase)) {
			Write-Host -ForegroundColor Yellow "Epic saves base not found: $epicBase"
		} else {
			$epicDirs = Get-ChildItem -Path $epicBase -Directory -ErrorAction SilentlyContinue
			$epicUserDir = ($epicDirs | Where-Object { $_.Name -match '^[0-9A-Za-z]{32}$' } | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
			if (-not $epicUserDir) { $epicUserDir = ($epicDirs | Select-Object -First 1).FullName }
			if (-not $epicUserDir) {
				Write-Host -ForegroundColor Yellow "No Epic user save folder found under: $epicBase"
			} else {
				New-Item -ItemType Directory -Path $hogBase -Force | Out-Null
				# Backups
				$savEpic = Get-ChildItem -Path $epicUserDir -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
				foreach ($f in $savEpic) { Copy-Item -Path $f.FullName -Destination (Join-Path $epicBackupDir $f.Name) -Force }
				$savHog = Get-ChildItem -Path $hogBase -Filter *.sav -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'SaveGameList.sav' }
				foreach ($f in $savHog) { Copy-Item -Path $f.FullName -Destination (Join-Path $hogBackupDir $f.Name) -Force }
				# Move saves EPIC -> HogWarp
				$destList = Join-Path $hogBase 'SaveGameList.sav'
				if (Test-Path $destList) { Remove-Item $destList -Force -ErrorAction SilentlyContinue }
				foreach ($f in $savEpic) { Move-Item -Path $f.FullName -Destination (Join-Path $hogBase $f.Name) -Force }
				Write-Host -ForegroundColor Green "Moved Epic saves to HogWarp. Backups: $epicBackupDir and $hogBackupDir"
			}
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
