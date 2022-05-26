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
    & "$PSScriptRoot\Uninstall.ps1"
    
    Start-Process -FilePath "$PSScriptRoot\eDrawingsFullAllX64-30.20.0037.exe" -ArgumentList '/S', '/v"ALLUSERS=1 /qn /norestart /log output.log LOGPERFORMANCE=0 ADDLOCAL=eDrawingsViewer ENABLECHKFORUPDATE=0 DESKTOPICONINSTALL=0 RebootYesNo=No"' -NoNewWindow -Wait -ErrorAction SilentlyContinue

    Remove-Item -Path "$($env:PUBLIC)\Desktop\eDrawings 2022 x64 Edition.lnk" -Force
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