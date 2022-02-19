# IntuneWin32AppDeployments

Deployment Scripts for Win32Apps in Intune

This is a compolation of deployments and the base core to template new apps with automated deployment into your Intune tenanat.

## Dependencies

- IntuneWin32App - https://www.powershellgallery.com/packages/IntuneWin32App/1.2.1
  - All Denpendeces require for this app.
- IntuneWinAppUtil - https://github.com/microsoft/Microsoft-Win32-Content-Prep-Tool
  - Place this excutable in your root working dir, same location as BuildApps.ps1

## Supported Features

- Templating applications using ".Build" files a stimple JSON file configuring how the app will deploy into Intune
- Supporting most features including
  - Multiple Detection Rules
  - Multiple Additional Requirement Rules
  - Multuple Group Assignments
  - Multuple Dependences
  - Multiple Superceedence
- Using Graph API to assign App Category after deployment

## Known Issues

- App Naming is quite specific.
  - Folde rname, Build name, and Primary script all have to have the same name. It was eaiser at the time to pass a single variable based on the folder name to load the .build and pass the same name into IntuneWinAppUtil to build the .intunewin file. This can be addressed with additional coding but it works for me.
- Issue deploying .intunewin into Intune
  - It has been common for Intune to throw a 403 error when the script attempts to upload the app to intune.
  - This may leave stale items in intune to be cleaned up before a re-attempt
  - I have not been able to narrow this down but I think its a timing issue, not enouhg time between app creation and app upload. However it is not consistant.

## Latest .Build Template

### Application Information

```jsonc
 "AppInformation": {
    "DisplayName": "Microsoft Teams", // Display name that will show up in Intune/Company Portal for the app
    "Description": "Microsoft Teams is a proprietary business communication platform developed by Microsoft, as part of the Microsoft 365 family of products. Teams primarily competes with the similar service Slack, offering workspace chat and videoconferencing, file storage, and application integration.",
    "Publisher": "Microsoft",
    "DisplayVersion": "1.0.0.0",
    "Category": "Collaboration & Social", //Options:
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
  "ProductVersionOperator": "equal",
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
