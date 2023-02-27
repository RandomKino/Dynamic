Set-Variable -Name desktopIniContent -Option ReadOnly -value ([string]"[.ShellClassInfo]`r`nCLSID2={0AFACED1-E828-11D1-9187-B532F1E9575D}`r`nFlags=2")

$networkLocationPath = "$env:APPDATA\Microsoft\Windows\Network Shortcuts"

[void]$(New-Item -Path "$networkLocationPath\Checklist" -ItemType Directory -ErrorAction Stop)

Set-ItemProperty -Path "$networkLocationPath\Checklist" -Name Attributes -Value ([System.IO.FileAttributes]::System) -ErrorAction Stop

[object]$desktopIni = New-Item -Path "$networkLocationPath\Checklist\desktop.ini" -ItemType File

Add-Content -Path $desktopIni.FullName -Value $desktopIniContent

$WshShell = New-Object -ComObject WScript.Shell

$Shortcut = $WshShell.CreateShortcut("$networkLocationPath\Checklist\target.lnk")
$Shortcut.TargetPath = "\\192.168.254.159\scans\Checklists\Kino"
$Shortcut.Save()
