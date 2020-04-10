Option Explicit

Const xlWindowMinimized = 2
Const xlCSV = 6
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
  If Ext = "xlsx" Or Ext = "xls" Then
      WScript.Echo "Processing file '" & File.Name & "..."
      Dim outputFile : outputFile = FsObj.BuildPath(FsObj.GetParentFolderName(inputFile), FsObj.GetBaseName(inputFile) & ".csv")

      ' Launch Excel
      Dim ExcelApp : Set ExcelApp = CreateObject("Excel.Application")
      ExcelApp.Visible = vbTrue
      ExcelApp.DisplayAlerts = False
      ExcelApp.WindowState = xlWindowMinimized

      ' Custom Error Handler
      On Error Resume Next
      Dim ExcelWB : Set ExcelWB = ExcelApp.Workbooks.Open(inputFile)
      If Err <> 0 Then
        WScript.Echo "ERR: Cannot open '" & File.Name & "' !"
      Else
	WScript.Echo "Saving CSV copy to '" & outputFile & "'..."
	ExcelWB.ActiveSheet.SaveAs outputFile, xlCSV
        If Err <> 0 Then
          WScript.Echo "ERR: Cannot save '" & outputFile & "' !"
        End If
        ExcelWB.Close
      End If

      ' Standard Error Handler
      On Error Goto 0

      ' Wait a little bit and close Excel
      Wscript.Sleep 500
      ExcelApp.Application.Quit
      ExcelApp.Quit
      Wscript.Sleep 1000

      ' Kill remaining instances of Excel
      Dim strComputer : strComputer = "."
      Dim objWMIService, colProcessList, objProcess
      Set objWMIService = GetObject("winmgmts:" _
          & "{impersonationLevel=impersonate}!\\" & strComputer & "\root\cimv2")
      Set colProcessList = objWMIService.ExecQuery _
          ("SELECT * FROM Win32_Process WHERE Name = 'excel.exe'")
      For Each objProcess in colProcessList
          WScript.Echo "Killing remaining Excel process !"
          objProcess.Terminate()
      Next
  Else
    WScript.Echo "Skipping unsupported file '" & File.Name & " !"
  End If
Next

