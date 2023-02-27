Attribute VB_Name = "MergetoSNPDF"
' Revision: 02.23.23
' Owner: Kino Zhou

' Make sure serial number column is named SN in data file
' Make sure number in batch column is named Number in data file

' Convert OneDrive path to local path
Option Explicit
'Excel:
Private Sub TestGetLocalPathExcel()
    Debug.Print GetLocalPath(ThisWorkbook.FullName)
    Debug.Print GetLocalPath(ThisWorkbook.path)
End Sub

'Word:
Private Sub TestGetLocalPathWord()
    Debug.Print GetLocalPath(ThisDocument.FullName)
    Debug.Print GetLocalPath(ThisDocument.path)
End Sub

'PowerPoint:
Private Sub TestGetLocalPathPowerPoint()
    Debug.Print GetLocalPath(ActivePresentation.FullName)
    Debug.Print GetLocalPath(ActivePresentation.path)
End Sub

Public Function GetLocalPath(ByVal path As String, _
                    Optional ByVal rebuildCache As Boolean = False, _
                    Optional ByVal returnAll As Boolean = False, _
                    Optional ByVal preferredMountPointOwner As String = "") _
                             As String
    #If Mac Then
        Const vbErrPermissionDenied As Long = 70
        Const vbErrInvalidFormatInResourceFile As Long = 325
        Const ps As String = "/" 'Application.PathSeparator doesn't work
    #Else 'Windows               'in all host applications (e.g. Outlook), hence
        Const ps As String = "\" 'conditional compilation is preferred here.
    #End If
    Const vbErrFileNotFound As Long = 53
    Static locToWebColl As Collection, lastTimeNotFound As Collection
    Static lastCacheUpdate As Date
    Dim resColl As Object, webRoot As String, locRoot As String
    Dim vItem As Variant, s As String, keyExists As Boolean
    Dim pmpo As String: pmpo = LCase(preferredMountPointOwner)

    If Not locToWebColl Is Nothing And Not rebuildCache Then
        Set resColl = New Collection: GetLocalPath = ""
        'If the locToWebColl is initialized, this logic will find the local path
        For Each vItem In locToWebColl
            locRoot = vItem(0): webRoot = vItem(1)
            If InStr(1, path, webRoot, vbTextCompare) = 1 Then _
                resColl.Add Key:=vItem(2), _
                   Item:=Replace(Replace(path, webRoot, locRoot, , 1), "/", ps)
        Next vItem
        If resColl.Count > 0 Then
            If returnAll Then
                For Each vItem In resColl: s = s & "//" & vItem: Next vItem
                GetLocalPath = Mid(s, 3): Exit Function
            End If
            On Error Resume Next: GetLocalPath = resColl(pmpo): On Error GoTo 0
            If GetLocalPath <> "" Then Exit Function
            GetLocalPath = resColl(1): Exit Function
        End If
        'Local path was not found with cached mountpoints
        If Not lastTimeNotFound Is Nothing Then 'Check if the same input already
            On Error Resume Next: lastTimeNotFound path 'failed recently (< 1s)
            keyExists = (Err.Number = 0): On Error GoTo 0
            If keyExists Then
                'For times between calls of > 1 sec the time saved by not
                'querying the FileDateTimes is completely insignificant.
                If DateAdd("s", 1, lastTimeNotFound(path)) > Now() Then _
                    GetLocalPath = path: Exit Function
            End If
        End If
        GetLocalPath = path 'No Exit Function here! Check if cache needs rebuild
    End If

    'Declare all variables that will be used in the loop over OneDrive settings
    Dim cid As String, fileNum As Long, line As Variant, parts() As String
    Dim tag As String, mainMount As String, relPath As String, email As String
    Dim b() As Byte, n As Long, i As Long, size As Long, libNr As String
    Dim parentID As String, folderID As String, folderName As String
    Dim folderIdPattern As String, fileName As String, folderType As String
    Dim siteID As String, libID As String, webID As String, lnkID As String
    Dim odFolders As Object, cliPolColl As Object, libNrToWebColl As Object
    Dim sig1 As String: sig1 = StrConv(Chr$(&H2), vbFromUnicode) 'x02
    Dim sig2 As String: sig2 = ChrW$(&H1) & String(3, vbNullChar) 'x01 (x00 * 7)
    Dim vbNullByte As String: vbNullByte = MidB$(vbNullChar, 1, 1) 'x00
    #If Mac Then 'Variables for UTF-32 decoding
        Dim utf16() As Byte, utf32() As Byte, j As Long, k As Long, m As Long
        Dim charCode As Long, lowSurrogate As Long, highSurrogate As Long
        ReDim b(0 To 3): b(0) = &HAB&: b(1) = &HAB&: b(2) = &HAB&: b(3) = &HAB&
        Dim sig3 As String: sig3 = b: sig3 = vbNullChar & vbNullChar & sig3
    #Else 'Windows
        ReDim b(0 To 1): b(0) = &HAB&: b(1) = &HAB&
        Dim sig3 As String: sig3 = b: sig3 = vbNullChar & sig3
    #End If

    Dim settPath As String, wDir As String, clpPath As String
    #If Mac Then
        s = Environ("HOME")
        settPath = Left(s, InStrRev(s, "/Library/Containers/")) & _
                   "Library/Containers/com.microsoft.OneDrive-mac/Data/" & _
                   "Library/Application Support/OneDrive/settings/"
        clpPath = s & "/Library/Application Support/Microsoft/Office/CLP/"

        'Excels CLP folder:
        'clpPath = left(s, InStrRev(s, "/Library/Containers")) & _
                  "Library/Containers/com.microsoft.Excel/Data/" & _
                  "Library/Application Support/Microsoft/Office/CLP/"
    #Else 'Windows
        settPath = Environ("LOCALAPPDATA") & "\Microsoft\OneDrive\settings\"
        clpPath = Environ("LOCALAPPDATA") & "\Microsoft\Office\CLP\"
    #End If

    #If Mac Then 'Request access to all necessary directories at once
        Dim possibleDirs(0 To 11) As String: possibleDirs(0) = settPath
        For i = 1 To 9: possibleDirs(i) = settPath & "Business" & i & ps: Next i
       possibleDirs(10) = settPath & "Personal" & ps: possibleDirs(11) = clpPath
        If Not GrantAccessToMultipleFiles(possibleDirs) Then _
            Err.Raise vbErrPermissionDenied
    #End If

    'Find all subdirectories in OneDrive settings folder:
    Dim oneDriveSettDirs As Collection: Set oneDriveSettDirs = New Collection
    Dim dirName As Variant: dirName = Dir(settPath, vbDirectory)
    Do Until dirName = ""
        If dirName = "Personal" Or dirName Like "Business#" Then _
            oneDriveSettDirs.Add dirName
        dirName = Dir(, vbDirectory)
    Loop

    #If Mac Then 'Request access to all necessary files at once
        s = ""
        For Each dirName In oneDriveSettDirs
            wDir = settPath & dirName & ps
            cid = IIf(dirName = "Personal", "????????????????", _
                      "????????-????-????-????-????????????")
            'Add needed files with fixed names
           If dirName = "Personal" Then s = s & "//" & wDir & "GroupFolders.ini"
            s = s & "//" & wDir & "global.ini"
            'Add needed files with variable names
            fileName = Dir(wDir, vbNormal)
            Do Until fileName = ""
                If fileName Like cid & ".ini" Or _
                   fileName Like cid & ".dat" Or _
                   fileName Like "ClientPolicy*.ini" Then _
                    s = s & "//" & wDir & fileName
                fileName = Dir
            Loop
        Next dirName
        If Not GrantAccessToMultipleFiles(Split(Mid(s, 3), "//")) Then _
            Err.Raise vbErrPermissionDenied
    #End If

    'This part should ensure perfect accuracy despite the mount point cache
    'while sacrificing almost no performance at all by querying FileDateTimes.
    If Not locToWebColl Is Nothing And Not rebuildCache Then
        'Local path was not found with cached mountpoints.
        s = "" 'Check if some of the OneDrive settings files were modified since
        For Each dirName In oneDriveSettDirs 'the last time the cache was built
            wDir = settPath & dirName & ps
            cid = IIf(dirName = "Personal", "????????????????", _
                      "????????-????-????-????-????????????")
            If Dir(wDir & "global.ini") <> "" Then _
                s = s & "//" & wDir & "global.ini"
            fileName = Dir(wDir, vbNormal)
            Do Until fileName = ""
                If fileName Like cid & ".ini" Then _
                    s = s & "//" & wDir & fileName
                fileName = Dir
            Loop
        Next dirName
        For Each vItem In Split(Mid(s, 3), "//") 'For each relevant file...
            If FileDateTime(vItem) > lastCacheUpdate Then _
                rebuildCache = True: Exit For 'full cache refresh is required!
        Next vItem
        If Not rebuildCache Then 'Cache does not need rebuild
            If lastTimeNotFound Is Nothing Then _
                Set lastTimeNotFound = New Collection
            On Error Resume Next: lastTimeNotFound.Remove path: On Error GoTo 0
            lastTimeNotFound.Add Item:=Now(), Key:=path
            Exit Function 'Return value was already set as unchanged input path
        End If
    End If
    
    'If execution reaches this point, the cache will be fully rebuilt...
    lastCacheUpdate = Now()
    Set lastTimeNotFound = Nothing 'Old not-found inputs are now irrelevant

    'Writing locToWebColl using .ini and .dat files in the OneDrive settings:
    'Here, a Scripting.Dictionary would be nice but it is not available on Mac!
    Set locToWebColl = New Collection
    For Each dirName In oneDriveSettDirs 'One folder per logged in OD account
        wDir = settPath & dirName & ps
        'Read global.ini to get cid
        If Dir(wDir & "global.ini", vbNormal) = "" Then GoTo NextFolder
        fileNum = FreeFile()
        Open wDir & "global.ini" For Binary Access Read As #fileNum
            ReDim b(0 To LOF(fileNum)): Get fileNum, , b
        Close #fileNum: fileNum = 0
        #If Mac Then 'On Mac, the OneDrive settings files use UTF-8 encoding
            b = StrConv(b, vbUnicode)
        #End If
        For Each line In Split(b, vbNewLine)
            If line Like "cid = *" Then cid = Mid(line, 7): Exit For
        Next line

        If cid = "" Then GoTo NextFolder
        If (Dir(wDir & cid & ".ini") = "" Or _
            Dir(wDir & cid & ".dat") = "") Then GoTo NextFolder
        If dirName Like "Business#" Then
            folderIdPattern = Replace(Space(32), " ", "[a-f0-9]")
        ElseIf dirName = "Personal" Then
            folderIdPattern = Replace(Space(16), " ", "[A-F0-9]") & "!###*"
        End If

        'Get email for business accounts
        '(only necessary to let user choose preferredMountPointOwner)
        fileName = Dir(clpPath, vbNormal)
        Do Until fileName = ""
            i = InStrRev(fileName, cid, , vbTextCompare)
            If i > 1 And cid <> "" Then _
                email = LCase(Left(fileName, i - 2)): Exit Do
            fileName = Dir
        Loop

        'Read all the ClientPloicy*.ini files:
        Set cliPolColl = New Collection
        fileName = Dir(wDir, vbNormal)
        Do Until fileName = ""
            If fileName Like "ClientPolicy*.ini" Then
                fileNum = FreeFile()
                Open wDir & fileName For Binary Access Read As #fileNum
                    ReDim b(0 To LOF(fileNum)): Get fileNum, , b
                Close #fileNum: fileNum = 0
                #If Mac Then 'On Mac, OneDrive settings files use UTF-8 encoding
                    b = StrConv(b, vbUnicode)
                #End If
                cliPolColl.Add Key:=fileName, Item:=New Collection
                For Each line In Split(b, vbNewLine)
                    If InStr(1, line, " = ", vbBinaryCompare) Then
                        tag = Left(line, InStr(line, " = ") - 1)
                        s = Mid(line, InStr(line, " = ") + 3)
                        Select Case tag
                        Case "DavUrlNamespace"
                            cliPolColl(fileName).Add Key:=tag, Item:=s
                        Case "SiteID", "IrmLibraryId", "WebID" 'Only used for
                            s = Replace(LCase(s), "-", "")  'backup method later
                            If Len(s) > 3 Then s = Mid(s, 2, Len(s) - 2)
                            cliPolColl(fileName).Add Key:=tag, Item:=s
                        End Select
                    End If
                Next line
            End If
            fileName = Dir
        Loop

        'Read cid.dat file
        fileNum = FreeFile
        Open wDir & cid & ".dat" For Binary Access Read As #fileNum
            ReDim b(0 To LOF(fileNum)): Get fileNum, , b: s = b: size = LenB(s)
        Close #fileNum: fileNum = 0
        Set odFolders = New Collection
        For Each vItem In Array(16, 8)
            i = InStrB(vItem, s, sig2) 'Sarch for byte pattern (sig2) in cid.dat
            Do While i > vItem And i < size - 168 'and confirm with additional
                If MidB$(s, i - vItem, 1) = sig1 Then 'byte pattern at an offset
                    i = i + 8: n = InStrB(i, s, vbNullByte) - i 'i: Start pos
                    If n < 0 Then n = 0                         'n: Length
                    If n > 39 Then n = 39
                    folderID = StrConv(MidB$(s, i, n), vbUnicode)
                    i = i + 39: n = InStrB(i, s, vbNullByte) - i
                    If n < 0 Then n = 0
                    If n > 39 Then n = 39
                    parentID = StrConv(MidB$(s, i, n), vbUnicode)
                    i = i + 121: n = -Int(-(InStrB(i, s, sig3) - i) / 2) * 2
                    If n < 0 Then n = 0
                    #If Mac Then 'Encoding of folder names is UTF-32-LE
                        utf32 = MidB$(s, i, n)
                        'UTF-32 can only be converted manually to UTF-16 in VBA:
                        ReDim utf16(LBound(utf32) To UBound(utf32))
                        j = LBound(utf32): k = LBound(utf32)
                        Do While j < UBound(utf32)
                            If utf32(j + 2) = 0 And utf32(j + 3) = 0 Then
                                utf16(k) = utf32(j): utf16(k + 1) = utf32(j + 1)
                                k = k + 2
                            Else
                                If utf32(j + 3) <> 0 Then Err.Raise _
                                    vbErrInvalidFormatInResourceFile '325
                                charCode = utf32(j + 2) * &H10000 + _
                                           utf32(j + 1) * &H100& + utf32(j)
                                'Surrogate pairs must be found manually, ChrW()
                                m = charCode - &H10000 'only works until &HFFFF
                                '(m \ &H400&) = most significant 10 bits of m
                                highSurrogate = &HD800& + (m \ &H400&)
                                '(m And &H3FF) = least significant 10 bits of m
                                lowSurrogate = &HDC00& + (m And &H3FF)
                                'take least significant 8 bits of highSurrogate:
                                utf16(k) = CByte(highSurrogate And &HFF&)
                                'take most significant 8 bits of highSurrogate:
                                utf16(k + 1) = CByte(highSurrogate \ &H100&)
                                'same for lowSurrogate...
                                utf16(k + 2) = CByte(lowSurrogate And &HFF&)
                                utf16(k + 3) = CByte(lowSurrogate \ &H100&)
                                k = k + 4
                            End If
                            j = j + 4
                        Loop
                        ReDim Preserve utf16(LBound(utf16) To k - 1)
                        folderName = utf16
                    #Else 'On Windows encoding is UTF-16-LE
                        folderName = MidB$(s, i, n)
                    #End If
                    If folderID Like folderIdPattern Then
                        'VBA.Array() instead of just Array() is used in this
                        'function because it ignores Option Base 1
                        odFolders.Add VBA.Array(parentID, folderName), folderID
                    End If
                End If
                i = InStrB(i + 1, s, sig2) 'Find next sig2 in cid.dat
            Loop
            If odFolders.Count > 0 Then Exit For
        Next vItem

        'Read cid.ini file
        fileNum = FreeFile()
        Open wDir & cid & ".ini" For Binary Access Read As #fileNum
            ReDim b(0 To LOF(fileNum)): Get fileNum, , b
        Close #fileNum: fileNum = 0
        #If Mac Then 'On Mac, the OneDrive settings files use UTF-8 encoding
            b = StrConv(b, vbUnicode)
        #End If
        Select Case True
        Case dirName Like "Business#" 'Settings files for a business OD account
        'Max 9 Business OneDrive accounts can be signed in at a time.
            mainMount = "": Set libNrToWebColl = New Collection
            For Each line In Split(b, vbNewLine)
                webRoot = "": locRoot = ""
                Select Case Left$(line, InStr(line, " = ") - 1)
                Case "libraryScope" 'One line per synchronized library
                    parts = Split(line, """"): locRoot = parts(9)
                    If locRoot = "" Then libNr = Split(line, " ")(2)
                    folderType = parts(3): parts = Split(parts(8), " ")
                    siteID = parts(1): webID = parts(2): libID = parts(3)
                    If mainMount = "" And folderType = "ODB" Then
                        mainMount = locRoot: fileName = "ClientPolicy.ini"
                    Else: fileName = "ClientPolicy_" & libID & siteID & ".ini"
                    End If
                    On Error Resume Next 'On error try backup method...
                    webRoot = cliPolColl(fileName)("DavUrlNamespace")
                    On Error GoTo 0
                    If webRoot = "" Then 'Backup method to find webRoot:
                        For Each vItem In cliPolColl
                            If vItem("SiteID") = siteID _
                            And vItem("WebID") = webID _
                            And vItem("IrmLibraryId") = libID Then
                                webRoot = vItem("DavUrlNamespace"): Exit For
                            End If
                        Next vItem
                    End If
                    If webRoot = "" Then Err.Raise vbErrFileNotFound
                    If locRoot = "" Then
                        libNrToWebColl.Add VBA.Array(libNr, webRoot), libNr
                    Else: locToWebColl.Add VBA.Array(locRoot, webRoot, email), _
                                           locRoot
                    End If
                Case "libraryFolder" 'One line per synchronized library folder
                    locRoot = Split(line, """")(1): libNr = Split(line, " ")(3)
                    For Each vItem In libNrToWebColl
                        If vItem(0) = libNr Then
                            s = "": parentID = Left(Split(line, " ")(4), 32)
                            Do  'If not synced at the bottom dir of the library:
                                '   -> add folders below mount point to webRoot
                                On Error Resume Next: odFolders parentID
                                keyExists = (Err.Number = 0): On Error GoTo 0
                                If Not keyExists Then Exit Do
                                s = odFolders(parentID)(1) & "/" & s
                                parentID = odFolders(parentID)(0)
                            Loop
                            webRoot = vItem(1) & s: Exit For
                        End If
                    Next vItem
                    locToWebColl.Add VBA.Array(locRoot, webRoot, email), locRoot
                Case "AddedScope" 'One line per folder added as link to personal
                    parts = Split(line, """")                           'library
                    relPath = parts(5): If relPath = " " Then relPath = ""
                    parts = Split(parts(4), " "): siteID = parts(1)
                    webID = parts(2): libID = parts(3): lnkID = parts(4)
                    fileName = "ClientPolicy_" & libID & siteID & lnkID & ".ini"
                    On Error Resume Next 'On error try backup method...
                    webRoot = cliPolColl(fileName)("DavUrlNamespace") & relPath
                    On Error GoTo 0
                    If webRoot = "" Then 'Backup method to find webRoot:
                        For Each vItem In cliPolColl
                            If vItem("SiteID") = siteID _
                            And vItem("WebID") = webID _
                            And vItem("IrmLibraryId") = libID Then
                                webRoot = vItem("DavUrlNamespace") & relPath
                                Exit For
                            End If
                        Next vItem
                    End If
                    If webRoot = "" Then Err.Raise vbErrFileNotFound
                    s = "": parentID = Left(Split(line, " ")(3), 32)
                    Do 'If link is not at the bottom of the personal library:
                        On Error Resume Next: odFolders parentID
                        keyExists = (Err.Number = 0): On Error GoTo 0
                        If Not keyExists Then Exit Do       'add folders below
                        s = odFolders(parentID)(1) & ps & s 'mount point to
                        parentID = odFolders(parentID)(0)   'locRoot
                    Loop
                    locRoot = mainMount & ps & s
                    locToWebColl.Add VBA.Array(locRoot, webRoot, email), locRoot
                Case Else
                    Exit For
                End Select
            Next line
        Case dirName = "Personal" 'Settings files for a personal OD account
        'Only one Personal OneDrive account can be signed in at a time.
            For Each line In Split(b, vbNewLine) 'Loop should exit at first line
                If line Like "library = *" Then _
                    locRoot = Split(line, """")(3): Exit For
            Next line
            On Error Resume Next 'This file may be missing if the personal OD
            webRoot = cliPolColl("ClientPolicy.ini")("DavUrlNamespace") 'account
            On Error GoTo 0                  'was logged out of the OneDrive app
            If locRoot = "" Or webRoot = "" Or cid = "" Then GoTo NextFolder
            locToWebColl.Add VBA.Array(locRoot, webRoot & "/" & cid, email), _
                             locRoot
            If Dir(wDir & "GroupFolders.ini") = "" Then GoTo NextFolder
            'Read GroupFolders.ini file
            cid = "": fileNum = FreeFile()
            Open wDir & "GroupFolders.ini" For Binary Access Read As #fileNum
                ReDim b(0 To LOF(fileNum)): Get fileNum, , b
            Close #fileNum: fileNum = 0
            #If Mac Then 'On Mac, the OneDrive settings files use UTF-8 encoding
                b = StrConv(b, vbUnicode)
            #End If 'Two lines per synced folder from other peoples personal ODs
            For Each line In Split(b, vbNewLine)
                If InStr(line, "BaseUri = ") And cid = "" Then
                    cid = LCase(Mid(line, InStrRev(line, "/") + 1, 16))
                    folderID = Left(line, InStr(line, "_") - 1)
                ElseIf cid <> "" Then
                    locToWebColl.Add VBA.Array(locRoot & ps & odFolders( _
                                     folderID)(1), webRoot & "/" & cid & "/" & _
                                     Mid(line, Len(folderID) + 9), email), _
                                     locRoot & ps & odFolders(folderID)(1)
                    cid = "": folderID = ""
                End If
            Next line
        End Select
NextFolder:
        cid = "": s = "": email = "": Set odFolders = Nothing
    Next dirName

    'Clean the finished "dictionary" up, remove trailing "\" and "/"
    Dim tmpColl As Collection: Set tmpColl = New Collection
    For Each vItem In locToWebColl
        locRoot = vItem(0): webRoot = vItem(1): email = vItem(2)
       If Right(webRoot, 1) = "/" Then webRoot = Left(webRoot, Len(webRoot) - 1)
        If Right(locRoot, 1) = ps Then locRoot = Left(locRoot, Len(locRoot) - 1)
        tmpColl.Add VBA.Array(locRoot, webRoot, email), locRoot
    Next vItem
    Set locToWebColl = tmpColl

    GetLocalPath = GetLocalPath(path, False, returnAll, pmpo): Exit Function
End Function

Sub MergetoSNPDF()

' Get Production Order number and create folder
    Dim pdoNum As String
    pdoNum = InputBox("Please type in the Production Order number:")
    Dim n As Integer
    Dim pn As String
    Dim outputPath As String
' Get local path from OneDrive path link
    outputPath = GetLocalPath(ActiveDocument.path) & Application.PathSeparator & pdoNum
    If Len(Dir(outputPath, vbDirectory)) = 0 Then
        MkDir (outputPath)
    End If

' Create variables
    Dim masterDoc As Document, singleDoc As Document, lastRecordNum As Long
    Set masterDoc = ActiveDocument

' Get total output number
    masterDoc.MailMerge.DataSource.ActiveRecord = wdLastRecord
    lastRecordNum = masterDoc.MailMerge.DataSource.ActiveRecord

' Jump to the first active record
    masterDoc.MailMerge.DataSource.ActiveRecord = wdFirstRecord
    
' Merge files and generated PDF
    Do While lastRecordNum > 0
        masterDoc.MailMerge.Destination = wdSendToNewDocument
        masterDoc.MailMerge.DataSource.FirstRecord = masterDoc.MailMerge.DataSource.ActiveRecord
        masterDoc.MailMerge.DataSource.LastRecord = masterDoc.MailMerge.DataSource.ActiveRecord
        masterDoc.MailMerge.Execute False
        n = masterDoc.MailMerge.DataSource.DataFields("Number").Value
        pn = Format(n, "000")
        Set singleDoc = ActiveDocument
        singleDoc.ExportAsFixedFormat _
            OutputFileName:=outputPath & Application.PathSeparator & _
                pn & "_" & masterDoc.MailMerge.DataSource.DataFields("SN").Value & ".pdf", _
            ExportFormat:=wdExportFormatPDF
        singleDoc.Close False
        If masterDoc.MailMerge.DataSource.ActiveRecord >= lastRecordNum Then
            lastRecordNum = 0
        Else
            masterDoc.MailMerge.DataSource.ActiveRecord = wdNextRecord
        End If
    Loop
    
End Sub

