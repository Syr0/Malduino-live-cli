OpenConsole()

Procedure.s WSTransaction(Connection.i, Command.s)
  If Right(Command, 1) <> #LF$
    Command + #LF$
  EndIf

  Protected *Payload = UTF8(Command)
  Protected MsgLen.i = MemorySize(*Payload) - 1
  Protected HeaderLen.i = 6

  If MsgLen > 125
    HeaderLen = 8
  EndIf

  Protected *Frame = AllocateMemory(HeaderLen + MsgLen)
  PokeB(*Frame, $81)

  Protected Offset.i
  If MsgLen <= 125
    PokeB(*Frame + 1, MsgLen | $80)
    Offset = 2
  Else
    PokeB(*Frame + 1, 126 | $80)
    PokeB(*Frame + 2, (MsgLen >> 8) & $FF)
    PokeB(*Frame + 3, MsgLen & $FF)
    Offset = 4
  EndIf

  PokeB(*Frame + Offset, 0)
  PokeB(*Frame + Offset + 1, 0)
  PokeB(*Frame + Offset + 2, 0)
  PokeB(*Frame + Offset + 3, 0)

  CopyMemory(*Payload, *Frame + Offset + 4, MsgLen)
  SendNetworkData(Connection, *Frame, HeaderLen + MsgLen)
  FreeMemory(*Frame)
  FreeMemory(*Payload)

  Protected *Buffer = AllocateMemory(8192)
  Protected Result.s = ""
  Protected Timeout.i = ElapsedMilliseconds() + 5000

  Repeat
    If NetworkClientEvent(Connection) = #PB_NetworkEvent_Data
      Protected BytesRead = ReceiveNetworkData(Connection, *Buffer, 8192)
      If BytesRead > 0
        Protected PayloadLen = PeekB(*Buffer + 1) & $7F
        Protected RxHeaderLen = 2

        If PayloadLen = 126
          PayloadLen = ((PeekB(*Buffer + 2) & $FF) << 8) | (PeekB(*Buffer + 3) & $FF)
          RxHeaderLen = 4
        EndIf

        If BytesRead >= RxHeaderLen + PayloadLen
          Result = PeekS(*Buffer + RxHeaderLen, PayloadLen, #PB_UTF8)
          Break
        EndIf
      EndIf
    Else
      Delay(1)
    EndIf
  Until ElapsedMilliseconds() > Timeout

  FreeMemory(*Buffer)
  ProcedureReturn Result
EndProcedure

Procedure.s ReadFile2(Connection.i, FilePath.s)
  WSTransaction(Connection, "stop " + #DQUOTE$ + FilePath + #DQUOTE$)
  WSTransaction(Connection, "stream " + #DQUOTE$ + FilePath + #DQUOTE$)
  
  Protected Content.s = ""
  Protected Chunk.s
  Repeat
    Chunk = WSTransaction(Connection, "read")
    If Trim(Chunk) = "> END"
      Break
    EndIf
    Content + Chunk
  ForEver
  
  WSTransaction(Connection, "close")
  ProcedureReturn Content
EndProcedure

Procedure WriteFile2(Connection.i, FilePath.s, RawText.s)
  WSTransaction(Connection, "remove " + #DQUOTE$ + "/temporary_script" + #DQUOTE$)
  WSTransaction(Connection, "create " + #DQUOTE$ + "/temporary_script" + #DQUOTE$)
  
  WSTransaction(Connection, "stream " + #DQUOTE$ + "/temporary_script" + #DQUOTE$)
  
  Protected *Payload = UTF8(RawText)
  Protected TotalLen.i = MemorySize(*Payload) - 1
  Protected Offset.i = 0
  Protected ChunkSize.i = 1024
  
  While Offset < TotalLen
    Protected BytesToSend = ChunkSize
    If Offset + BytesToSend > TotalLen
      BytesToSend = TotalLen - Offset
    EndIf
    
    Protected Chunk.s = PeekS(*Payload + Offset, BytesToSend, #PB_UTF8)
    ; Rohdaten senden. WSTransaction wartet auf die "Written data to file"-Bestätigung
    WSTransaction(Connection, Chunk)
    
    Offset + BytesToSend
  Wend
  
  FreeMemory(*Payload)
  
  WSTransaction(Connection, "close")
  WSTransaction(Connection, "remove " + #DQUOTE$ + FilePath + #DQUOTE$)
  WSTransaction(Connection, "rename " + #DQUOTE$ + "/temporary_script" + #DQUOTE$ + " " + #DQUOTE$ + FilePath + #DQUOTE$)
EndProcedure

PrintN("Trying to Connect to 192.168.4.1 ...")
Define IP.s = "192.168.4.1"
Define Port.i = 80
Define Connection = OpenNetworkConnection(IP, Port)

If Not Connection
  PrintN("Connection failed.")
  End
EndIf

Define Handshake.s = "GET /ws HTTP/1.1" + #CRLF$ +
                     "Host: " + IP + #CRLF$ +
                     "Upgrade: websocket" + #CRLF$ +
                     "Connection: Upgrade" + #CRLF$ +
                     "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" + #CRLF$ +
                     "Sec-WebSocket-Version: 13" + #CRLF$ + #CRLF$

SendNetworkString(Connection, Handshake)
Delay(500)

If NetworkClientEvent(Connection) = #PB_NetworkEvent_Data
  Define *HSBuf = AllocateMemory(4096)
  ReceiveNetworkData(Connection, *HSBuf, 4096)
  FreeMemory(*HSBuf)
EndIf

PrintN("Connected. Usage: list, mem, format, run <file>, stop, create <scriptname>, read <file>, delete <file>, rename <old> <new>, edit <file>, exit")


        WSTransaction(Connection, "stop " + #DQUOTE$ + "temp" + #DQUOTE$)
        PrintN(WSTransaction(Connection, "create " + #DQUOTE$ + "temp" + #DQUOTE$))
        
Repeat
  Print("> ")
  Define CmdLine.s = Input()
  Define Cmd.s = LCase(StringField(CmdLine, 1, " "))
  Define Arg1.s = StringField(CmdLine, 2, " ")
  Define Arg2.s = StringField(CmdLine, 3, " ")
  
  Select Cmd
    Case "list"
      PrintN(WSTransaction(Connection, "ls"))
    Case "create"
      If Arg1 <> ""
        WSTransaction(Connection, "stop " + #DQUOTE$ + Arg1 + #DQUOTE$)
        PrintN(WSTransaction(Connection, "create " + #DQUOTE$ + Arg1 + #DQUOTE$))
      EndIf
    Case "mem"
      PrintN(WSTransaction(Connection, "mem"))
    Case "format"
      PrintN(WSTransaction(Connection, "format"))
    Case "run"
      If Arg1 <> ""
        PrintN(WSTransaction(Connection, "run " + #DQUOTE$ + Arg1 + #DQUOTE$))
      EndIf
    Case "stop"
      PrintN(WSTransaction(Connection, "stop"))
    Case "read"
      If Arg1 <> ""
        PrintN(ReadFile2(Connection, Arg1))
      EndIf
    Case "delete"
      If Arg1 <> ""
        PrintN(WSTransaction(Connection, "remove " + #DQUOTE$ + Arg1 + #DQUOTE$))
      EndIf
    Case "rename"
      If Arg1 <> "" And Arg2 <> ""
        PrintN(WSTransaction(Connection, "rename " + #DQUOTE$ + Arg1 + #DQUOTE$ + " " + #DQUOTE$ + Arg2 + #DQUOTE$))
      EndIf
    Case "edit"
      If Arg1 <> ""
        PrintN("Read to write. End with 'EOF' in a single line:")
        Define NewContent.s = ""
        Repeat
          Define L.s = Input()
          If L = "EOF"
            Break
          EndIf
          NewContent  + #LF$ + "STRING "+ L
        ForEver
        WriteFile2(Connection, Arg1, NewContent)
        PrintN(Str(Len(NewContent))+ " characters written.")
      EndIf
    Case "exit"
      Break
    Default
      WriteFile2(Connection, "temp", "STRING "+CmdLine)
      PrintN(WSTransaction(Connection, "run " + #DQUOTE$ + "temp" + #DQUOTE$))
  EndSelect
ForEver

CloseNetworkConnection(Connection)
CloseConsole()
; IDE Options = PureBasic 6.21 (Windows - x64)
; CursorPosition = 204
; FirstLine = 159
; Folding = 0
; EnableXP
; DPIAware
; Executable = cli.exe