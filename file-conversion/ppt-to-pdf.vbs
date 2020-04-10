Option Explicit

Const ppWindowMinimized = 2
Const ppSaveAsPDF = 32
Const msoTrue = -1

Dim FsObj : Set FsObj = CreateObject("Scripting.FileSystemObject")

Dim inputFile : inputFile = WScript.Arguments.Item(0)
inputFile = FsObj.GetAbsolutePathName(inputFile)
Dim outputFile : outputFile = FsObj.BuildPath(FsObj.GetParentFolderName(inputFile), FsObj.GetBaseName(inputFile) & ".pdf")

Dim PowerPointApp : Set PowerPointApp = CreateObject("PowerPoint.Application")
PowerPointApp.Visible = vbTrue
PowerPointApp.WindowState = ppWindowMinimized

Dim PowerPointPres : Set PowerPointPres = PowerPointApp.Presentations.Open(inputFile)
PowerPointPres.SaveAs outputFile, ppSaveAsPDF, msoTrue
PowerPointPres.Close

PowerPointApp.Quit
