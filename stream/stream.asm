.486p
model flat
ideal

extrn DosClose:near
extrn DosCloseEventSem:near
extrn DosCreateEventSem:near
extrn DosDevIOCtl:near
extrn DosExit:near
extrn DosExitList:near
extrn DosOpen:near
extrn DosResetEventSem:near
extrn DosSetPriority:near
extrn DosSleep:near
extrn DosWaitEventSem:near
extrn DosWrite:near

stack 8192

dataseg ; must be first
; define isochronous buffers
aSize=65536 ; maximum value
mSize=65535 ; maximum value
IsoData db aSize dup(0)
iUsed=3 ; number of buffers
iSize=mSize/iUsed ; buffer size
tSize=iSize*iUsed ; total size
fUsed=0 ; number of frames

dataseg
szDevice db '\DEV\'
szDriver db '$',0,0,0,0,0,0,0,0
szOutput db 'stream.raw',0

dataseg
sGood0 db 'started.',13,10
sGood1 db 'stopped.',13,10
sGood2 db 'waiting...',13,10
sGood3 db 'awaiting...',13,10
sGood4 db 'quitting...',13,10
label sGood5 byte

dataseg
sInfo0 db ' opening usbecd.sys',13,10
sInfo1 db ' setting configuration',13,10
sInfo2 db ' setting alternate interface',13,10
sInfo3 db ' creating event semaphore',13,10
sInfo4 db ' opening isochronous',13,10
sInfo5 db ' queuing isochronous',13,10
sInfo6 db ' closing isochronous',13,10
sInfo7 db ' closing event semaphore',13,10
sInfo8 db ' resetting default interface',13,10
sInfo9 db ' closing usbecd.sys',13,10
sInfoA db ' descriptor:'
sInfoB db ' parameters:'
sInfoC db ' complete:'
label sInfoD byte

dataseg
sTest0 db ' opening stream.raw',13,10
sTest1 db ' closing stream.raw',13,10
label sTest2 byte

udataseg
ActionTaken dd ?
BytesDone dd ?
fhDevice dd ?
fhOutput dd ?

udataseg
GetConfigDescriptor dd 2 dup(?)
ConfigDescriptor db 8192 dup(?)

dataseg
SetConfiguration db 00h,09h,01h,00h,00h,00h,00h,00h

dataseg
SetInterface db 01h,0Bh,00h,00h,00h,00h,00h,00h

dataseg
; parameter buffer
IsoParm dd 0 ; hEventSem
  db 00h ; bEndpointAddress
  db 00h ; bAlternateSetting
  dw 0000h ; wIsoFrameLength
  dw iSize ; wIsoBufferLength
  dw iUsed ; wIsoBufferCount
  dw fUsed ; wIsoFrameCount

udataseg
wIsoFrameLength dd ?

dataseg
IsoFree dd iUsed
IsoThis dd offset(IsoData)

udataseg
DataLen dd ?
IsoPost dd ?
ParmLen dd ?

codeseg
proc MainRoutine c near
arg @@Mod,@@Nul,@@Env,@@Arg
; determine begin of arguments
  cld ; operate foreward scan
  mov ecx,512 ; max scan length
  mov edi,[@@Arg] ; start address
  repne scasb ; find terminator
; process passed arguments
  call ProcessArguments
; show application started message
  call DosWrite c,1,offset(sGood0),sGood1-sGood0,offset(BytesDone)
; open raw iso data output file
  call DosWrite c,1,offset(sTest0),sTest1-sTest0,offset(BytesDone)
  call DosOpen c,offset(szOutput),offset(fhOutput),offset(ActionTaken),0,0,012h,0191h,0
  call ShowReturnCode
  jnz BadRawOpenAttempt
; open usb stream device driver
  call DosWrite c,1,offset(sInfo0),sInfo1-sInfo0,offset(BytesDone)
  call DosOpen c,offset(szDevice),offset(fhDevice),offset(ActionTaken),0,0,1,18,0
  call ShowReturnCode
  jnz BadDosOpenAttempt
; obtain 1st configuration descriptor
  mov [GetConfigDescriptor+0],02000680h
  mov [GetConfigDescriptor+4],20000000h
  call DosWrite c,[fhDevice],offset(GetConfigDescriptor),8192+8,offset(BytesDone)
  call ShowReturnCode
  jnz NotIsoOpenAttempt
; fix isochronous open arguments
  mov esi,offset(ConfigDescriptor)
; get total descriptor size
  movzx ebx,[word(esi+2)]
label NextDescriptor near
; point to next descriptor
  and eax,0FFh ; length
  add esi,eax ; next
  sub ebx,eax ; next
  jna NotIsoOpenAttempt
label ScanDescriptors near
; find interface descriptor
  mov eax,[esi] ; start
  cmp ah,4 ; interface
  jne NextDescriptor
