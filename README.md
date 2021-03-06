# IntuneWin32AppDeployments

Deployment Scripts for Win32Apps in Intune

This is a compilation of deployments and the base core to template new apps with automated deployment into your Intune tenant.

## Goal

My initial goal was to create a build kit that could potentially be integrated to a CV\CI to help the automation of application updates in our organization. As I started developing for private applications in our organization to start, this morphed quickly into a possible WinGet solution. Once a package template has been created there are minimal changes that you need to make when updating to a newer version and “one-click” deployment into Intune for new or updated applications. With the introduction to WinGet this opened a new path for managing publicly available applications.

## Initial Complications - WinGet

WinGet took a little time to get working smoothly, however all the apps listed in this repository should install via the system context without issue. As new applications are added verification is needed on the https://github.com/microsoft/winget-pkgs repository for said application to ensure that it at least has a “machine scope”. If this scope is missing the application will fail due to the required scope parameter in the install.ps1 scripts. This ensures that the application can be installed in the system context.

The system context requirement was set in place because we wanted our users to be able to install approved applications without helpdesk performing the task.

## Dependencies

- IntuneWin32App - https://www.powershellgallery.com/packages/IntuneWin32App/1.3.2
  - All dependences required for this app.
- IntuneWinAppUtil - https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
  - Place this executable in your root working directory, same location as BuildApps.ps1

## Supported Features

- Templating applications using ".Build" files a simple JSON file configuring how the app will deploy into Intune
- Supporting most features including
  - Multiple Detection Rules
  - Multiple Additional Requirement Rules
  - Multiple Group Assignments
  - Multiple Dependences
  - Multiple Supersedence
- Using Graph API to assign App Category after deployment

## Known Issues

- App Naming is quite specific.
  - Folder name and build name must have the same name. It was easier at the time to pass a single variable based on the folder name to load the .build. This can be addressed with additional coding but it works for me.
- Issue deploying .intunewin into Intune
  - It has been common for Intune to throw a 403 error when the script attempts to upload the app to Intune.
  - There is a 3 attempt retry script to help mitigate this issue.
  - I have not been able to narrow this down but I think it’s a timing issue, not enough time between app creation and app upload. However, it is not consistent.

## Instructions
- Install Dependencies as directed above. 
- Rename settings.json.dist to settings.json and update the tenantID to match your tenant. 
- Rename build files to remove .dist use the following script to make copy's of everything
    ```powershell
    $BuildDir = "C:\IntuneWin32AppDeployments" # Where ever the root dir is for this repository
    Get-ChildItem "$BuildDir\Winget-Pkgs", "$BuildDir\Win32App-Pkgs", "$BuildDir\Private-Pkgs" -Directory | where-object { $_.Name -notin $Settings.Folders.Exclusions } | foreach-object {
        set-location $($_.FullName)                                         
        Copy-Item -Path "$($_.Name).build.dist" -Destination "$($_.Name).build"                              
    }
    ```
- Within the root directory run the following from Admin PS
  - *** IMPORTANT *** This will disable FIPS in order to run IntuneWinAppUtil - Ref lines 33-38
  - ```.\BuildApps.ps1```  - 
- This will start to deploy all the apps listed in the current folder. If you want to exclude any you can go to line 55 to add exclusions. 
- Optional Lines 122-126 are available to force a republish of all apps or adjust to define apps to republish to Intune. 

## ToDo

https://github.com/users/CodyRWhite/projects/2/views/1

## Latest .Build Template

### Application Information

```jsonc
 "AppInformation": {
    "DisplayName": "Microsoft Teams", // Display name that will show up in Intune/Company Portal for the app
    "Description": "Microsoft Teams is a proprietary business communication platform developed by Microsoft, as part of the Microsoft 365 family of products. Teams primarily competes with the similar service Slack, offering workspace chat and videoconferencing, file storage, and application integration.",
    "Publisher": "Microsoft",
    "DisplayVersion": "1.0.0.0",
    "Category": "Collaboration & Social", //Options: "Other Apps", "Books & Reference", "Data Management", "Productivity", "Business", "Development & Design", "Photos & Media", "Collaboration & Social", "Computer Management"
    "CompanyPortalFeaturedApp": 0, //Options: 0,1
    "InformationURL": "https://www.microsoft.com/en-ca/microsoft-teams/log-in",
    "PrivacyURL": "https://go.microsoft.com/fwlink/?LinkId=521839",
    "Developer": "Microsoft",
    "Owner": "",
    "Notes": "",
    "Logo": "C:\\IntuneApps\\Icons\\Export-Teams.png"
  }
```

