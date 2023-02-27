# Clear Quick Access history for current user
# It may not just delete bt reset Quick Access

function Clear-Quick-Access {
    Get-ChildItem -Path ($env:USERPROFILE + "\AppData\Roaming\Microsoft\Windows\Recent") -Include *.* -File -Recurse | Foreach { $_.Delete()}
    Get-ChildItem -Path ($env:USERPROFILE + "\AppData\Roaming\Microsoft\Windows\Recent\AutomaticDestinations") -Include *.* -File -Recurse | Foreach { $_.Delete()}
}