; check interface descriptor
  mov ecx,[esi+2] ; values
; verify bInterfaceNumber
  cmp cl,[SetInterface+4]
  jne NextDescriptor
; verify bAlternateSetting
  cmp ch,[SetInterface+2]
  jne NextDescriptor
; show matched descriptor
  call DosWrite c,1,offset(sInfoA),sInfoB-sInfoA,offset(BytesDone)
  mov eax,[esi] ; start
  bswap eax ; reorder
  call ShowReturnCode
  bswap eax ; restore
label ScanInterface near
; point to next descriptor
  and eax,0FFh ; length
  add esi,eax ; next
  sub ebx,eax ; next
  jna NotIsoOpenAttempt
; find endpoint descriptor
  mov eax,[esi] ; start
  cmp ah,5 ; endpoint
  jne ScanInterface
; check endpoint descriptor
  mov ecx,[esi+2] ; values
; verify bEndpointAddress
  cmp cl,[byte(IsoParm+4)]
  jne ScanInterface
; verify bmAttributes
  and ch,0F3h ; synctype
  cmp ch,1 ; isochronous
  jne ScanInterface
; override wMaxPacketSize
  shr ecx,16 ; wMaxPacketSize
  mov [word(IsoParm+6)],cx
; calculate wIsoFrameLength
  mov eax,ecx ; wMaxPacketSize
  and ah,07h ; wIsoFrameLength
  mov [wIsoFrameLength],eax
  and ch,18h ; multiplier
  shr ch,03h ; position
  cmp ch,03h ; invalid
  je EndMultiplier
  cmp ch,01h ; twice
  jb EndMultiplier
  je AddMultiplier
  add eax,eax ; twice
label AddMultiplier near
  add [wIsoFrameLength],eax
label EndMultiplier near
; show matched descriptor
  call DosWrite c,1,offset(sInfoA),sInfoB-sInfoA,offset(BytesDone)
  mov eax,[esi] ; start
  bswap eax ; reorder
  call ShowReturnCode
; show current parameters
  call DosWrite c,1,offset(sInfoB),sInfoC-sInfoB,offset(BytesDone)
  mov eax,[IsoParm+4]
  call ShowReturnCode
; set configuration request
  call DosWrite c,1,offset(sInfo1),sInfo2-sInfo1,offset(BytesDone)
  call DosWrite c,[fhDevice],offset(SetConfiguration),8,offset(BytesDone)
  call ShowReturnCode
  jnz NotIsoOpenAttempt
; setup alternative interface request
  call DosWrite c,1,offset(sInfo2),sInfo3-sInfo2,offset(BytesDone)
  call DosWrite c,[fhDevice],offset(SetInterface),8,offset(BytesDone)
  call ShowReturnCode
  jnz NotIsoOpenAttempt
; create isochronous event semaphore
  call DosWrite c,1,offset(sInfo3),sInfo4-sInfo3,offset(BytesDone)
  call DosCreateEventSem c,0,offset(IsoParm),1,0
  call ShowReturnCode
  jnz NotIsoOpenAttempt
; register termination processing
  call DosExitList c,1,offset(ProcessComplete)
; open isochronous transfer
  call DosWrite c,1,offset(sInfo4),sInfo5-sInfo4,offset(BytesDone)
  call DosDevIOCtl c,[fhDevice],0ECh,040h,offset(IsoParm),14,offset(ParmLen),offset(IsoData),tSize,offset(DataLen)
  call ShowReturnCode
  jnz EndProcess
; show application waiting message
  call DosWrite c,1,offset(sGood2),sGood3-sGood2,offset(BytesDone)
; hang in here for 3 seconds
  call DosSleep c,3000
; process iso buffers
  call ProcessIsoStream
label EndProcess near
; force process complete
  sub eax,eax ; success
  ret ; uses exit list
label NotIsoOpenAttempt near
; close usb stream device driver
  call DosWrite c,1,offset(sInfo9),sInfoA-sInfo9,offset(BytesDone)
  call DosClose c,[fhDevice]
  call ShowReturnCode
label BadDosOpenAttempt near
; close raw iso data output file
  call DosWrite c,1,offset(sTest1),sTest2-sTest1,offset(BytesDone)
  call DosClose c,[fhOutput]
  call ShowReturnCode
label BadRawOpenAttempt near
; show application stopped message
  call DosWrite c,1,offset(sGood1),10,offset(BytesDone)
; exit the process
  call DosExit c,1,0
endp MainRoutine

codeseg
proc ProcessComplete c near
arg @@ReasonCode
; show application quitting message
  call DosWrite c,1,offset(sGood4),sGood5-sGood4,offset(BytesDone)
