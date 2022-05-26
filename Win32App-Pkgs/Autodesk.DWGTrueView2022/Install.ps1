$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = $args[0]

$logPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging\Install"
$logSettingsPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\CustomLogging"

$logFile = "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$settingsFile = "settings.json"

$errorVar = $null
$installResult = $null

$debug = $false

IF (Test-Path -Path $logSettingsPath\$settingsFile) {
    $intuneSettings = Get-Content -Raw -Path $logSettingsPath\$settingsFile | ConvertFrom-Json
    $debug = [bool]$intuneSettings.Settings.InstallDebug
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
    Start-Process -FilePath "$PSScriptRoot\DWGTrueView_2022_English_64bit_dlm.sfx.exe" -ArgumentList "-suppresslaunch", "-d $PSScriptRoot" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Start-Process -FilePath "$PSScriptRoot\DWGTrueView_2022_English_64bit_dlm\Setup.exe" -ArgumentList "--silent" -NoNewWindow -Wait -ErrorAction SilentlyContinue
    Remove-Item -Path "$($env:PUBLIC)\Desktop\DWG TrueView 2022 - English.lnk" -Force
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