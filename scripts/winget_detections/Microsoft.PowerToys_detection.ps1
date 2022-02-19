$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "Microsoft.PowerToys"
$logPath = "$env:SystemRoot\Intune\Logging\Detection"
$logFile = "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$errorVar = $null
$AppDetectionCode = $null

$intuneSettings = Get-Content -Raw -Path "$env:SystemRoot\Intune\Logging\settings.json" | ConvertFrom-Json
$debug = [bool]$intuneSettings.Settings.DetectionDebug

IF (!(Test-Path -Path $logPath)){
	New-Item -Path $logPath -ItemType Directory -Force
}

IF ($debug) {Start-Transcript -Path "$logPath\$logFile"}

try{
	Write-Verbose "Starting detection for $appID"
	Push-Location "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
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
