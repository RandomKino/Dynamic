#Use this after merged checklists to indivisual PDFs using Acrobat PDFMaker
#SN must stored in a txt file named NewName.txt, and it is located in the same directory

$BasePath = ".\"
$FilesToChangeFolderName = 'Output'
$filestochange = Get-ChildItem -Path ".\$FilesToChangeFolderName"

$FileNames = Get-Content ".\NewName.txt"

if($filestochange.FullName.Count -eq $FileNames.Count)
{
    for($i=0; $i -lt $FileNames.Count; $i++)
    {
        write-host "Renaming file $($filestochange.Name[$i]) to $($FileNames[$i]+".pdf")"
        Rename-Item -Path $filestochange.FullName[$i] -NewName ($FileNames[$i]+".pdf")
    }
}

