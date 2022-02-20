$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "PuTTY.PuTTY"

$logPath 			= "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging\Detection"
$logSettingsPath 	= "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging"

$logFile 		= "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$settingsFile 	= "settings.json"

$errorVar = $null
$uninstallResult = $null

$debug = $false

IF (Test-Path -Path $logSettingsPath\$settingsFile){
	$intuneSettings = Get-Content -Raw -Path $logSettingsPath\$settingsFile | ConvertFrom-Json
	$debug = [bool]$intuneSettings.Settings.DetectionDebug
}ELSE{
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
	IF (!(Test-Path -Path $logPath)){
		New-Item -Path $logPath -ItemType Directory -Force
	}
	Start-Transcript -Path "$logPath\$logFile"
}

try{
	Write-Verbose "Starting detection for $appID"
	Push-Location "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
	$appFilePath = "$(Get-Location)\AppInstallerCLI.exe"
	IF (Test-Path -Path $appFilePath){
		$argumentList =  [System.Collections.ArrayList]@("list", "--id $appID")  
		$cliCommand = '& "' + $($appFilePath) + '" ' + $argumentList
		$AppDetectionCode =  Invoke-Expression $cliCommand
		If($AppDetectionCode[-1].Contains($appID)){
			Write-Verbose "$appID successfully installed"
			exit 0
		}else{
			Write-Verbose "$appID not installed"
			exit 1
		}
	}else{
		Write-Verbose "WinGet not Installed"
		Exit 1
	}
}
Catch {
	$errorVar = $_.Exception.Message
}
Finally {
	IF ($errorVar){
		Write-Verbose "Script Errored"
		Write-Error  $errorVar
	}else{
		Write-Verbose "Script Completed"
	}   

	IF ($debug) {Stop-Transcript}
	$VerbosePreference = "SilentlyContinue"
	$DebugPreference = "SilentlyContinue"

	IF ($errorVar){
		throw $errorVar 
	}
}
