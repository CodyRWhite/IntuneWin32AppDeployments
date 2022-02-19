$VerbosePreference = "Continue"
$DebugPreference = "Continue"

$appID = "AgileBits.1Password"
$logPath = "$env:SystemRoot\Intune\Logging\Detection"
$logFile = "$($(Get-Date -Format "yyyy-MM-dd hh.mm.ssK").Replace(":",".")) - $appID.log"
$errorVar = $null
$AppDetectionCode = $null

IF (!(Test-Path -Path $logPath)){
    New-Item -Path $logPath -ItemType Directory -Force
}

#Start-Transcript -Path "$logPath\$logFile"

try{
#	Write-Verbose "Starting Detection for $appID"
	Push-Location "$env:ProgramFiles\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe" -ErrorAction SilentlyContinue
	$AppDetectionCode = (./AppInstallerCLI.exe list --id "$appID")
	If($AppDetectionCode[-1].Contains($appID)){
#		Write-Verbose "$appID successfully installed"
		exit 0
	}else{
#		Write-Verbose "$appID not installed"
		exit 1
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
		#Write-Verbose "Script Completed"
	}   

 #   Stop-Transcript
    $VerbosePreference = "SilentlyContinue"
    $DebugPreference = "SilentlyContinue"

    IF ($errorVar){
        throw $errorVar 
    }
}