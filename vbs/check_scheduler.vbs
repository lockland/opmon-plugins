'--------------------------------------------------------------------------------------

' Author: Estevan Ramalho
' E-mail: estevan.ramalho@opservices.com.br

' Date: 16/08/11
'--------------------------------------------------------------------------------------
' ChangeLog 
'--------------------------------------------------------------------------------------  
' 26/12/12
' Parcialmente modificado por Sidney Souza (sidney.souza@opservices.com.br)
' Modificações:
  
' Alterado as funcionalidades do plugin.
' Antes: Criava um log de todas as tasks e armazenava em uma pasta compartilhada 
' para consulta posterior através de outro plugin (check_smb_tasks).
  
' Agora: Não cria o log, simplesmente retorna diretamente para o nrpe as informações 
' referente a task cujo o nome é passado por parâmetro na linha de comando.
  
' Modificado o comportamento do modo DEBUG
  
' Adicionado a opção de monitoramento por status (EN ou PT-BR) da task ou pelo last 
' result

' Exemplos de uso: 
' Com debug, tipo de monitoramento: last result
' cscript.exe check_scheduler.vbs /task:"[nome task]" /debug

' Sem debug, tipo de monitoramento: last result
' cscript.exe check_scheduler.vbs /task:"[nome task]"

' Com debug, tipo de monitoramento: status
' cscript.exe check_scheduler.vbs /task:"[nome task]" /debug /status

' Sem debug, tipo de monitoramento: status
' cscript.exe check_scheduler.vbs /task:"[nome task]" /status

' 30/01/13
' Adicionado validação de existência do nome de uma task.
  
' 14/02/2013
' Adicionado opção de mostrar versão.
' Modificado a validação do nome da task
'--------------------------------------------------------------------------------------

'define argumentos
Dim oArgs
Set oArgs = WScript.Arguments
'--------------------------------------------------------------------------------------

'recupera os argumentos
Dim oNamed
Set oNamed = oArgs.Named
'--------------------------------------------------------------------------------------

'--------------------------------------------------------------------------------------
'Atribuindo parametros a variáveis 
'--------------------------------------------------------------------------------------

'Modo Debug (0 = false, 1 = true)
Dim debug
If oNamed.Exists("debug") Then 'Se o argumento debug existir
	debug = 1
End If

'Name da task
Dim task

' INI - Adicionado 30/01/13
' Valida se o nome da task existe e não é vazio
If oNamed.Exists("task") and oNamed("task") <> "" Then
	task = oNamed("task")
Else
	task = ""
End If
' FIM - Adicionado 30/01/13

'Tipo monitoração ("status" para status, "[vazio]" para Last Result)
Dim typeMonitor
If oNamed.Exists("status") Then 'Se o argumento status existir
	typeMonitor = "status"
End If
'--------------------------------------------------------------------------------------

'--------------------------------------------------------------------------------------
' INI - Adicionado 14/02/2013
' Valida os argumentos necessários
'--------------------------------------------------------------------------------------

' Exibe a versão do plugin
If oNamed.Exists("version") Then
	wscript.echo "Version: 2.2"
	WScript.Quit (0)
End If

' Caso o nome da task não seja declarado corretamente executará o codigo abaixo
If task = "" Then
	wscript.echo "UNKNOWN: Nome da task deve ser declarado."
	wscript.echo "Usage: " & Wscript.ScriptName & " /task:" & Chr(34) & "\[caminho completo]\[nome task]" & Chr(34)
	WScript.Quit (3)
End If
' FIM - Adicionado 14/02/2013 
'--------------------------------------------------------------------------------------

' Executando o comando no Console

'cria o objeto de shell
Set oShell = CreateObject("WScript.Shell") 

'passa a linha de comnado para o objeto
Set oExecObject = oShell.Exec("schtasks /QUERY /FO CSV /V /TN " & Chr(34) & task & Chr(34)) 

If debug Then
	wscript.echo "Task: " & Chr(34) & task & Chr(34)
End If

'executa comando no shell
Set objStdOut = oExecObject.StdOut 
'--------------------------------------------------------------------------------------

' Valida se o nome da task foi encontrado
If (objStdOut.ReadLine = "") then
	wscript.echo "UNKNOWN: A task nao pode ser consultada corretamente. Dados invalidos."
	WScript.Quit (3)
End If
'--------------------------------------------------------------------------------------

'Lê a saída e atribui a ultima linha a variável strLine
do While Not oExecObject.StdOut.AtEndOfStream
	strLine = objStdOut.ReadLine
	'strLine = Replace(strLine,""",""",""";""") 'substitui os caracteres "," por ";"
	strLine = Replace(strLine,""",""",";") 'substitui os caracteres "," por ;
		
	If debug Then
		wscript.echo
		wscript.echo strLine
	End If
loop
'--------------------------------------------------------------------------------------

'Converte a string em um array e armazena na variavel elements
Dim elements
elements = Split(strLine, ";")
'--------------------------------------------------------------------------------------

'Variaveis utilizadas para armazenar os elementos do array
Dim taskName, status, nextRunTime, lastRunTime, lastResult

'Processa as strings armazenadas no array elements e armazena na sua respectiva variável

'Remove a \ do nome da task
taskName = Replace (elements(1), "\", "")
status = elements(3)
nextRunTime = elements(2)
lastRunTime = elements(5)
lastResult = elements(6)


'--------------------------------------------------------------------------------------

If debug Then
	wscript.echo
	wscript.echo "Task Name: " & taskName
	wscript.echo "Next Run Time: " & nextRunTime
	wscript.echo "Last Run Time: " & lastRunTime
	wscript.echo "Status: " & status
	wscript.echo "Last Result: " & lastResult
	wscript.echo
End If

'Testes do tipo de monitoramento e saída do plugin para o nrpe

'Se o tipo de monitoramento for status
If (typeMonitor = "status") Then

	If ( status = "Ready" or status = "Running" or status = "Pronto" or status = "Executando" or status = "Em execução") Then
			wscript.echo "Task OK - Last run: " & lastRunTime & " / Next run: " & nextRunTime & " / Status: " & status
			WScript.Quit (0)
	Else
			WScript.Echo "UNKNOWN - Task em status incorreto: " & status
			WScript.Quit (3)
	End If

'Se o tipo estiver vazio
Else
	If (lastResult = 0) Then
		wscript.echo "Task OK - Last run: " & lastRunTime & " / Next run: " & nextRunTime & " / Last Result: " & lastResult
		WScript.Quit (0)
	Else
		wscript.echo "Task CRITICAL - Last run: " & lastResult
		WScript.Quit (2)
	End If
End If
'--------------------------------------------------------------------------------------
