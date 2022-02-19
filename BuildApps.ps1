Import-Module IntuneWin32App -Force

$TenantName = "org.onmicrosoft.com"
$BuildDir = "C:\IntuneApps"
$OutputDir = "C:\IntuneApps\Output"

#FIPS ISSUE WITH IntuneWinAppUtil.exe
#Computer\HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy ;
#change both values "Enabled" and "MDMEnabled" to 0
Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\FipsAlgorithmPolicy" -Name "MDMEnabled" -Value 0

$Connection_Details = Connect-MSIntuneGraph -TenantID $TenantName

# Get Categories
Write-Verbose -Message "Fetching Category List from Remote Server"
$GraphURI = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCategories"
$CategoryList = $(Invoke-RestMethod -Uri $GraphURI -Headers $Global:AuthenticationHeader -Method "GET" -ErrorAction Stop -Verbose:$false).value

# Get App List
Write-Verbose -Message "Fetching Application List from Remote Server"
$Win32Apps = Get-IntuneWin32App

Get-ChildItem $BuildDir -Directory | where-object { $_.Name -notin "Output", "Icons", "In Progress", "scripts", "logs"} | foreach-object{
    $Win32App = $null
    $BuildInfo = $null
    $ContinueBuild = $false
    $Icon = $null  

    $RequirementRule = $null
    $RequirementRuleParams = @{}
    
    $AdditionalRequirementRule = @()
    $AdditionalRequirementRuleParams = @{}

    $DetectionRule = @() 
    $DetectionRuleParams = @{} 

    $Dependencies = @() 
    $DependencyParms = @{}

    $Supersedences = @() 
    $SupersedenceParms = @{}

    $AppParams = @{}
    $NewWin32App = $null

    $Win32AppAssignment = $null
    $AssignmentParams = @{}

    $SourceFolder = $_.Name
    $BuildPath = $BuildDir + "\" + $SourceFolder
    $BuildInfoFile = $BuildPath + "\" + (Get-ChildItem $BuildPath | where-object {$_.Extension -eq ".build"}).Name
    $BuildInfo = Get-Content -Raw -Path $BuildInfoFile | ConvertFrom-Json
    $IntuneWinFile = "$OutputDir\$SourceFolder.intunewin"

    $BuildAppInfo = $BuildInfo.AppInformation
    $BuildProgramInfo = $BuildInfo.ProgramInformation
    $BuildRequirementRule = $BuildInfo.RequirementRule
    $BuildAdditionalRequirementRule = $BuildInfo.AdditionalRequirementRule
    $BuildDetectionRules = $BuildInfo.DetectionRules
    $BuildDependencies = $BuildInfo.Dependencies
    $BuildSupersedences = $BuildInfo.Supersedence
    $BuildAssignments = $BuildInfo.assignments

    Write-Verbose -Message "Starting W32 App Check on $($BuildAppInfo.DisplayName)"
    Write-Verbose -Message "Local version of $($BuildAppInfo.DisplayName) detected as: $($BuildAppInfo.DisplayVersion)"
    
    foreach ($app in $Win32Apps) {
      IF ($app.displayName -eq $BuildAppInfo.DisplayName){
        $Win32App = $app
        break
      }else {
        $Win32App = $null
      }
    }
    
    IF ($Win32App) {
      Write-Verbose -Message "Remote version of $($BuildAppInfo.DisplayName) detected as: $($Win32App.DisplayVersion)"
      IF ([System.Version][string]$Win32App.DisplayVersion -lt [System.Version]$BuildAppInfo.DisplayVersion) { #-or $NewBuild
        Write-Verbose -Message "New Version Availble! Preparing Intune W32 App for $($BuildAppInfo.DisplayName)"
        $ContinueBuild = $true
      }
    }else{
      Write-Verbose -Message "No apps were found in remote catalog - Assuming New Build Process"
      $ContinueBuild = $true
    }

    IF ($ContinueBuild) {
      #Start-Sleep -Seconds 120
      #region Build Win32App
        Write-Verbose -Message "Intune W32 App for $($BuildAppInfo.DisplayName) Build Started"
        Start-Process -FilePath "$BuildDir\IntuneWinAppUtil.exe" -ArgumentList "-c $BuildPath","-s $($BuildProgramInfo.InstallFile)","-o $OutputDir","-q" -NoNewWindow -Wait -RedirectStandardOutput "NULL"
        if ($($BuildProgramInfo.InstallFile) -eq "Install.ps1"){
          IF (Test-Path -Path "$OutputDir\$SourceFolder.intunewin"){
            Remove-Item -Path "$OutputDir\$SourceFolder.intunewin"
          }
           Move-Item -Path "$OutputDir\Install.intunewin" -Destination "$OutputDir\$SourceFolder.intunewin"
        }
        Write-Verbose -Message "Intune W32 App for $($BuildAppInfo.DisplayName) Build Complete"
      #endregion Build Win32App

      #region Win32App Logo Image
        Write-Verbose -Message "Preparing package logo image"
        IF ($BuildAppInfo.Logo) {
            $Icon = New-IntuneWin32AppIcon -FilePath "$($BuildAppInfo.Logo)"
        }
      #endregion Win32App Logo Image 

      #region App Information
        Write-Verbose -Message "Preparing package app information"
        $AppParams = @{          
          "DisplayName" = $BuildAppInfo.DisplayName # Required
          "Description" = $BuildAppInfo.Description # Required          
        }
        
        IF ($BuildAppInfo.Publisher) {$AppParams.add("Publisher", $BuildAppInfo.Publisher)} # Not required, default [String]::empty
        IF ($BuildAppInfo.DisplayVersion) {$AppParams.add("AppVersion", $BuildAppInfo.DisplayVersion)} # Not Required, default [String]::empty
        ## Category when it is added
        IF ($BuildAppInfo.CompanyPortalFeaturedApp) {$AppParams.add("CompanyPortalFeaturedApp", $BuildAppInfo.CompanyPortalFeaturedApp)} # Not required, default false
        IF ($BuildAppInfo.InformationURL) {$AppParams.add("InformationURL", $BuildAppInfo.InformationURL)} # Not required, default [String]::empty
        IF ($BuildAppInfo.PrivacyURL) {$AppParams.add("PrivacyURL", $BuildAppInfo.PrivacyURL)} # Not required, default [String]::empty
        IF ($BuildAppInfo.Developer) {$AppParams.add("Developer", $BuildAppInfo.Developer)} # Not required, default [String]::empty
        IF ($BuildAppInfo.Owner) {$AppParams.add("Owner", $BuildAppInfo.Owner)} # Not required, default [String]::empty
        IF ($BuildAppInfo.Notes) {$AppParams.add("Notes", $BuildAppInfo.Notes)} # Not required, default [String]::empty
        IF ($Icon) {$AppParams.add("Icon", $Icon)} # Not required, validated null or empty       
      #endregion App Information

      #region Program
        Write-Verbose -Message "Preparing package program"
        IF ($IntuneWinFile) {$AppParams.add("FilePath", $IntuneWinFile)} # Required
        IF ($BuildProgramInfo.InstallCommandLine) {$AppParams.add("InstallCommandLine", $BuildProgramInfo.InstallCommandLine)} # Required
        IF ($BuildProgramInfo.UninstallCommandLine) {$AppParams.add("UninstallCommandLine", $BuildProgramInfo.UninstallCommandLine)} # Required
        IF ($BuildProgramInfo.InstallExperience) {$AppParams.add("InstallExperience", $BuildProgramInfo.InstallExperience)} # Required, "system", "user"
        IF ($BuildProgramInfo.RestartBehavior) {$AppParams.add("RestartBehavior", $BuildProgramInfo.RestartBehavior)} # Required "allow", "basedOnReturnCode", "suppress", "force"
      #endregion Program

      #region Custom Return Codes
        Write-Verbose -Message "Preparing package custom return codes - TBD"
      #endregion Custom Return Codes

      #region Requirement Rule
        Write-Verbose -Message "Preparing package requirement rules"
        $RequirementRuleParams = @{
          "Architecture" = $BuildRequirementRule.Architecture # Required, "x64", "x86", "All"
          "MinimumSupportedOperatingSystem" = $BuildRequirementRule.MinimumSupportedOperatingSystem # Required, "1607", "1703", "1709", "1803", "1809", "1903"
        }
        IF ($BuildRequirementRule.MinimumFreeDiskSpaceInMB) {$RequirementRuleParams.add("MinimumFreeDiskSpaceInMB", $BuildRequirementRule.MinimumFreeDiskSpaceInMB)} # Not required, but validated not null or empty
        IF ($BuildRequirementRule.MinimumMemoryInMB) {$RequirementRuleParams.add("MinimumMemoryInMB", $BuildRequirementRule.MinimumMemoryInMB)} # Not required, but validated not null or empty
        IF ($BuildRequirementRule.MinimumNumberOfProcessors) {$RequirementRuleParams.add("MinimumNumberOfProcessors", $BuildRequirementRule.MinimumNumberOfProcessors)} # Not required, but validated not null or empty
        IF ($BuildRequirementRule.MinimumCPUSpeedInMHz) {$RequirementRuleParams.add("MinimumCPUSpeedInMHz", $BuildRequirementRule.MinimumCPUSpeedInMHz)} # Not required, but validated not null or empty

        $RequirementRule = New-IntuneWin32AppRequirementRule @RequirementRuleParams
        IF ($RequirementRule) {$AppParams.add("RequirementRule", $RequirementRule)} # Not required, validated null or empty
      #endregion Requirement Rule

      #region Additional Requirement Rules
        Write-Verbose -Message "Preparing package additional requirement rules"
        foreach ($Rule in $BuildAdditionalRequirementRule)  
        {     
          Switch ($Rule.RuleType) {
            "Script" {
              <#
              # "AdditionalRequirementRule": [
              #  {
              #    "id": 0,
              #    "RuleType": "Registry",
              #    "OutputDataType": "String",
              #    "ScriptFile": "C:\\IntuneApps\\scripts\\ChassisType.ps1",
              #    "ScriptContext": "system",
              #    "ComparisonOperator": "equal",
              #    "Value": "isDesktop",
              #    "RunAs32BitOn64System": "0",
              #    "EnforceSignatureCheck": "0"
              #  }
              # ],
              #>
              $AdditionalRequirementRuleParams = @{}     
              $AdditionalRequirementRuleParams = @{
                "ScriptFile" = $Rule.ScriptFile
                "ScriptContext" = $Rule.ScriptContext
                "RunAs32BitOn64System" = [bool]$Rule.RunAs32BitOn64System
                "EnforceSignatureCheck" = [bool]$Rule.EnforceSignatureCheck
              }

              Switch ($Rule.OutputDataType) {
                "String" {
                  $AdditionalRequirementRuleParams.add("StringOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("StringComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("StringValue", $Rule.Value)
                }
                "Integer" {
                  $AdditionalRequirementRuleParams.add("IntegerOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("IntegerComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("IntegerValue", $Rule.Value)
                }
                "Boolean" {
                  $AdditionalRequirementRuleParams.add("BooleanOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("BooleanComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("BooleanValue", $Rule.Value)
                }
                "DateTime" {
                  $AdditionalRequirementRuleParams.add("DateTimeOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("DateTimeComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("DateTimeValue", $Rule.Value)
                }
                "Float" {
                  $AdditionalRequirementRuleParams.add("FloatOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("FloatComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("FloatValue", $Rule.Value)
                }
                "Version" {
                  $AdditionalRequirementRuleParams.add("VersionOutputDataType", $true)
                  $AdditionalRequirementRuleParams.add("VersionComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("VersionValue", $Rule.Value)
                }
              }
              $AdditionalRequirementRule += $(New-IntuneWin32AppRequirementRuleScript @AdditionalRequirementRuleParams)
            }
            "File" {
              <#
              # "AdditionalRequirementRule": [
              #  {
              #    "id": 0,
              #    "RuleType": "File",
              #    "OutputDataType": "Version",
              #    "Path": "C:\\IntuneApps\\scripts\\ChassisType.ps1",
              #    "ComparisonOperator": "equal",
              #    "Value": "8.0.0",
              #    "Check32BitOn64System": "0",
              #    "EnforceSignatureCheck": "0"
              #  }
              # ],
              #>
              $AdditionalRequirementRuleParams = @{}     
              $AdditionalRequirementRuleParams = @{
                "Path" = $Rule.Path
                "FileOrFolder" = $Rule.FileOrFolder
                "Check32BitOn64System" = [bool]$Rule.Check32BitOn64System
              }

              Switch ($Rule.OutputDataType) {
                "Existence" {
                  $AdditionalRequirementRuleParams.add("Existence", $true)
				          $AdditionalRequirementRuleParams.add("FileOrFolder", $Rule.FileOrFolder)
                  $AdditionalRequirementRuleParams.add("DetectionType", $Rule.ComparisonOperator)
                }
                "DateModified" {
                  $AdditionalRequirementRuleParams.add("DateModified", $true)
                  $AdditionalRequirementRuleParams.add("Operator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("DateTimeValue", $Rule.Value)
                }
                "DateCreated" {
                  $AdditionalRequirementRuleParams.add("DateCreated", $true)
                  $AdditionalRequirementRuleParams.add("Operator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("DateTimeValue", $Rule.Value)
                }
                "Version" {
                  $AdditionalRequirementRuleParams.add("Version", $true)
                  $AdditionalRequirementRuleParams.add("Operator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("VersionValue", $Rule.Value)
                }
                "Size" {
                  $AdditionalRequirementRuleParams.add("Size", $true)
                  $AdditionalRequirementRuleParams.add("Operator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("SizeInMBValue", $Rule.Value)
                }
              }
              $AdditionalRequirementRule += $(New-IntuneWin32AppRequirementRuleFile @AdditionalRequirementRuleParams)
            }
            "Registry" {
              <#
              # "AdditionalRequirementRule": [
              #  {
              #    "id": 0,
              #    "RuleType": "Registry",
              #    "OutputDataType": "Version",
              #    "Path": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{2997FB52-F493-4644-BCD6-F00816479D3A}",
              #    "ValueName": "DisplayVersion",
              #    "ComparisonOperator": "greaterThanOrEqual",
              #    "Value": "8.8.1",
              #    "Check32BitOn64System": "0"
              #  }
              # ],
              #>
              $AdditionalRequirementRuleParams = @{}     
              $AdditionalRequirementRuleParams = @{
                "KeyPath" = $Rule.Path
                "ValueName" = $Rule.ValueName
                "Check32BitOn64System" = [bool]$Rule.RunAs32BitOn64System
              }

              Switch ($Rule.OutputDataType) {
                "Existence" {
                  $AdditionalRequirementRuleParams.add("Existence", $true)
                  $AdditionalRequirementRuleParams.add("DetectionType", $Rule.ComparisonOperator)
                }
                "String" {
                  $AdditionalRequirementRuleParams.add("StringComparison", $true)
                  $AdditionalRequirementRuleParams.add("StringComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("StringComparisonValue", $Rule.Value)
                }
                "Version" {
                  $AdditionalRequirementRuleParams.add("VersionComparison", $true)
                  $AdditionalRequirementRuleParams.add("VersionComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("VersionComparisonValue", $Rule.Value)
                }
                "Integer" {
                  $AdditionalRequirementRuleParams.add("IntegerComparison", $true)
                  $AdditionalRequirementRuleParams.add("IntegerComparisonOperator", $Rule.ComparisonOperator)
                  $AdditionalRequirementRuleParams.add("IntegerComparisonValue", $Rule.Value)
                }
              }
              $AdditionalRequirementRule += $(New-IntuneWin32AppRequirementRuleRegistry @AdditionalRequirementRuleParams)
            }
          }
        }
        IF ($AdditionalRequirementRule) {$AppParams.add("AdditionalRequirementRule", $AdditionalRequirementRule)} # Not required, validated null or empty
      #endregion Additional Requirement Rules

      #region Detection Rules
        Write-Verbose -Message "Preparing package detection rules"
        foreach ($Detection in $BuildDetectionRules) {
            $DetectionRuleParams = @{}
            Switch ($Detection.Detection) {
                "MSI"
                {
                  $DetectionRuleParams = @{
                    "ProductCode" = $Detection.ProductCode # Required
                    "ProductVersionOperator" = $Detection.ProductVersionOperator # Not required, default notConfigured - "notConfigured", "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
                    "ProductVersion" = $Detection.ProductVersion # Not required, default [String]::empty
                  }
                  $DetectionRule += $(New-IntuneWin32AppDetectionRuleMSI @DetectionRuleParams)
                }

                "Script"
                {
                  $DetectionRuleParams = @{
                    "ScriptFile" = $Detection.ScriptFile # Required for all
                    "EnforceSignatureCheck" = $Detection.EnforceSignatureCheck # Not required, default false
                    "RunAs32Bit" = $Detection.RunAs32Bit  # Not required, default false
                  }
                  $DetectionRule += $(New-IntuneWin32AppDetectionRuleScript @DetectionRuleParams)
                }

                "File"
                {
                  $DetectionRuleParams = @{                    
                    "Path" = $Detection.Path #Required for all
                    "FileOrFolder" = $Detection.FileOrFolder #Required for all
                    "Check32BitOn64System" = [bool]$Detection.Check32BitOn64System #Not required, default false
                  }

                  Switch ($Detection.DetectionMethod) ## "Existence" / "DateModified" / "DateCreated" / "Version" / "Size"
                  {
                    "Existence" {
                      $DetectionRuleParams.add("Existence", $true)
                      $DetectionRuleParams.add("DetectionType", $Detection.ComparisonOperator)
                    }
                    "DateModified" {
                      $DetectionRuleParams.add("DateModified", $true)
                      $DetectionRuleParams.add("Operator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("DateTimeValue", $Detection.Value)
                    }
                    "DateCreated" {
                      $DetectionRuleParams.add("DateCreated", $true)
                      $DetectionRuleParams.add("Operator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("DateTimeValue", $Detection.Value)
                    }
                    "Version" {
                      $DetectionRuleParams.add("Version", $true)
                      $DetectionRuleParams.add("Operator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("VersionValue", $Detection.Value)
                    }
                    "Size" {
                      $DetectionRuleParams.add("Size", $true)
                      $DetectionRuleParams.add("Operator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("SizeInMBValue", $Detection.Value)
                    }
                  }

                  $DetectionRule += $(New-IntuneWin32AppDetectionRuleFile @DetectionRuleParams)
                }

                "Registry"
                {
                  $DetectionRuleParams = @{
                    "KeyPath" = $Detection.KeyPath #Not Required, default null
                    "ValueName" = $Detection.ValueName #Required for all
                    "Check32BitOn64System" = $Detection.Check32BitOn64System #Not required, default false
                  }

                  Switch ($Detection.DetectionMethod) ## "Existence" / "StringComparison" / "VersionComparison" / "IntegerComparison"
                  {
                    "Existence" {
                      $DetectionRuleParams.add("Existence", $true)
                      $DetectionRuleParams.add("DetectionType", $Detection.DetectionType)
                    }
                    "StringComparison" {
                      $DetectionRuleParams.add("StringComparison", $true)
                      $DetectionRuleParams.add("StringComparisonOperator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("StringComparisonValue", $Detection.Value)
                    }
                    "VersionComparison" {
                      $DetectionRuleParams.add("VersionComparison", $true)
                      $DetectionRuleParams.add("VersionComparisonOperator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("VersionComparisonValue", $Detection.Value)
                    }
                    "IntegerComparison" {
                      $DetectionRuleParams.add("IntegerComparison", $true)
                      $DetectionRuleParams.add("IntegerComparisonOperator", $Detection.ComparisonOperator)
                      $DetectionRuleParams.add("IntegerComparisonValue", $Detection.Value)
                    }
                  }

                  $DetectionRule += $(New-IntuneWin32AppDetectionRuleRegistry @DetectionRuleParams)
                }
            }
        }
        IF ($DetectionRule) {$AppParams.add("DetectionRule", $DetectionRule)} # required
      #endregion Detection Rules

      #region Add App
        Write-Output -InputObject "Adding $($BuildAppInfo.DisplayName) Win32App to Endpoint Manager"
        $retryCount = 0
        do {
          $retryCount += 1
          Write-Debug -Message "RetryCount = $retryCount"
          $NewWin32App = Add-IntuneWin32App @AppParams #ReturnCode # Not required, validated null or empty
          #Write-Output $NewWin32App
          IF ($NewWin32App.size -eq 0) {
            Write-Warning -Message "Upload Failed Attempting Again...Cleaning up Orphans and Pausing for 3 Seconds"
            $GraphURI = "https://graph.microsoft.com/Beta/deviceAppManagement/mobileApps/$($NewWin32App.id)"
            $GraphResponse = Invoke-RestMethod -Uri $GraphURI -Headers $Global:AuthenticationHeader -Method "DELETE" -ErrorAction Stop -Verbose:$false 
            Start-Sleep -Seconds 3
            IF ($retryCount -eq 3){
              Write-Error -Message "Upload failed 3 attempts, skipping to next package."
            }
          }
        } while ($NewWin32App.size -eq 0 -and $retryCount -le 3)
        Write-Output -InputObject "App $($BuildAppInfo.DisplayName) added to Endpoint Manager"
      #endregion Add App

      #region App Dependencies
        <#
          "Dependencies":[
          {
            "displayName": "",
            "displayVersion": "",
            "dependencyType: ""
          }
          ],
        #>
        Write-Output -InputObject "Assigning Dependencies"
        foreach ($Dependency in $BuildDependencies){
          foreach ($app in $Win32Apps) {
            IF ($app.displayName -eq $Dependency.displayName -and $app.displayVersion -eq $Dependency.displayVersion){
              $Win32AppDependency = $app
              break
            }else {
              $Win32AppDependency = $null
            }
          }
          
          $DependencyParms = @{
            "id" = $Win32AppDependency.id
            "DependencyType" = $Dependency.DependencyType
          }
          $Dependencies += $(New-IntuneWin32AppDependency  @DependencyParms)
        }
        IF ($Dependencies) {$Win32AppDependency = Add-IntuneWin32AppDependency -ID $NewWin32App.id -Dependency $Dependencies} # Not required, validated null or empty
      #endregion App Dependencies

      #region App Supersedence
        <#
        "Supersedence":[
          {
          "displayName": "",
          "displayVersion": "",
          "SupersedenceType: "Replace"
          }
        ],
        #>
        Write-Output -InputObject "Assigning Supersedence"
        foreach ($Supersedence in $BuildSupersedences){
          foreach ($app in $Win32Apps) {
            IF ($app.displayName -eq $Supersedence.displayName -and $app.displayVersion -eq $Supersedence.displayVersion){
              $Win32AppSupersedence = $app
              break
            }else {
              $Win32AppSupersedence = $null
            }
          }
          
          $SupersedenceParms = @{
            "id" = $Win32AppSupersedence.id
            "SupersedenceType" = $Supersedence.SupersedenceType
          }
          $Supersedences += $(New-IntuneWin32AppSupersedence  @SupersedenceParms)
        }
        IF ($Supersedences) {$Win32AppSupersedence = Add-IntuneWin32AppSupersedence -ID $NewWin32App.id -Supersedence $Supersedences} # Not required, validated null or empty
      #endregion App Supersedence

      #region App Assignment
        Write-Output -InputObject "Assigning Assignments"
		ForEach ($Assignment in $BuildAssignments){
			Switch ($Assignment.Target){
			  "AllUsers" 
			  {
				  $AssignmentParams = @{
					  "id" = $NewWin32App.id # Required
					  "Intent" = $Assignment.Intent # Required "required", "available", "uninstall"
				  }
				  IF ($Assignment.Notification) {$AssignmentParams.add("Notification", $Assignment.Notification)} # Not Required, default "showAll" - "showAll", "showReboot", "hideAll"
				  IF ($Assignment.AvailableTime) {$AssignmentParams.add("AvailableTime", $Assignment.AvailableTime)} # Not required, validated null or empty
				  IF ($Assignment.DeadlineTime) {$AssignmentParams.add("DeadlineTime", $Assignment.DeadlineTime)} # Not required, validated null or empty
				  IF ($Assignment.UseLocalTime) {$AssignmentParams.add("UseLocalTime", $Assignment.UseLocalTime)} # Not required, default false
				  IF ($Assignment.DeliveryOptimizationPriority) {$AssignmentParams.add("DeliveryOptimizationPriority", $Assignment.DeliveryOptimizationPriority)} # Not required, default "notConfigured" - "notConfigured", "foreground"
				  IF ($Assignment.EnableRestartGracePeriod) {$AssignmentParams.add("EnableRestartGracePeriod", $Assignment.EnableRestartGracePeriod)} # Not required, default false
				  IF ($Assignment.RestartGracePeriod) {$AssignmentParams.add("RestartGracePeriod", $Assignment.RestartGracePeriod)} # Not required, default 1440 - 1-20160
				  IF ($Assignment.RestartCountDownDisplay) {$AssignmentParams.add("RestartCountDownDisplay", $Assignment.RestartCountDownDisplay)} # Not required, default 15 - 1-240
				  IF ($Assignment.RestartNotificationSnooze) {$AssignmentParams.add("RestartNotificationSnooze", $Assignment.RestartNotificationSnooze)} # Not required, default 240 - 1-712

				  $Win32AppAssignment += Add-IntuneWin32AppAssignmentAllUsers @AssignmentParams         
			  }
			  "AllDevices" 
			  {        
				  $AssignmentParams = @{
					  "id" = $NewWin32App.id # Required
					  "Intent" = $Assignment.Intent # Required "required", "available", "uninstall"
				  }
				  IF ($Assignment.Notification) {$AssignmentParams.add("Notification", $Assignment.Notification)} # Not Required, default "showAll" - "showAll", "showReboot", "hideAll"
				  IF ($Assignment.AvailableTime) {$AssignmentParams.add("AvailableTime", $Assignment.AvailableTime)} # Not required, validated null or empty
				  IF ($Assignment.DeadlineTime) {$AssignmentParams.add("DeadlineTime", $Assignment.DeadlineTime)} # Not required, validated null or empty
				  IF ($Assignment.UseLocalTime) {$AssignmentParams.add("UseLocalTime", $Assignment.UseLocalTime)} # Not required, default false
				  IF ($Assignment.DeliveryOptimizationPriority) {$AssignmentParams.add("DeliveryOptimizationPriority", $Assignment.DeliveryOptimizationPriority)} # Not required, default "notConfigured" - "notConfigured", "foreground"
				  IF ($Assignment.EnableRestartGracePeriod) {$AssignmentParams.add("EnableRestartGracePeriod", $Assignment.EnableRestartGracePeriod)} # Not required, default false
				  IF ($Assignment.RestartGracePeriod) {$AssignmentParams.add("RestartGracePeriod", $Assignment.RestartGracePeriod)} # Not required, default 1440 - 1-20160
				  IF ($Assignment.RestartCountDownDisplay) {$AssignmentParams.add("RestartCountDownDisplay", $Assignment.RestartCountDownDisplay)} # Not required, default 15 - 1-240
				  IF ($Assignment.RestartNotificationSnooze) {$AssignmentParams.add("RestartNotificationSnooze", $Assignment.RestartNotificationSnooze)} # Not required, default 240 - 1-712

				  $Win32AppAssignment += Add-IntuneWin32AppAssignmentAllDevices @AssignmentParams        
			  }
			  "Groups"
			  {        
				  
				  $AssignmentParams = @{
					  "id" = $NewWin32App.id # Required
					  "Intent" = $Assignment.Intent # Required "required", "available", "uninstall"
					  "GroupID" = $Assignment.GroupID #Required Specify the ID for an Azure AD group.
				  }

				  Switch ($Assignment.GroupMode) ## "Include" / "Exclude"
				  {
					  "Include" {$AssignmentParams.add("Include", $true)}
					  "Exclude" {$AssignmentParams.add("Exclude", $true)}
				  }
				  IF ($Assignment.Notification) {$AssignmentParams.add("Notification", $Assignment.Notification)} # Not Required, default "showAll" - "showAll", "showReboot", "hideAll"
				  IF ($Assignment.AvailableTime) {$AssignmentParams.add("AvailableTime", $Assignment.AvailableTime)} # Not required, validated null or empty
				  IF ($Assignment.DeadlineTime) {$AssignmentParams.add("DeadlineTime", $Assignment.DeadlineTime)} # Not required, validated null or empty
				  IF ($Assignment.UseLocalTime) {$AssignmentParams.add("UseLocalTime", $Assignment.UseLocalTime)} # Not required, default false
				  IF ($Assignment.DeliveryOptimizationPriority) {$AssignmentParams.add("DeliveryOptimizationPriority", $Assignment.DeliveryOptimizationPriority)} # Not required, default "notConfigured" - "notConfigured", "foreground"
				  IF ($Assignment.EnableRestartGracePeriod) {$AssignmentParams.add("EnableRestartGracePeriod", $Assignment.EnableRestartGracePeriod)} # Not required, default false
				  IF ($Assignment.RestartGracePeriod) {$AssignmentParams.add("RestartGracePeriod", $Assignment.RestartGracePeriod)} # Not required, default 1440 - 1-20160
				  IF ($Assignment.RestartCountDownDisplay) {$AssignmentParams.add("RestartCountDownDisplay", $Assignment.RestartCountDownDisplay)} # Not required, default 15 - 1-240
				  IF ($Assignment.RestartNotificationSnooze) {$AssignmentParams.add("RestartNotificationSnooze", $Assignment.RestartNotificationSnooze)} # Not required, default 240 - 1-712

				  $Win32AppAssignment += Add-IntuneWin32AppAssignmentGroup @AssignmentParams 
			  }
			} 
		}
      #endregion App Assignement      

      #region App Category
        Write-Output -InputObject "Assigning category"
        $Category = $CategoryList | where-object {$_.displayName -eq $BuildAppInfo.Category}
        Write-Verbose -Message "Adding app to category: $($BuildAppInfo.Category)"
        $GraphURI = "https://graph.microsoft.com/Beta/deviceAppManagement/mobileApps/$($NewWin32App.id)/categories/`$ref"
        $CategoryBody = @{
            "@odata.id" = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppCategories/$($Category.ID)"
        } | ConvertTo-Json
        $GraphResponse = Invoke-RestMethod -Uri $GraphURI -Headers $Global:AuthenticationHeader -Method "POST" -Body $CategoryBody -ContentType "application/json" -ErrorAction Stop -Verbose:$false 
      #endregion App Category

        # IF ($Win32App) {
        #     Write-Verbose -Message "Removing old version from remote catalog"
        #     $GraphURI = "https://graph.microsoft.com/Beta/deviceAppManagement/mobileApps/$($Win32App.id)"
        #     $GraphResponse = Invoke-RestMethod -Uri $GraphURI -Headers $Global:AuthenticationHeader -Method "DELETE" -ErrorAction Stop -Verbose:$false 
        # }
        Write-Output -InputObject "Finished W32 App Check on $($BuildAppInfo.DisplayName)"

    } ELSE {
        Write-Verbose -Message "A newer or equal version of $($BuildAppInfo.DisplayName) already exists in Intune, will not attempt to create new Win32 app"
    }
}