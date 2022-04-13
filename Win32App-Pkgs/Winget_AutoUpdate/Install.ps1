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
	$parentKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall"
	$key = "{091a1849-1ebf-455c-9440-592bdcc6a76e}"
	$uninstallPath = Join-Path -Path $parentKey -ChildPath $key

	IF (!(Test-Path -Path $uninstallPath)) {
		$WingetAutoUpdateParams = @{
			"Silent"       = $true
			"DoNotUpdate"  = $true
			"UseWhiteList" = $true
		}

		& "$PSScriptRoot\Winget-AutoUpdate-Install.ps1" @WingetAutoUpdateParams

		IF ($LastExitCode -eq 0) {
			Get-Childitem $PSScriptRoot | Where-Object { $_.extension -like ".build" }
			$BuildInfoFile = (Get-Childitem $PSScriptRoot | Where-Object { $_.extension -like ".build" }).FullName
			$BuildInfo = $(Get-Content -Raw -Path $BuildInfoFile) -Replace '(?m)(?<=^([^"]|"[^"]*")*)//.*' -Replace '(?ms)/\*.*?\*/' | ConvertFrom-Json

			New-Item -Path $parentKey -Name $key -Force
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "Comments" -Value $BuildInfo.AppInformation.Description
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "Contact" -Value $BuildInfo.AppInformation.Publisher
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "DisplayName" -Value $BuildInfo.AppInformation.DisplayName
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "DisplayVersion" -Value $BuildInfo.AppInformation.DisplayVersion
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "HelpLink" -Value $BuildInfo.AppInformation.InformationURL
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "InstallDate" -Value (Get-Date -Format "yyyyMMdd")
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "InstallSource" -Value $PSScriptRoot 
			New-ItemProperty -Path $uninstallPath -PropertyType DWORD -Name "EstimatedSize" -Value ([INT]((Get-ChildItem -path "$PSScriptRoot\Winget-AutoUpdate\" -recurse | Measure-Object -property length -sum ).sum / 1KB))
			New-ItemProperty -Path $uninstallPath -PropertyType DWORD -Name "Language" -Value 1033
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "Publisher" -Value $BuildInfo.AppInformation.Publisher
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "UninstallString" -Value $BuildInfo.ProgramInformation.UninstallCommandLine
			New-ItemProperty -Path $uninstallPath -PropertyType String -Name "URLInfoAbout" -Value $BuildInfo.AppInformation.InformationURL
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



