; report reason code
; mov eax,[@@ReasonCode]
; call ShowReturnCode
; close isochronous transfer
  call DosWrite c,1,offset(sInfo6),sInfo7-sInfo6,offset(BytesDone)
  call DosDevIOCtl c,[fhDevice],0ECh,041h,0,0,0,0,0,0
  call ShowReturnCode
; close isochronous event semaphore
  call DosWrite c,1,offset(sInfo7),sInfo8-sInfo7,offset(BytesDone)
  call DosCloseEventSem c,[IsoParm]
  call ShowReturnCode
; reset alternative interface request
  mov [SetInterface+2],0 ; zero bandwidth
  call DosWrite c,1,offset(sInfo8),sInfo9-sInfo8,offset(BytesDone)
  call DosWrite c,[fhDevice],offset(SetInterface),8,offset(BytesDone)
  call ShowReturnCode
; close usb stream device driver
  call DosWrite c,1,offset(sInfo9),sInfoA-sInfo9,offset(BytesDone)
  call DosClose c,[fhDevice]
  call ShowReturnCode
; close raw iso data output file
  call DosWrite c,1,offset(sTest1),sTest2-sTest1,offset(BytesDone)
  call DosClose c,[fhOutput]
  call ShowReturnCode
; show application stopped message
  call DosWrite c,1,offset(sGood1),10,offset(BytesDone)
; exit termination process
  call DosExitList c,3,0)
endp ProcessComplete

dataseg
RawBytesDone dd 0

codeseg
proc ProcessIsoStream near
; set time critical priority
; call DosSetPriority c,2,3,31,0
; prepare for frame size arrays
  mov edi,offset(IsoData+iSize-4)
label QueueEmptyIsoBuffers near
; initialize frame size array
  movzx ecx,[word(IsoParm+12)]
  test ecx,ecx ; wIsoFrameCount
  jz EndSetFrameSizeArray
  mov eax,[wIsoFrameLength]
  sub edi,ecx ; wIsoFrameCount
  sub edi,ecx ; wIsoFrameCount
  rep stosw ; wIsoFrameLength
  add edi,iSize ; bump pointer
label EndSetFrameSizeArray near
; queue empty isochronous buffers
  call DosWrite c,1,offset(sInfo5),sInfo6-sInfo5,offset(BytesDone)
  call DosDevIOCtl c,[fhDevice],0ECh,042h,0,0,0,0,0,0
  call ShowReturnCode
  dec [IsoFree] ; count
  jnz QueueEmptyIsoBuffers
label AwaitFilledIsoBuffers near
; await filled isochronous buffers
  call DosWrite c,1,offset(sGood3),sGood4-sGood3,offset(BytesDone)
  call DosWaitEventSem c,[IsoParm],-1
  call ShowReturnCode
; update filled isochronous buffers
  call DosResetEventSem c,[IsoParm],offset(IsoPost)
  mov eax,[IsoPost] ; additional
  add [IsoFree],eax ; current
label ProcessRawIsoData near
; address current isochronous buffer
  mov esi,[IsoThis] ; this buffer
; show actual completion lengths
  call DosWrite c,1,offset(sInfoC),sInfoD-sInfoC,offset(BytesDone)
  mov eax,[dword(esi+iSize-4)]
  call ShowReturnCode
; write current iso buffer
  movzx ecx,[word(IsoParm+12)]
  test ecx,ecx ; wIsoFrameCount
  jz WriteStreamDataBytes
; get start of frame size array
  and eax,0FFFFh ; buffer1length
  lea edi,[esi+eax] ; size array
  sub ebx,ebx ; 1st frame index
label WriteIsochronousFrame near
; write to raw iso data output file
  movzx eax,[word(edi+ebx*2)] ; size
  add [RawBytesDone],eax ; total
  call DosWrite c,[fhOutput],esi,eax,offset(BytesDone)
; reset size to wIsoFrameLength
  mov eax,[wIsoFrameLength]
  mov [word(edi+ebx*2)],ax
; loop until all frames done
  movzx ecx,[word(IsoParm+12)]
  inc ebx ; next frame index
  cmp ebx,ecx ; wIsoFrameCount
  jnb QueueEmptyIsoBuffer ; done
  add esi,eax ; wIsoFrameLength
  jmp WriteIsochronousFrame
label WriteStreamDataBytes near
; write to raw iso data output file
  shr eax,16 ; buffer2length
  add [RawBytesDone],eax ; total
  call DosWrite c,[fhOutput],esi,eax,offset(BytesDone)
label QueueEmptyIsoBuffer near
; queue empty isochronous buffer
  call DosWrite c,1,offset(sInfo5),sInfo6-sInfo5,offset(BytesDone)
  call DosDevIOCtl c,[fhDevice],0ECh,042h,0,0,0,0,0,0
  call ShowReturnCode
