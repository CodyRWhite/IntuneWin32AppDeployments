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
	$AppName = "*eDrawings*"
	$Process = "edrawings*", "emodelviewer*"
	
	ForEach ( $Architecture in "SOFTWARE", "SOFTWARE\Wow6432Node" ) { 
		$UninstallKeys = "HKLM:\$Architecture\Microsoft\Windows\CurrentVersion\Uninstall"
		if (Test-path $UninstallKeys) {
			Write-Output "Checking for $AppName installation in $UninstallKeys"
			$GUID = Get-ItemProperty -Path "$UninstallKeys\*" | 
			Where-Object -FilterScript { $_.DisplayName -like $AppName } |
			Select-Object PSChildName -ExpandProperty PSChildName
	
			If ( $GUID ) {
				Write-Output "Stopping $AppName Processes"
				Get-Process $Process | Stop-Process -Force
				$GUID | ForEach-Object {
					Write-Output "Uninstalling: $(( Get-ItemProperty "$UninstallKeys\$_" ).DisplayName) " 
					Start-Process -Wait -FilePath "MsiExec.exe" -ArgumentList "/X$_ /qn /norestart"
				}
			}
			Else { 
				Write-Output "$AppName installation not found in $UninstallKeys"
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