### Program Information

```jsonc
"ProgramInformation": {
  "InstallFile": "Install.ps1", // This is the "primary" file that will be used when invoking IntuneWunAppUtil
  "InstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1 Microsoft.Teams",
  "UninstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 Microsoft.Teams",
  "InstallExperience": "system", //Options: "system", "user"
  "RestartBehavior": "suppress" //Options: "allow", "basedOnReturnCode", "suppress", "force"
}
```

### Custom Return Codes

_Coming Soon_

### Requirement Rule

```jsonc
"RequirementRule": {
  "Architecture": "x86", //Options: "x64", "x86", "All"
  "MinimumSupportedOperatingSystem": "2004", //Options: "1607", "1703", "1709", "1803", "1809", "1903", "1909", "2004", "20H2", "21H1"
  "MinimumFreeDiskSpaceInMB": "",
  "MinimumMemoryInMB": "",
  "MinimumNumberOfProcessors": "",
  "MinimumCPUSpeedInMHz": ""
}
```

### Additional Requirement Rule

#### Script

```jsonc
{
  "id": 0,
  "RuleType": "Script",
  "OutputDataType": "String", //Options: "String", "Integer", "Boolean", "DateTime", "Float", "Version"
  "ScriptFile": "C:\\IntuneApps\\scripts\\ChassisType.ps1", //Full path to script on your system to be uploaded to Intune
  "ScriptContext": "system", //Options: "system", "user"
  "ComparisonOperator": "equal", //Options: Changes based on OutputDataType "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "isDesktop", //This handles all comparitor input values.
  "RunAs32BitOn64System": "0", //Options: 0,1
  "EnforceSignatureCheck": "0" //Options: 0,1
}
```

#### File

```jsonc
{
  "id": 0,
  "RuleType": "File",
  "OutputDataType": "Version", //Options: "Existence", "DateModified", "DateCreated", "Version", "Size"
  "Path": "C:\\folder\\", //Path to file on deployed computer
  "FileOrFolder": "file.ext",
  "ComparisonOperator": "equal", //Options: Changes based on OutputDataType "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "8.0.0", //This handles all comparitor input values.
  "RunAs32BitOn64System": "0" //Options: 0,1
}
```

#### Registry

```jsonc
{
  "id": 0,
  "RuleType": "Registry",
  "OutputDataType": "Existence", //Options: "Existence","StringComparison","VersionComparison","IntegerComparison"
  "Path": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{2997FB52-F493-4644-BCD6-F00816479D3A}", // Registry Key Path
  "ValueName": "DisplayVersion", // Registry Key or Item
  "ComparisonOperator": "greaterThanOrEqual", //Options: Changes based on OutputDataType "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "8.8.1", //This handles all comparitor input values.
  "Check32BitOn64System": "0" //Options: 0,1
}
```

### Detection Rules

#### File

```jsonc
{
  "id": 0,
  "Detection": "File",
  "DetectionMethod": "Existence", //Options: "Existence", "DateModified", "DateCreated", "Version", "Size"
  "Path": "C:\\Folder\\Folder",
  "FileOrFolder": "file.ext",
  "ComparisonOperator": "Operator", //Options: Changes based on DetectionMethod "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "", //Required for "DateModified", "DateCreated", "Version", "Size"
  "Check32BitOn64System": 1 //Options: 0,1
}
```

#### MSI

```jsonc
{
  "id": 0,
  "Detection": "MSI",
  "ProductCode": "{523727B0-D5D5-4392-935B-BFEAA70F29A6}", // MSI Product Code
  "ProductVersionOperator": "equal", //Options: "notConfigured", "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "ProductVersion": "3.4.4.1179"
}
```

#### Registry

