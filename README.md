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

```jsonc
{
  "AppInformation": {
    "DisplayName": "Microsoft Teams",
    "Description": "Microsoft Teams is a proprietary business communication platform developed by Microsoft, as part of the Microsoft 365 family of products. Teams primarily competes with the similar service Slack, offering workspace chat and videoconferencing, file storage, and application integration.",
    "Publisher": "Microsoft",
    "DisplayVersion": "1.0.0.0",
    "Category": "Collaboration & Social",
    "CompanyPortalFeaturedApp": 0,
    "InformationURL": "https://www.microsoft.com/en-ca/microsoft-teams/log-in",
    "PrivacyURL": "https://go.microsoft.com/fwlink/?LinkId=521839",
    "Developer": "Microsoft",
    "Owner": "",
    "Notes": "",
    "Logo": "C:\\IntuneApps\\Icons\\Export-Teams.png"
  },
  "ProgramInformation": {
    "InstallFile": "Install.ps1",
    "InstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Install.ps1 Microsoft.Teams",
    "UninstallCommandLine": "PowerShell.exe -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 Microsoft.Teams",
    "InstallExperience": "system",
    "RestartBehavior": "suppress",
    "ReturnCode": ""
  },
  "RequirementRule": {
    "Architecture": "x86",
    "MinimumSupportedOperatingSystem": "2004",
    "MinimumFreeDiskSpaceInMB": "",
    "MinimumMemoryInMB": "",
    "MinimumNumberOfProcessors": "",
    "MinimumCPUSpeedInMHz": ""
  },
  "AdditionalRequirementRule": [
    {
      "id": 0,
      "RuleType": "File",
      "OutputDataType": "Existence",
      "Path": "C:\\Folder\\Folder",
      "FileOrFolder": "file.ext",
      "ComparisonOperator": "exists",
      "Check32BitOn64System": 1
    }
  ],
  "DetectionRules": [
    {
      "id": 0,
      "Detection": "File",
      "DetectionMethod": "Existence",
      "Path": "C:\\Folder\\Folder",
      "FileOrFolder": "file.ext",
      "DetectionType": "exists",
      "Check32BitOn64System": 1
    }
  ],
  "Dependencies": [
    {
      "displayName": "App Display Name already in Intune",
      "displayVersion": "1.0.0.0",
      "dependencyType": "AutoInstall"
    }
  ],
  "Supersedence": [
    {
      "displayName": "App Display Name already in Intune",
      "displayVersion": "1.0.0.0",
      "supersedenceType": "Replace"
    }
  ],
  "assignments": [
    {
      "Target": "AllDevices",
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

### Additional Requirement Rule

#### Script

```jsonc
{
  "id": 0,
  "RuleType": "Script",
  "OutputDataType": "String", //Options: String, Integer, Boolean, DateTime, Float, Version
  "ScriptFile": "C:\\IntuneApps\\scripts\\ChassisType.ps1", //Full path to script on your system to be uploaded to Intune
  "ScriptContext": "system", //Options: System, User
  "ComparisonOperator": "equal", //Options: Changes based on OutputDataType "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "isDesktop", //Options: String
  "RunAs32BitOn64System": "0", //Options: 0,1
  "EnforceSignatureCheck": "0" //Options: 0,1
}
```

#### File

```jsonc
{
  "id": 0,
  "RuleType": "File",
  "OutputDataType": "Version", //Options: "Existence","DateModified","DateCreated","Version","Size"
  "Path": "C:\\folder\\", //Path to file on deployed computer
  "FileOrFolder": "file.ext",
  "ComparisonOperator": "equal", //Options: Changes based on OutputDataType "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "8.0.0", //This handles all comparitor input values, Date Version Size etc.
  "RunAs32BitOn64System": "0" //Options: 0,1
}
```

#### Registry

```jsonc
{
  "id": 0,
  "RuleType": "Registry",
  "OutputDataType": "Existence", //Options: "Existence","StringComparison","VersionComparison","IntegerComparison"
  "Path": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\{2997FB52-F493-4644-BCD6-F00816479D3A}",
  "ValueName": "DisplayVersion",
  "ComparisonOperator": "greaterThanOrEqual", //Options: Changes based on OutputDataType "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "8.8.1",
  "Check32BitOn64System": "0"
}
```

### Detection Rules

#### File

```jsonc
{
  "id": 0,
  "Detection": "File",
  "DetectionMethod": "Existence", //Options: "Existence","DateModified","DateCreated","Version","Size"
  "Path": "C:\\Folder\\Folder",
  "FileOrFolder": "file.ext",
  "ComparisonOperator": "Operator", //Options: Changes based on DetectionMethod "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "", //Required for "DateModified","DateCreated","Version","Size"
  "Check32BitOn64System": 1
}
```

#### MSI

```jsonc
{
  "id": 0,
  "Detection": "MSI",
  "ProductCode": "{523727B0-D5D5-4392-935B-BFEAA70F29A6}",
  "ProductVersionOperator": "equal",
  "ProductVersion": "3.4.4.1179"
}
```

#### Registry

```jsonc
{
  "id": 0,
  "Detection": "Registry",
  "DetectionMethod": "Existence", //Options: "Existence","StringComparison","VersionComparison","IntegerComparison"
  "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\",
  "ValueName": "DisplayVersion",
  "ComparisonOperator": "exists", //Options: Changes based on DetectionMethod "exists", "doesNotExist" // "equal", "notEqual", "greaterThanOrEqual", "greaterThan", "lessThanOrEqual", "lessThan"
  "Value": "", //Required for "StringComparison","VersionComparison","IntegerComparison"
  "Check32BitOn64System": 1
}
```

#### Script

```jsonc
{
	"id":0,
	"Detection":"Script",
	"ScriptFile":"C:\\Folder\\File.ps1",
	"EnforceSignatureCheck":0
	"RunAs32Bit":1
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
