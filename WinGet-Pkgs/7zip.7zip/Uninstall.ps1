$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = $args[0]

$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging\Uninstall"
$logSettingsPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging"

$logFile = "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$settingsFile = "settings.json"

$errorVar = $null
$uninstallResult = $null

$debug = $false

IF (Test-Path -Path $logSettingsPath\$settingsFile) {
	$intuneSettings = Get-Content -Raw -Path $logSettingsPath\$settingsFile | ConvertFrom-Json
	$debug = [bool]$intuneSettings.Settings.UninstallDebug
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
	IF ($([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) -eq $True) {
		IF ([System.Environment]::Is64BitOperatingSystem) {
			$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe"
		}
		ELSE {
			$ResolveWingetPath = Resolve-Path "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x86__8wekyb3d8bbwe\winget.exe"
		}

		if ($ResolveWingetPath) {
			$wingetPath = $ResolveWingetPath[-1].Path
		}

		$wingetFolderPath = Split-Path -Path $WingetPath -Parent
		
		Write-Verbose "Starting uninstall for $appID in System Context"
		Push-Location $wingetFolderPath -ErrorAction SilentlyContinue
		$wingetPath = "$(Get-Location)\winget.exe"
		$AppFilePath = Resolve-Path -Path $wingetPath
		IF ($AppFilePath) {
			$argumentList = [System.Collections.ArrayList]@("uninstall", "--silent", "--accept-source-agreements", "--disable-interactivity", "--id $appID")  
			$cliCommand = '& "' + $($appFilePath) + '" ' + $argumentList
			$uninstallResult = Invoke-Expression $cliCommand | Out-String
			Write-Verbose $uninstallResult
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
			Write-Verbose "Starting uninstall for $appID in User Context"
			$WinGetVer = Invoke-Expression '& WinGet -v'
			IF ($WinGetVer -ge "V1.0.0") {
				$argumentList = [System.Collections.ArrayList]@("uninstall", "--silent", "$appID") 
				$cliCommand = '& "WinGet" ' + $argumentList
				$uninstallResult = Invoke-Expression $cliCommand | Out-String
				Write-Verbose $uninstallResult
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