```jsonc
{
  "id": 0,
  "Detection": "Registry",
  "DetectionMethod": "Existence", //Options: "Existence", "StringComparison", "VersionComparison", "IntegerComparison"
  "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\",
  "ValueName": "DisplayVersion",
  "ComparisonOperator": "exists", //Options: Changes based on DetectionMethod "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "", //Required for "StringComparison", "VersionComparison", "IntegerComparison"
  "Check32BitOn64System": 1 //Options: 0,1
}
```

#### Script

```jsonc
{
  "id": 0,
  "Detection": "Script",
  "ScriptFile": "C:\\Folder\\File.ps1",
  "EnforceSignatureCheck": 0, //Options: 0,1
  "RunAs32Bit": 1 //Options: 0,1
}
```

### Dependencies

```jsonc
  "Dependencies": [
    {
      "displayName": "App Display Name already in Intune",
      "displayVersion": "1.0.0.0",
      "dependencyType": "AutoInstall" //Options: "AutoInstall", "Detect"
    }
  ],
```

### Supersedence

```jsonc
  "Supersedence": [
    {
      "displayName": "App Display Name already in Intune",
      "displayVersion": "1.0.0.0",
      "supersedenceType": "Replace" //Options: "Replace", "Update"
    }
  ],
```

### Assignments

```jsonc
  "assignments": [
    {
      "Target": "AllDevices", //Options: "AllUsers", "AllDevices", "Group"
      "Intent": "Required", //Options: "required", "available", "uninstall" -- $null/default = "available"
      "GroupMode": "", //Options: "Include", "Exclude" -- Only required when Target == Group // $null/default = "Include"
      "GroupID": "", //This is the Azure Object ID of the Group -- Only required when Target == Group
      "Notification": "hideAll", //Options: "showAll", "showReboot", "hideAll" -- $null/default = "showAll"
      "AvailableTime": "",
      "DeadlineTime": "",
      "UseLocalTime": "", //Options: 0,1 -- $null/default = 0
      "DeliveryOptimizationPriority": "notConfigured", //Options: "notConfigured", "foreground" -- $null/default = "notConfigured"
      "EnableRestartGracePeriod": "", //Options: 0,1 -- $null/default = 0
      "RestartGracePeriod": "", //Options: Any integer between 1 and 20160 -- $null/default = 1440
      "RestartCountDownDisplay": "", //Options: Any integer between 1 and 240 -- $null/default = 15
      "RestartNotificationSnooze": "" //Options: Any integer between 1 and 710 -- $null/default = 240
    }
  ]
}
```

### Sample Build File

```jsonc
{
  "AppInformation": {
    "DisplayName": "Desktop App Installer",
    "Description": "Desktop installer for winget package manager",
    "Publisher": "Microsoft",
    "DisplayVersion": "1.0.0.0",
    "Category": "Computer Management",
    "CompanyPortalFeaturedApp": 0,
    "InformationURL": "",
    "PrivacyURL": "",
    "Developer": "Microsoft",
    "Owner": "",
    "Notes": "",
    "Logo": ""
  },
  "ProgramInformation": {
    "InstallFile": "Install.ps1",
    "InstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1 DesktopAppInstaller",
    "UninstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 DesktopAppInstaller",
    "InstallExperience": "system",
    "RestartBehavior": "suppress",
    "ReturnCode": ""
  },
  "RequirementRule": {
    "Architecture": "All",
    "MinimumSupportedOperatingSystem": "2004",
    "MinimumFreeDiskSpaceInMB": "",
    "MinimumMemoryInMB": "",
    "MinimumNumberOfProcessors": "",
    "MinimumCPUSpeedInMHz": ""
  },
  "DetectionRules": [
    {
      "id": 0,
      "Detection": "Script",
      "ScriptFile": "C:\\IntuneApps\\scripts\\winget_detections\\DesktopAppInstaller_detection.ps1",
      "EnforceSignatureCheck": 0,
      "RunAs32Bit": 0
    }
  ],
  "Dependencies": [],
  "assignments": [
    {
      "Target": "AllUsers",
      "Intent": "Required",
      "Notification": "hideAll",
      "AvailableTime": "",
      "DeadlineTime": "",
      "UseLocalTime": "",
      "DeliveryOptimizationPriority": "notConfigured",
      "EnableRestartGracePeriod": "",
      "RestartGracePeriod": "",
      "RestartCountDownDisplay": "",
      "RestartNotificationSnooze": ""
    }
  ]
}
```
