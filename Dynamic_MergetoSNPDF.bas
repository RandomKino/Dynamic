Attribute VB_Name = "Dynamic_MergetoSNPDF"
' Revision: 01.23.23
' Owner: Kino Zhou

' Make sure template file are NOT located in a OneDrive synced folder (Like Downloads folder)
' Make sure serial number column is named SN in data file

Sub MergetoSNPDF()

' Get Production Order number and create folder
    Dim pdoNum As String
    pdoNum = InputBox("Please type in the Production Order number:")
    Dim outputPath As String
    outputPath = ActiveDocument.Path & Application.PathSeparator & pdoNum
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
    
' Merge files to individual PDF file named Serial Number
    Do While lastRecordNum > 0
        masterDoc.MailMerge.Destination = wdSendToNewDocument
        masterDoc.MailMerge.DataSource.FirstRecord = masterDoc.MailMerge.DataSource.ActiveRecord
        masterDoc.MailMerge.DataSource.LastRecord = masterDoc.MailMerge.DataSource.ActiveRecord
        masterDoc.MailMerge.Execute False
        Set singleDoc = ActiveDocument
        singleDoc.ExportAsFixedFormat _
            OutputFileName:=outputPath & Application.PathSeparator & _
                masterDoc.MailMerge.DataSource.DataFields("SN").Value & ".pdf", _
            ExportFormat:=wdExportFormatPDF
        singleDoc.Close False
        If masterDoc.MailMerge.DataSource.ActiveRecord >= lastRecordNum Then
            lastRecordNum = 0
        Else
            masterDoc.MailMerge.DataSource.ActiveRecord = wdNextRecord
        End If
    Loop
    
End Sub

