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
    $AppFileName = "ChromaCam-G2M-2.6.0.21.exe"
    $Arguments = { "/S" }

    Write-Debug -Message "FileName: $AppFileName"
    Write-Debug -Message "Arguments: $Arguments"

    Write-Debug -Message "Startting Installers"
    Start-Process -FilePath "$PSScriptRoot\$AppFileName" -ArgumentList $Arguments -NoNewWindow -Wait -ErrorAction SilentlyContinue

    Write-Debug -Message "Moving GreenScreen Background to BG12"
    Move-Item -Path "C:\Program Files (x86)\Personify\ChromaCam\bg2.png" -Destination "C:\Program Files (x86)\Personify\ChromaCam\bg12.png"
    Move-Item -Path "C:\Program Files (x86)\Personify\ChromaCam\bg2_16x9.png" -Destination "C:\Program Files (x86)\Personify\ChromaCam\bg12_16x9.png"

    Write-Debug -Message "Copying Company Backgound to BG2"
    Move-Item -Path "$PSScriptRoot\bg2.png" -Destination "C:\Program Files (x86)\Personify\ChromaCam\bg2.png"
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