$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "Printer.KyoceraUniversalPrintDriver"

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

	$DriverLocated = $False
	$ExpectedClassGUID = "{4D36E979-E325-11CE-BFC1-08002BE10318}"
	$ExpectedVersion = [version]"8.2.0623.0"
	$ExpectedDate = [Datetime]::ParseExact("06/23/2021", 'MM/dd/yyyy', $null)

	IF ($([Security.Principal.WindowsIdentity]::GetCurrent().IsSystem) -eq $True) {
		$DriverINF = Get-ChildItem -path C:\windows\inf -name "oem*.inf" | 
		Where-Object { $_.psiscontainer -eq $false } | 
		Where-Object { 
			Get-Content $_.pspath | 
			Select-String -pattern "CatalogFile= KYOMITA.CAT"
		}	
		ForEach ($File in $DriverINF) {
	
			$DriverVersion = Get-Content "C:\Windows\INF\$File" |
			Where-Object { $_ -like 'DriverVer*' } |
			Select-Object -First 1 |
			ForEach-Object { 
				$_.Split(',')[-1] 
			}
			$DriverVersion = [Version]$DriverVersion

			$DriverDate = Get-Content "C:\Windows\INF\$File" |
			Where-Object { $_ -like 'DriverVer*' } |
			Select-Object -First 1 |
			ForEach-Object { 
				($_.Split(',')[0]).split("=")[-1].Trim()
			}			
			$DriverDate = [Datetime]::ParseExact($DriverDate, 'MM/dd/yyyy', $null)

			$DriverClassGUID = Get-Content "C:\Windows\INF\$File" |
			Where-Object { $_ -like 'ClassGUID*' } |
			Select-Object -First 1 |
			ForEach-Object { 
		($_.Split('=')[-1] ).Trim()
			}

			IF ($DriverClassGUID -eq $ExpectedClassGUID -and $DriverVersion -ge $ExpectedVersion -and $DriverDate -ge $ExpectedDate) {
				$DriverLocated = $true
				Write-Verbose "$appID successfully installed"
				exit 0
			}
			else {
				Write-Verbose "$appID not installed"
				exit 1
			}
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