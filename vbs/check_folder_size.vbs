'Create Marek Pastier 18.03.201
'Easy script for check space folder. You need NRPE_NT daemon on win computer
'##########################################################'
'Install'
'##########################################################'
'1.copy file to c:\ for example... c:\nrpe_nt\bin\check_folder_size.vbs'
'2.set your nrpe.cfg for command for example 
'command[check_foldersize]=cscript.exe //NoLogo //T:30 c:\opmon\plugins\check_folder_size.vbs $ARG1$
'50 70 are parameters for warning and critical value in MB'
'Values before ',' is warning and critical to size (logical) folder
'Values after ',' is warning and critical to size (fisical || size on disk) folder
'3.restart your nrpe_nt daemon in command prompt example.. net stop nrpe_nt and net start nrpe_nt'
'4. try from linux example.: ./check_nrpe -H yourcomputer -c check_foldersize -a "c:\yourfolder 50,50 78,78"'
'it is all'
'##########################################################'

'http://stackoverflow.com/questions/10259170/vbscript-recursion-programming-techniques
'http://www.visualbasicscript.com/FILE39S-SIZE-ON-DISK-m33044.aspx
'http://stackoverflow.com/questions/6520807/asp-cannot-use-parentheses-when-calling-a-sub
'http://technet.microsoft.com/en-us/library/bb490884.aspx

' VERSION 2.3

Function SizeFolder(ByRef FSO, ByRef Shell, ByRef folderSize, ByRef folderCompressedSize, Folder)
    'Wscript.echo Folder.Path
    'WScript.Echo "cmd.exe /c compact.exe /S " & Chr(34) & Folder.Path & "\*.*" & Chr(34) & " | findStr /C:" & Chr(34) & "= " & Chr(34)
    Set Stream = Shell.Exec("cmd.exe /c compact.exe /S " & Chr(34) & Folder.Path & "\*.*" & Chr(34) & " | findStr /C:" & Chr(34) & "= " & Chr(34))
    Dim temp, elements
    Do While Not Stream.StdOut.AtEndOfStream
        'WScript.Echo Trim(Stream.StdOut.ReadLine)
        temp = Split(Stream.StdOut.ReadLine, "=")
        elements = Split(temp(0), ":")
        folderSize = folderSize + Trim(elements(0))
        folderCompressedSize = folderCompressedSize + Trim(elements(1))
        'WScript.Echo temp(0) & " : " & temp(1)
        'WScript.Echo folderSize & " = " & folderCompressedSize & " : " & temp(1)
    Loop
    folderSize = (folderSize / 1024 / 1024) 'converte para megabytes
    folderCompressedSize = (folderCompressedSize / 1024 / 1024) 'converte para megabytes

End Function

Dim folderSize
Dim folderCompressedSize
Dim strfolder
Dim intwarning
Dim intcritic
Dim output

folderSize = 0
folderCompressedSize = 0

strfolder  = Wscript.Arguments(0)
intwarning = Split(Wscript.Arguments(1), ",")
intcritic  = Split(Wscript.Arguments(2), ",")

If Wscript.Arguments.Count = 3 Then
    Set FSO = CreateObject("Scripting.FileSystemObject")
    Set Shell = CreateObject("Wscript.Shell")
    Set Folder = FSO.GetFolder(strfolder)

    Call SizeFolder(FSO, Shell, folderSize, folderCompressedSize, Folder)
    'WScript.Echo folderSize & " = " & folderCompressedSize

    output = " - " & Folder.Path & "<br>Size: " & round(folderSize) & "MB<br>SizeOnDisk: " & round (folderCompressedSize) & "MB | " _
    & "Size="& round(folderSize) & "MB;" & round(intwarning(0)) & "MB;" & round(intcritic(0)) & "MB;0; " _
    & "SizeOnDisk=" & round (folderCompressedSize) & "MB;" & round(intwarning(1)) & "MB;" & round(intcritic(1)) & "MB;0;"

    if ( (folderSize > CLng(intcritic(0))) Or (folderCompressedSize > CLng(intcritic(1))) ) Then  
        Wscript.Echo "CRITICAL" & output
        Wscript.Quit(2)
    elseif ( (folderSize > CLng(intwarning(0))) Or (folderCompressedSize > CLng(intwarning(1))) ) Then
        Wscript.Echo "WARNING" & output
        Wscript.Quit(1)
    else
    Wscript.Echo "OK" & output
    Wscript.Quit(0)
    end if
else
    Wscript.Echo "UNKNOWN:"& strfolder &"-" & intwarning & "-" & intcritic
    WScript.Echo "cscript.exe //NoLogo //T:30 c:\opmon\plugins\check_folder_size.vbs c:\\yourfolder 50,50 78,78"
    Wscript.Quit(3)
End If
'##########################################################'
