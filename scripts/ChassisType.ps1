
$isLaptopArray = 8, 9, 10, 11, 12, 14, 18, 21
$isDesktopArray = 3, 4, 5, 6, 7, 15, 16
$isServerArray = 23

Switch ((Get-CimInstance -ClassName Win32_SystemEnclosure).ChassisTypes) 
{
    {$isLaptopArray -contains $_} {Write-Output "isLaptop"}
    {$isDesktopArray -contains $_} {Write-Output "isDesktop"}
    {$isServerArray -contains $_} {Write-Output "isServer"}
}