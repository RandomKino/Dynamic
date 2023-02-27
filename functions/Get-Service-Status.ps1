# Return service running status
# Return boolean, true = running, false = stopped
# Usage: Get-Service-Status ("Service_Name")

function Get-Service-Status {
    param (
        $ServiceName
    )
    $WTStatus = (Get-Service -Name ($ServiceName)).Status
    if ($WTStatus -eq "Running") {
    Return $true
    } else {
    Return $false
    }
}