; update next iso buffer pointer
  add [IsoThis],iSize ; bump pointer
  cmp [IsoThis],offset(IsoData+tSize)
  jne DecrementFreeBuffers ; proper
  mov [IsoThis],offset(IsoData)
label DecrementFreeBuffers near
  dec [IsoFree] ; count
  jnz ProcessRawIsoData
; stop with enough raw data
  cmp [RawBytesDone],tSize*15
  jna AwaitFilledIsoBuffers
  ret ; return
endp ProcessIsoStream

codeseg
proc chr2ddn near
; convert char to ddname
  xor esi,esi ; first position
label UpdateDriverName near
  inc edi ; next position
  mov al,[edi] ; obtain
; validate character
  cmp al,"!" ; control
  jb EndChr2ddn ; reject
  cmp al,'"' ; special
  je EndChr2ddn ; reject
  cmp al,"*" ; special
  je EndChr2ddn ; reject
  cmp al,"." ; special
  je EndChr2ddn ; reject
  cmp al,"/" ; special
  je EndChr2ddn ; reject
  cmp al,":" ; special
  je EndChr2ddn ; reject
  cmp al,"<" ; special
  je EndChr2ddn ; reject
  cmp al,">" ; special
  je EndChr2ddn ; reject
  cmp al,"?" ; special
  je EndChr2ddn ; reject
  cmp al,"\" ; special
  je EndChr2ddn ; reject
  cmp al,"|" ; special
  je EndChr2ddn ; reject
; update ddname character
  mov [szDriver+esi],al
  inc esi ; next position
  cmp esi,8 ; maximum
  jb UpdateDriverName
label EndChr2ddn near
  ret ; return
endp chr2ddn

codeseg
proc hex2bin near
; convert hex to binary
  sub edx,edx ; output
label ConvertInput near
  inc edi ; next position
  mov al,[edi] ; digit
; convert decimal digit
  cmp al,"0" ; minimum
  jb NotDecimal ; hex
  cmp al,"9" ; maximum
  ja NotDecimal ; hex
; convert to binary
  sub al,"0"-00h
  shl edx,4 ; output
  xor dl,al ; insert
  jmp ConvertInput
label NotDecimal near
; convert character
  cmp al,"A" ; minimum
  jb EndHex2bin ; end
  cmp al,"F" ; maximum
  ja EndHex2bin ; end
; convert to binary
  sub al,"A"-0Ah
  shl edx,4 ; output
  xor dl,al ; insert
  jmp ConvertInput
label EndHex2bin near
  ret ; return
endp hex2bin

codeseg
proc ProcessArguments near
; scan for forward slash
  mov al,[edi] ; character
  inc edi ; next position
  cmp al,00h ; terminator
  je EndScanString ; done
  cmp al,'/' ; parameter
  jne ProcessArguments
; parm AlternateSetting
  cmp [byte(edi)],'a'
  jne NotAltSetting
  call hex2bin ; convert
; override bAlternateSetting
  mov [byte(SetInterface+2)],dl
  mov [byte(IsoParm+5)],dl
  jmp ProcessArguments
label NotAltSetting near
; parm EndpointAddress
  cmp [byte(edi)],'e'
  jne NotEptAddress
  call hex2bin ; convert
; override bEndpointAddress
  mov [byte(IsoParm+4)],dl
  jmp ProcessArguments
label NotEptAddress near
; parm IsoFrameCount
  cmp [byte(edi)],'f'
  jne NotFrameCount
  call hex2bin ; convert
; override wIsoFrameCount
  mov [word(IsoParm+12)],dx
  jmp ProcessArguments
label NotFrameCount near
; parm InterfaceNumber
  cmp [byte(edi)],'i'
  jne NotIntfcNumber
  call hex2bin ; convert
; override bInterfaceNumber
  mov [byte(SetInterface+4)],dl
  jmp ProcessArguments
label NotIntfcNumber near
; parm DeviceDriverName
  cmp [byte(edi)],'n'
  jne ProcessArguments
  call chr2ddn ; update
  jmp ProcessArguments
label EndScanString near
; skip sanity checks
  ret ; return
endp ProcessArguments

dataseg
hex2ascii db '0123456789ABCDEF'

dataseg
szStatus db '[????????]',13,10

codeseg
proc ShowReturnCode near
; skip zero return code
  test eax,eax ; zero
  jz EndShow ; finished
  push eax ; save register
; convert return code
  mov ecx,8 ; code length
label ConvertDigit near
  mov edx,eax ; error code
  and edx,0000000Fh ; digit
  mov dl,[hex2ascii+edx]
  mov [szStatus+ecx],dl
  shr eax,4 ; next one
  loop ConvertDigit
; show appropriate info message
  call DosWrite c,1,offset(szStatus),12,offset(BytesDone)
  pop eax ; restore register
  test eax,eax ; check
label EndShow near
  ret ; return
endp ShowReturnCode

end MainRoutine
