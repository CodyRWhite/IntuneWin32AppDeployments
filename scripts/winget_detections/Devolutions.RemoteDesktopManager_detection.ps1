$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "Devolutions.RemoteDesktopManager"

$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging\Detection"
$logSettingsPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging"

$logFile = "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$settingsFile = "settings.json"

$errorVar = $null

$debug = $false

IF (Test-Path -Path $logSettingsPath\$settingsFile) {
	$intuneSettings = Get-Content -Raw -Path $logSettingsPath\$settingsFile | ConvertFrom-Json
	$debug = [bool]$intuneSettings.Settings.DetectionDebug
}
ELSE {
	$BaseSettings = '{
		"Settings":
		{
			"DetectionDebug": 0,
			"InstallDebug": 0,
			"UninstallDebug": 0
		}
	}'
	New-Item -Path $logSettingsPath\$settingsFile -Force
	Set-Content -Path $logSettingsPath\$settingsFile -Value $BaseSettings
}

IF ($debug) {
	IF (!(Test-Path -Path $logPath)) {
		New-Item -Path $logPath -ItemType Directory -Force
	}
	Start-Transcript -Path "$logPath\$logFile"
}

try {
	IF ([System.Environment]::Is64BitOperatingSystem) {
		$ProgramFiles = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"
	}
	ELSE {
		$ProgramFiles = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x86__8wekyb3d8bbwe"		
	}

	IF ($([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) -eq $True) {
		Write-Verbose "Starting detection for $appID in System Context"
		Push-Location $ProgramFiles -ErrorAction SilentlyContinue
		$AppInstallerPath = "$(Get-Location)\AppInstallerCLI.exe"
		$WinGetPath = "$(Get-Location)\winget.exe"		
		$AppFilePath = (Resolve-Path $AppInstallerPath, $WinGetPath -ErrorAction SilentlyContinue).Path
		IF ($AppFilePat) {
			$argumentList = [System.Collections.ArrayList]@("list", "--id $appID")  
			$cliCommand = '& "' + $($appFilePath) + '" ' + $argumentList
			$AppDetectionCode = Invoke-Expression $cliCommand
			If ($AppDetectionCode[-1].Contains($appID)) {
				Write-Verbose "$appID successfully installed"
				exit 0
			}
			else {
				Write-Verbose "$appID not installed"
				exit 1
			}
		}
		else {
			Write-Verbose "WinGet not Installed"
			Exit 1
		}
	}
	ELSE {
		IF ($([Security.Principal.WindowsIdentity]::GetCurrent().Groups) -match "S-1-5-32-544") {
			#Running as Admin 
			Write-Error  "Script is running in Administrator Context not System or User Context - Unsupported configuration"
			Exit 1
		}
		ELSE {
			#Running as Users
			Write-Verbose "Starting detection for $appID in User Context"
			$WinGetVer = Invoke-Expression '& WinGet -v'
			IF ($WinGetVer -ge "V1.0.0") {
				$argumentList = [System.Collections.ArrayList]@("list", "--id $appID")  
				$cliCommand = '& "WinGet" ' + $argumentList
				$AppDetectionCode = Invoke-Expression $cliCommand
				If ($AppDetectionCode[-1].Contains($appID)) {
					Write-Verbose "$appID successfully installed"
					exit 0
				}
				else {
					Write-Verbose "$appID not installed"
					exit 1
				}
			}
			else {
				Write-Verbose "WinGet not Installed"
				Exit 1
			}
		}
	}		
}
Catch {
	$errorVar = $_.Exception.Message
}
Finally {
	IF ($errorVar) {
		Write-Verbose "Script Errored"
		Write-Error  $errorVar
	}
	else {
		Write-Verbose "Script Completed"
	}   

	IF ($debug) { Stop-Transcript }
	$VerbosePreference = "SilentlyContinue"
	$DebugPreference = "SilentlyContinue"

	IF ($errorVar) {
		throw $errorVar 
	}
}