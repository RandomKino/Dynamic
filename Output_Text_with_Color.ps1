# Usage: OutputText "Hello World" "Yellow"

function OutputText($Text,$Color){
    $j = $Text.Length
    for ($i = 1; $i -le $j; $i++) {
       $Lines = $Lines + "-"
    }
    Write-Host "`n"
    Write-Host $Lines
    $Host.UI.RawUI.BackgroundColor = $Color
    Write-Host $Text
    $Host.UI.RawUI.BackgroundColor = "DarkBlue"
    Write-Host $Lines
}
