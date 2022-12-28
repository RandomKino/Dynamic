# Self Elevate

$myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$myWindowsPrincipal = New-Object System.Security.Principal.WindowsPrincipal($myWindowsID)
$adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
if ($myWindowsPrincipal.IsInRole($adminRole)) {
    $Host.UI.RawUI.WindowTitle = "Dynamic Technology Solutions"
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Clear-Host
} else {
    Start-Process PowerShell.exe -ArgumentList "-ExecutionPolicy Unrestricted $($script:MyInvocation.MyCommand.Path)" -Verb RunAs
    Exit
}
