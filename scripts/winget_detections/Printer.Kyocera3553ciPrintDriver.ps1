$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "Printer.Kyocera3553ciPrintDriver"

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
	IF ($([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) -eq $True) {
		$PrinterDriver = Get-PrinterDriver -Name "Kyocera TASKalfa 3553ci KX"

		IF ($PrinterDriver) {
			Write-Verbose "$appID successfully installed"
			exit 0
		}
		else {
			Write-Verbose "$appID not installed"
			exit 1
		}
	}
	ELSE {
		IF ($([Security.Principal.WindowsIdentity]::GetCurrent().Groups) -match "S-1-5-32-544") {
			#Running as Admin
			Write-Error  "Script is running in Administrator Context not System Context - Unsupported configuration"
			Exit 1 
		}
		ELSE {
			#Running as User
			Write-Error  "Script is running in User Context not System Context - Unsupported configuration"
			Exit 1
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