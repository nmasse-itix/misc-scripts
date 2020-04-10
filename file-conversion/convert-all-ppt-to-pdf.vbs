Option Explicit

Const ppWindowMinimized = 2
Const ppSaveAsPDF = 32
Const msoTrue = -1

Dim CurrentDir, Files, File, FsObj

' Get the Current Folder
Set FsObj = CreateObject("Scripting.FileSystemObject")
Set CurrentDir = FsObj.GetFolder(FsObj.GetAbsolutePathName("."))

' Process all files in the current dir
Set Files = CurrentDir.Files
For Each File in Files
  Dim inputFile : inputFile = File.Path
  Dim Ext : Ext = FsObj.GetExtensionName(inputFile)

  ' Process only supported files
  If Ext = "pptx" Or Ext = "ppt" Or Ext = "pps" Then
    Dim outputFile : outputFile = FsObj.BuildPath(FsObj.GetParentFolderName(inputFile), FsObj.GetBaseName(inputFile) & ".pdf")
    
    If Not FsObj.FileExists(outputFile) Then
      WScript.Echo "Processing file '" & File.Name & "..."

      ' Launch PowerPoint
      Dim PowerPointApp : Set PowerPointApp = CreateObject("PowerPoint.Application")
      PowerPointApp.Visible = vbTrue
      PowerPointApp.WindowState = ppWindowMinimized

      ' Custom Error Handler
      On Error Resume Next
      Dim PowerPointPres : Set PowerPointPres = PowerPointApp.Presentations.Open(inputFile)
      If Err <> 0 Then
        WScript.Echo "ERR: Cannot open '" & File.Name & "' !"
      Else
        PowerPointPres.SaveAs outputFile, ppSaveAsPDF, msoTrue
        If Err <> 0 Then
          WScript.Echo "ERR: Cannot save PDF version of '" & File.Name & "' !"
        End If
        PowerPointPres.Close
      End If

      ' Standard Error Handler
      On Error Goto 0

      ' Wait a little bit and close PowerPoint
      Wscript.Sleep 500
      PowerPointApp.Quit
      Wscript.Sleep 1000

      ' Kill remaining instances of PowerPoint
      Dim strComputer : strComputer = "."
      Dim objWMIService, colProcessList, objProcess
      Set objWMIService = GetObject("winmgmts:" _
          & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
      Set colProcessList = objWMIService.ExecQuery _
          ("SELECT * FROM Win32_Process WHERE Name = 'powerpnt.exe'")
      For Each objProcess in colProcessList
          WScript.Echo "Killing remaining PowerPoint process !"
          objProcess.Terminate()
      Next

    Else
      WScript.Echo "Skipping file '" & File.Name & "' since the PDF version already exists !"
    End If
  Else
    WScript.Echo "Skipping unsupported file '" & File.Name & " !"
  End If
Next

