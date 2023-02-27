# Return Windows Activation status
# Return boolean, true = activated, false = not activated.

function Get-Activation-Status {
    $ACTRESULT = (cscript C:\Windows\System32\slmgr.vbs /xpr | Select-Object -index 4).ToString().Trim()

    if ($ACTRESULT -eq "The machine is permanently activated.") {
        Return $true
    } else {
        Return $false
    }
}
