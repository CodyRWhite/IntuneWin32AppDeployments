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
    $parentKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
    $key = "{091a1849-1ebf-455c-9440-592bdcc6a76e}"
    $uninstallPath = Join-Path -Path $parentKey -ChildPath $key

    IF (Test-Path -Path $uninstallPath) {
        $WingetAutoUpdateParams = @{
            "Silent"    = $true
            "Uninstall" = $true
        }

        & "$PSScriptRoot\Winget-AutoUpdate-Install.ps1" @WingetAutoUpdateParams

        IF ($LastExitCode -eq 0) {
            Remove-Item -Path $uninstallPath -Force
        }
        ELSE {
            Write-Error "Registry Key Exists - Please uninstall first"
            exit 1
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