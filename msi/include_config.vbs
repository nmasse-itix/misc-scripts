' +---------------------------------------------------------------------+
' |                          Requirements                               |
' +---------------------------------------------------------------------+
' 
'  - CScript.exe
'  - Windows Installer
'  - Microsoft Cabinet Software Development Kit (See KB 310618)
'

' Safe coding
Option Explicit

' +---------------------------------------------------------------------+
' |            Adjust the following settings to your needs              |
' +---------------------------------------------------------------------+

' The MSI file to modify
Dim databasePath : databasePath = "installer.msi"

' The Properties to set
Dim Properties : Set Properties = CreateObject("Scripting.Dictionary")
Properties.Add "PROPERTY1", "FOO"
Properties.Add "PROPERTY2", "BAR"

' MSI Release (numeric value)
Dim Release : Release = "1"

' Machine Install ?
Dim machineInstall : machineInstall = vbTrue

' =======================================================================
' 
'      WARNING !    WARNING !    WARNING !    WARNING !   WARNING !  
'
'
'                 -=    DO NOT MODIFY ANYTHING BELOW !    =-
'
' =======================================================================

' Custom Error Handling (see below)
On Error Resume Next

' Machine installation needs the "ALLUSERS" property
If machineInstall Then
    Properties.Add "ALLUSERS", "1"
End If

' Update Product Version
Properties.Add "ProductVersion", "1.2.3." & Release

Const msiOpenDatabaseModeTransact = 1
Dim openMode : openMode = msiOpenDatabaseModeTransact

' Connect to Windows installer object
Dim installer : Set installer = Nothing
Set installer = Wscript.CreateObject("WindowsInstaller.Installer") : CheckError "Cannot instanciate WindowsInstaller.Installer. Check the script's requirements !"

' Open database
Dim database
Set database = installer.OpenDatabase(databasePath, openMode) : CheckError "Unable to open the MSI database '" & databasePath & "'"

' Process SQL statements
Dim query, view, prop, value, record, errMessage
For Each prop in Properties
    value = Properties.Item(prop)
    errMessage = "Cannot create/update property '" & prop & "'"
    query = "SELECT Property, Value FROM Property"
    Set record = installer.CreateRecord(2) : CheckError errMessage
    record.StringData(1) = prop
    record.StringData(2) = value
    InsertOrUpdate database, query, record, errMessage
Next

Dim Dialogs(4)
Dialogs(1) = "ExitDialog"
Dialogs(2) = "PrepareDlg"
Dialogs(3) = "ProgressDlg"
Dialogs(4) = "WelcomeEulaDlg"

Dim Dialog
For Each Dialog in Dialogs
    errMessage = "Cannot disable UI Dialog '" & Dialog & "'"

    query = "UPDATE InstallUISequence SET Condition = 0 WHERE Action = ?"
    Set record = installer.CreateRecord(1) : CheckError errMessage
    record.StringData(1) = Dialog
    Set view = database.OpenView(query) : CheckError errMessage
    view.Execute record : CheckError errMessage
    view.Close : CheckError errMessage
Next

' Handle Machine Install
If machineInstall Then
    ' Update the Word Count Property of the Summary Information Stream
    Dim infoStream, wordCount
    errMessage = "Cannot update the Word Count Property of the Summary Information Stream"
    Set infoStream = database.SummaryInformation(1) : CheckError errMessage ' we will modify 1 property...
    Const PID_WORDCOUNT = 15
    wordCount = infoStream.Property(PID_WORDCOUNT) : CheckError errMessage
    wordCount = wordCount And Not 8
    infoStream.Property(PID_WORDCOUNT) = wordCount : CheckError errMessage
    infoStream.Persist : CheckError errMessage
End If

' Final Step: Commit !
database.Commit : CheckError "Cannot commit !"
MsgBox "Successfully updated the MSI file '" & databasePath & "' !" & vbLf & "You can now deploy '" & databasePath & "' to Workstations.", 64, "Status"
Wscript.Quit 0

'
' Helper functions
'
Sub InsertOrUpdate(db, query, record, errorMessage)
    Const msiViewModifyAssign         = 3
    Dim view
    
    Set view = db.OpenView(query) : CheckError errorMessage
    view.Modify msiViewModifyAssign, record : CheckError errorMessage
    view.Close : CheckError errorMessage
End Sub

'
' Error Handling
'
Sub Error(userMessage)
    Dim message, msiErr

    message = ""
    
    ' VB Errors
    If Err <> 0 Then
        message = Err.Source & " " & Hex(Err) & ": " & Err.Description & vbLf
    End If

    ' MSI Errors
    If Not installer Is Nothing Then
        Set msiErr = installer.LastErrorRecord
        If Not msiErr Is Nothing Then message = message & msiErr.FormatText & vbLf End If
    End If

    ' Optional Error message
    If userMessage = "" Then
        Fail "Unexpected Error. Details Follow: " & vbLf & message
    Else
        Fail userMessage & vbLf & "Error: " & message
    End If
End Sub

Sub CheckError(userMessage)
    If Err <> 0 Then
        Error userMessage
    End If
End Sub

Sub Fail(message)
    MsgBox message, 48, "Status"
    Wscript.Quit 2
End Sub