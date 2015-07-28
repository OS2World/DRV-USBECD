.386p
model use16 small
ideal

extrn Dos16Write:far

dataseg
; device driver header
hdrlnk dd 0FFFFFFFFh
hdratr dw 0D180h
hdrstr dw offset(strategy)
hdridc dw offset(idcentry)
hdrddn db "$       "
hdrres db 8 dup(0)
hdrbit dd 000000010h

dataseg
; device helper
devhlp dd 0

dataseg
; allocgdtselectors
gdtsel dw 2 dup(0)

dataseg
; attachdd usbd
idcepi dw 6 dup(0)

dataseg
; attach device specification
adsvid dw 0 ; vendor identification
adspid dw 0 ; product identification
adsdrn dw 0 ; device release number

dataseg
; attach device wildcard mask
adxvid dw 0 ; vendor identification
adxpid dw 0 ; product identification
adxdrn dw 0 ; device release number

dataseg
; attached device address
adaproper dw 0 ; good device
adarecent dw 0 ; last device

dataseg
; register class driver request
regheader db 0,0,10h,0,0,0,0,0,0,0,0,0,0
regctcfnc db 91h,43h ; usbd register
regsupply dd idctarget
regobtain dw 0,0,0,0,0
; supply request block
idctarget dd idcentry
idcdatsel dw @data

dataseg
; standard device request
sdrheader db 0,0,10h,0,0,0,0,0,0,0,0,0,0
sdrctcfnc db 91h,41h ; usbd acceptio
sdrsupply dd sdrreqblk
sdrobtain dw 0,0,0,0,0
; supply request block
sdrreqblk dw 0
sdrreqept dw 0
sdrreqflg dw 0
sdrbufad1 dd 0
sdrbufsz1 dw 0
sdrbufad2 dd 0
sdrbufsz2 dw 0
sdrdefsfr dw 0
sdrmaxpkz dw 0
sdrtarget dd idcentry
sdrdatsel dw @data
sdrcatgry db 92h ; class
sdrreqdat dd 0,0,0
sdrmaxerr db 3
sdrnxtblk dd 0

dataseg
; terminate device request
tdrheader db 0,0,10h,0,0,0,0,0,0,0,0,0,0
tdrctcfnc db 91h,42h ; usbd cancelio
tdrsupply dd sdrreqblk
tdrobtain dw 0,0,0,0,0

dataseg
; isochronous device request
idrheader db 0,0,10h,0,0,0,0,0,0,0,0,0,0
idrctcfnc db 91h,41h ; usbd acceptio
idrsupply dd idrreqblk
idrobtain dw 0,0,0,0,0
; supply request block
idrreqblk dw 0
idrreqept dw 0
idrreqflg dw 8220h
idrbufad1 dd 0
idrbufsz1 dw 0
idrbufad2 dd 0
idrbufsz2 dw 0
idrdefsfr dw 0
idrmaxpkz dw 0
idrtarget dd idcentry
idrdatsel dw @data
idrcatgry db 92h ; class
idrreqdat dd 1,0,0
idrmaxerr db 3
idrnxtblk dd 0
idraltint db 0
idriflags db 2
idrifrmsz dw 0
idrinabuf dw 0
idrhbmult db 0
idrhubadr db 0
idrprtnum db 0

dataseg
flsilence db 0

codeseg
proc DevBeep near
; obtain user attention
  cmp [flsilence],0 ; beep
  jne EndDevBeep ; silent
  push bx ; save register
  mov bx,3000 ; frequency
  mov cx,200 ; duration
  mov dl,52h ; sound beep
  call [devhlp] ; helper
  pop bx ; restore register
label EndDevBeep near
  ret ; return
endp DevBeep

codeseg
proc idcentry c far
arg @@offset,@@selector
; obtain packet pointer
  mov bx,[@@offset] ; packet
  mov es,[@@selector] ; packet
; check generic ioctl command
  cmp [byte(es:bx+02)],10h
  mov ax,8113h ; error/done/parm
  jne EndIdcEntry ; failure
; check category class code
  mov cx,[es:bx+13] ; function
  cmp cl,92h ; class category
  jne EndIdcEntry ; failure
; access parameter buffer
  lfs di,[dword(es:bx+15)]
; handle process complete
  cmp ch,44h ; process irq
  jne NotInterrupt ; other
; check isochronous interrupt
  cmp [byte(fs:di+29)],1 ; iso
  jne NotIsoInterrupt ; other
  call idciso ; isochronous
  jmp IdcGoodStatus ; done
label NotIsoInterrupt near
; provide completion status
  mov ax,[es:bx+03] ; status
  mov [word(sdrheader+03)],ax
; provide completion result
  cmp [byte(fs:di+06)],8
  je SetParmPacket ; data
; control transfer complete
; obtain 2nd buffer length
  mov cx,[word(fs:di+16)]
; access 1st data buffer
  lfs di,[dword(fs:di+06)]
; supply completion length
  mov [word(fs:di+06)],cx
  jmp EndProvideResult
label SetParmPacket near
; bulk/interrupt complete
; obtain completion toggle
  mov dl,[byte(fs:di+05)]
; obtain 1st buffer length
  mov cx,[word(fs:di+10)]
; access 1st data buffer
  lfs di,[dword(fs:di+06)]
; supply completion length
  mov [word(fs:di-02)],cx
; update completion toggle
  test ah,80h ; any error
  jnz EndUpdateToggle ; yes
  xor dl,008h ; acknowledged
label EndUpdateToggle near
; supply completion toggle
  mov [byte(fs:di-07)],dl
label EndProvideResult near
; release blocked thread
  push bx ; save register
  mov ax,ds ; event number
  mov bx,offset(sdrreqblk)
  mov dl,05h ; release
  call [devhlp] ; helper
  pop bx ; restore register
  jmp IdcGoodStatus ; done
label NotInterrupt near
; handle device attached
  cmp ch,45h ; check service
  jne NotAttached ; other
; access device information
  lgs si,[dword(fs:di+00)]
; retain last device address
  mov cx,[word(gs:si+00)]
  mov [adarecent],cx ; address
; verify device not present
  cmp [adaproper],0 ; absent
  mov ax,0119h ; done/rejected
  jne EndIdcEntry ; present
; verify attached device
  mov dx,[word(gs:si+28)]
  and dx,[adxvid] ; idVendor
  cmp dx,[adsvid] ; idVendor
  jne EndIdcEntry ; reject
  mov dx,[word(gs:si+30)]
  and dx,[adxpid] ; idProduct
  cmp dx,[adspid] ; idProduct
  jne EndIdcEntry ; reject
  mov dx,[word(gs:si+32)]
  and dx,[adxdrn] ; bcdDevice
  cmp dx,[adsdrn] ; bcdDevice
  jne EndIdcEntry ; reject
; mark device vendor specific
  mov [byte(gs:si+24)],255
; mark device configured
  mov al,[byte(gs:si+43)]
  mov [byte(gs:si+02)],al
; retain good device address
  mov [adaproper],cx ; address
  call DevBeep ; attach alert
  jmp IdcGoodStatus ; done
label NotAttached near
; handle device detached
  cmp ch,46h ; detach device
  jne EndIdcEntry ; failure
; verify this device present
  mov cx,[word(fs:di+00)]
  cmp cx,[adaproper] ; address
  mov ax,0119h ; done/rejected
  jne EndIdcEntry ; other device
; remove good device address
  mov [adaproper],0 ; absent
  call DevBeep ; detach alert
label IdcGoodStatus near
; set success status code
  mov ax,0100h ; ok/done
label EndIdcEntry near
; return status code
  mov [es:bx+03],ax
  ret ; return
endp idcentry

codeseg
proc idciso near
; obtain 1st buffer length
  mov ax,[word(fs:di+10)]
; obtain 2nd buffer length
  mov cx,[word(fs:di+16)]
; obtain 1st data buffer address
  mov di,[word(fs:di+06)] ; offset
  mov fs,[gdtsel+2] ; selector
; point just after this buffer
  add di,[BufferNext] ; bump
; supply 1st buffer length
  mov [word(fs:di-4)],ax
; supply completion length
  mov [word(fs:di-2)],cx
; open event semaphore
  mov eax,[EventHandle]
  mov dl,67h ; openeventsem
  call [devhlp] ; helper
; post event semaphore
  mov eax,[EventHandle]
  mov dl,69h ; posteventsem
  call [devhlp] ; helper
; close event semaphore
  mov eax,[EventHandle]
  mov dl,68h ; closeeventsem
  call [devhlp] ; helper
  ret ; return
endp idciso

codeseg
proc IdcUsbd c near
uses ds,di,es,fs,si,bx,cx
; obtain usbd entry point
  mov dx,ds ; data selector
  lea di,[idcepi+06] ; target
  mov cx,es ; packet selector
  mov es,dx ; data selector
; provide usbd data selector
  mov ds,[idcepi+10] ; selector
; invoke usbd function processor
  call [dword(es:di)] c,bx,cx
  ret ; return
endp IdcUsbd

dataseg
BufferNext dw 0
BufferSize dw 0
EventHandle dd 0
LockHandle db 12 dup(0)

codeseg
proc IssueIoControl near
; obtain isochronous flags
  mov al,[idriflags] ; state
; obtain function/category
  mov dx,[word(es:bx+13)]
; isochronous open request
  cmp dx,40ECh ; open request
  jne NotIsoOpen ; other
; check isochronous closed
  cmp al,2 ; closed state
  je ProcessIsoOpen ; free
; issue isochronous close
  call ProcessIsoClose
label ProcessIsoOpen near
; access proper device
  mov si,[adaproper]
; setup device address
  mov [idrreqblk],si
; check parm buffer size
  mov cx,[word(es:bx+25)]
  cmp cx,12 ; length
  je VerifyParmBuffer
  cmp cx,14 ; length
  je VerifyParmBuffer
label SetIsoFailure near
  mov ax,8113h ; error/done/parm
  ret ; return failure
label VerifyParmBuffer near
; verify parm buffer accessible
  mov ax,[word(es:bx+17)] ; selector
  mov di,[word(es:bx+15)] ; offset
  mov dx,0127h ; verifyaccess
  call [devhlp] ; helper
  jc SetIsoFailure
; obtain parm buffer address
  lfs si,[dword(es:bx+15)]
; save event semaphore handle
  mov eax,[dword(fs:si+00)]
  mov [EventHandle],eax
; set alternate index
  mov ax,[word(fs:si+04)]
  mov [idraltint],ah
; check endpoint address
  test al,0Fh ; number
  jz SetIsoFailure
; set endpoint address
  and ax,008Fh ; endpoint
  mov [idrreqept],ax
; setup transfer direction
  cmp al,80h ; device-to-host
  mov al,21h ; device-to-host ;*
  jnb EndSetupDirection ; no
  mov al,22h ; host-to-device ;*
label EndSetupDirection near
  mov [byte(idrreqflg)],al
; check iso frame length
  mov ax,[word(fs:si+06)]
  test ax,ax ; nonzero
  jz SetIsoFailure
; set max packet size
  mov dh,ah ; multiplier
  and ah,07h ; get size
  mov [idrmaxpkz],ax
; set packet multiplier
  and dh,18h ; isolate
  shr dh,03h ; proper
  cmp dh,03h ; invalid
  je SetIsoFailure
  mov [idrhbmult],dh
; set iso frame length
  mov [idrifrmsz],ax
  cmp dh,01h ; once
  jb EndMultiple
  je AddMultiple
  add ax,ax ; twice
label AddMultiple near
  add [idrifrmsz],ax
label EndMultiple near
; check iso frame count
  sub ax,ax ; reset size
  cmp cx,14 ; available
  jne Set2ndBuffer
; apply iso frame count
  mov ax,[word(fs:si+12)]
  shl ax,1 ; buffer size
  jc SetIsoFailure
label Set2ndBuffer near
; set buffer 2 size
  mov [idrbufsz2],ax
; set iso buffer size
  mov cx,[word(fs:si+08)]
  mov [BufferNext],cx
; set number of buffers
  mov ax,[word(fs:si+10)]
  mov [idrinabuf],ax
; set buffers boundary
  mul cx ; total size
  jc SetIsoFailure
  mov [BufferSize],ax
; get buffer 1 size
  sub cx,4 ; lengths
  jb SetIsoFailure
  sub cx,[idrbufsz2]
  jb SetIsoFailure
; check buffer 1 size
  mov ax,[idrifrmsz]
  mov dx,[idrbufsz2]
  shr dx,1 ; frames
  jz CheckBuffer
  mul dx ; payloads
  jc SetIsoFailure
label CheckBuffer near
  cmp cx,ax ; minimum
  jb SetIsoFailure
; set buffer 1 size
  mov [idrbufsz1],cx
; check data buffer size
  mov cx,[word(es:bx+27)]
  cmp cx,[BufferSize]
  jb SetIsoFailure
; check data buffer offset
  mov di,[word(es:bx+19)]
  test di,di ; aligned
  jnz SetIsoFailure
; verify data buffer access
  mov ax,[word(es:bx+21)]
  mov dx,0127h ; verifyaccess
  call [devhlp] ; helper
  jc SetIsoFailure
; get data buffer linear address
  movzx esi,[word(es:bx+19)]
  mov ax,[word(es:bx+21)]
  mov dl,5Bh ; virttolin
  call [devhlp] ; helper
  mov edi,eax ; linear address
; get lock handle linear address
  mov esi,offset(LockHandle)
  mov ax,ds ; data selector
  mov dl,5Bh ; virttolin
  call [devhlp] ; helper
  mov esi,eax ; linear address
; lock data buffer memory region
  mov eax,01Ah ; dma/long/write
  push bx edi ; save registers
  mov ebx,edi ; linear address
  mov edi,-1 ; no page list
  mov dl,55h ; vmlock
  call [devhlp] ; helper
  pop edi bx ; restore
  jc SetIsoFailure
; provide buffer access
  push bx ; save register
  mov ax,[gdtsel+2] ; gdtselector
  mov ebx,edi ; linear address
  mov dl,5Ch ; lintogdtselector
  call [devhlp] ; helper
  pop bx ; restore register
  jc SetIsoFailure
; set buffer 1 address
  mov eax,[es:bx+19]
  mov [idrbufad1],eax
; set buffer 2 address
  add ax,[idrbufsz1]
  mov [idrbufad2],eax
; issue isochronous open
  mov al,1 ; open request
  call IssueIsoRequest
  ret ; return
label NotIsoOpen near
; isochronous close request
  cmp dx,41ECh ; close request
  jne NotIsoClose ; other
; check isochronous closed
  cmp al,2 ; closed state
  je SetIsoSuccess ; done
label ProcessIsoClose near
; check isochronous opened
  cmp al,1 ; opened state
  je RequestIsoClose ; idle
; force isochronous cancel
  mov al,4 ; cancel request
  call IssueIsoRequest
label RequestIsoClose near
; issue isochronous close
  mov al,2 ; close request
  call IssueIsoRequest
; build linear lock handle
  mov ax,ds ; data selector
  mov esi,offset(LockHandle)
  mov dl,5Bh ; virttolin
  call [devhlp] ; helper
  mov esi,eax ; linear address
; unlock data buffer memory
  mov dl,56h ; vmunlock
  call [devhlp] ; helper
label SetIsoSuccess near
; set success status code
  mov ax,0100h ; ok/done
  ret ; return success
label NotIsoClose near
; isochronous queue request
  cmp dx,42ECh ; queue request
  jne SetIsoFailure ; error
; check isochronous closed
  cmp al,2 ; closed state
  je SetIsoFailure ; error
; issue isochronous queue
  sub ax,ax ; single buffer
  cmp [idrbufsz2],ax ; size
  je ProcessRequest ; yes
  mov al,80h ; two buffers
label ProcessRequest near
  call IssueIsoRequest
; address next data buffer
  mov dx,[word(idrbufad1)]
  add dx,[BufferNext] ; bump
  cmp dx,[BufferSize] ; limit
  jb SetBufferAddress ; next
  sub dx,dx ; first buffer
label SetBufferAddress near
; update buffer 1 address
  mov [word(idrbufad1)],dx
; update buffer 2 address
  add dx,[idrbufsz1] ; size
  mov [word(idrbufad2)],dx
  ret ; return
endp IssueIoControl

codeseg
proc IssueIoRequest near
; setup device address
  mov [sdrreqblk],si
; obtain buffer address
  push bx ; save register
  mov si,[gdtsel+0] ; gdtselector
  mov ax,[word(es:bx+16)] ; >address
  mov bx,[word(es:bx+14)] ; <address
  mov dl,2Eh ; phystogdtselector
  call [devhlp] ; helper
  pop bx ; restore register
  mov ax,810Ch ; error/done/general
  jc NotIssueIoRequest ; failure
  mov fs,si ; buffer selector
; provide read setup packet
  cmp [byte(es:bx+02)],04h
  jne EndProvideRead ; write
; set get device descriptor
  mov [word(fs:0)],0680h
  mov [word(fs:2)],0100h
  mov [word(fs:4)],0000h
  mov [word(fs:6)],0012h
label EndProvideRead near
; obtain data buffer size
  mov di,[fs:6] ; size
; verify data buffer size
  sub cx,08h ; setup length
  cmp cx,di ; data buffer size
  mov ax,8113h ; error/done/parm
  jb NotIssueIoRequest ; failure
; verify setup packet passed
  mov cx,[fs:0] ; request
  mov dx,[fs:4] ; endpoint
  cmp cl,0ECh ; not setup
  je NotControlTransfer
label ControlTransfer near
; provide setup packet address
  mov [word(sdrbufad1+0)],0
  mov [word(sdrbufad1+2)],si
; provide setup packet size
  mov [sdrbufsz1],8 ; size
; provide data buffer address
  mov [word(sdrbufad2+0)],8
  mov [word(sdrbufad2+2)],si
; provide data buffer size
  mov [sdrbufsz2],di ; size
; default control transfer
  mov cx,0004h ; transfer
  mov dx,0000h ; endpoint
  jmp StartTransfer ; control
label NotControlTransfer near
; bulk/interrupt/isochronous
  mov cl,ch ; data toggle
; provide transfer type
  mov ch,40h ; interrupt
  cmp dh,03h ; interrupt
  je BulkInterrupt
  mov ch,20h ; bulk
  cmp dh,02h ; bulk
  je BulkInterrupt
; isochronous removed
  ret ; error/done/parm
label BulkInterrupt near
  and cl,08h ; data toggle
  and dx,008Fh ; endpoint
; provide initiation toggle
  xor ch,cl ; provide toggle
; provide transfer direction
  cmp dl,80h ; device-to-host
  mov cl,01h ; device-to-host
  jnb EndProvideDirection ; no
  mov cl,02h ; host-to-device
label EndProvideDirection near
; provide data buffer address
  mov [word(sdrbufad1+0)],8
  mov [word(sdrbufad1+2)],si
; provide data buffer size
  mov [sdrbufsz1],di ; size
label StartTransfer near
; setup transfer information
  mov [sdrreqflg],cx ; transfer
; setup endpoint information
  mov [sdrreqept],dx ; endpoint
; reset maximum packet size
  mov [sdrmaxpkz],0 ; default
; start acceptio operation
  push es bx ; save registers
  mov bx,ds ; get data selector
  mov es,bx ; set packet selector
  mov bx,offset(sdrheader) ; packet
  call IdcUsbd ; function acceptio
  mov ax,[es:bx+03] ; status
  test ah,80h ; any error
  mov al,0Ch ; general
  jnz EndIssueIoRequest
; await process complete
  push bx ; save register
  mov ax,ds ; event number
  mov bx,offset(sdrreqblk)
; set appropriate timeout
  sub di,di ; >interval
; check control transfer
  cmp cl,04h ; control
  mov cx,di ; <interval
  je SetFixedTimeOut
; bulk/interrupt transfer
  mov cx,[fs:2] ; timeout
; check default timeout
  test cx,cx ; minimum
  jz SetFixedTimeOut
; check without timeout
  cmp cx,0FFFFh ; -1
  jne EndSetupTimeOut
  mov di,cx ; >interval
  jmp EndSetupTimeOut
label SetFixedTimeOut near
  mov ch,10h ; 4 seconds
label EndSetupTimeOut near
  mov dx,0004h ; interruptable
  call [devhlp] ; helper
  pop bx ; restore register
  mov ax,[es:bx+03] ; status
  jnc EndIssueIoRequest ; normal
; terminate current device request
  mov bx,offset(tdrheader) ; packet
  call IdcUsbd ; function cancelio
  mov ax,8111h ; error/done/stop
label EndIssueIoRequest near
  pop bx es ; restore registers
label NotissueIoRequest near
  ret ; return
endp IssueIoRequest

codeseg
proc IssueIsoRequest
; set isochronous request
  mov [idriflags],al ; request
; start acceptio operation
  push es bx ; save registers
  mov bx,ds ; get data selector
  mov es,bx ; set packet selector
  mov bx,offset(idrheader) ; packet
  call IdcUsbd ; function acceptio
  mov ax,[es:bx+03] ; status
  pop bx es ; restore registers
  ret ; return
endp IssueIsoRequest

codeseg
proc strategy far
; set parm failure status code
  mov ax,8113h ; error/done/parm
; obtain driver request code
  mov cl,[es:bx+02] ; request
; handle doswrite request
  cmp cl,08h ; write normal
  jb NotDosWrite ; other
  cmp cl,09h ; write verify
  ja NotDosWrite ; other
; verify buffer length
  mov cx,[word(es:bx+18)]
  cmp cx,08h ; setup length
  jb EndStrategy ; failure
; access proper device
  mov si,[adaproper]
  call IssueIoRequest
  cmp al,20h ; i/o error
  jne EndStrategy ; other
  mov al,0Ah ; write fault
  jmp EndStrategy ; done
label NotDosWrite near
; handle dosread request
  cmp cl,04h ; read normal
  jne NotDosRead ; other
; verify buffer length
  mov cx,[word(es:bx+18)]
  cmp cx,1Ah ; total length
  jb EndStrategy ; failure
; access recent device
  mov si,[adarecent]
  call IssueIoRequest
  cmp al,20h ; i/o error
  jne EndStrategy ; other
  mov al,0Bh ; read fault
  jmp EndStrategy ; done
label NotDosRead near
; handle dosdevioctl request
  cmp cl,10h ; dosdevioctl
  jne NotDosDevIoctl ; other
; issue ioctrl operation
  call IssueIoControl
  jmp EndStrategy ; done
label NotDosDevIoctl near
; handle init completion
  cmp cl,1Fh ; init complete
  jne NotInitComplete
; register class driver
  push es bx ; save registers
  mov bx,ds ; get data selector
  mov es,bx ; set packet selector
  mov bx,offset(regheader) ; packet
  call IdcUsbd ; function register
  mov ax,[es:bx+03] ; status
  pop bx es ; restore registers
  mov [es:bx+03],ax ; status
  jmp EndStrategy ; done
label NotInitComplete near
; handle initialization
  cmp cl,00h ; initialize
  je Initialize ; once
label EndStrategy near
; return status code
  mov [es:bx+03],ax
  ret ; return
endp strategy

codeseg
; end of code segment
label EndCode near

dataseg
; end of data segment
label EndData byte

dataseg
flverbose db 0

dataseg
ddname db "USBD$   "

dataseg
InitMsg0 db "USBECD.SYS /D:"
msgvid db "0000:"
msgpid db "0000:"
msgdrn db "0000 /N:"
msgddn db "$        "
InitMsg1 db "Specified driver name NOT available",13,10
InitMsg2 db "Required USBD.SYS driver NOT available",13,10
InitMsg3 db "Required GDT selector NOT available",13,10
InitMsg4 db "- USB 2.0 Extended Control Driver",13,10
label InitMsg5 byte
Written dw 0

codeseg
proc bin2hex near
; convert binary to hex
  not cx ; wildcard mask
label ConvertBinData near
; convert wildcard mask
  shl cx,4 ; wildcard
  mov al,"#" ; token
  jc StoreCharacter
; convert binary data
  mov al,dh ; byte data
  shr al,4 ; nibble data
  cmp al,10 ; character
  jb NotCharacter
; convert to character
  add al,"A"-0Ah ; ascii
  jmp StoreCharacter
label NotCharacter near
; convert to decimal
  add al,"0"-00h ; ascii
label StoreCharacter near
  mov [ds:si],al ; store
  inc si ; next position
  shl dx,4 ; next nibble
  jnz ConvertBinData
  test cx,cx ; any mask
  jnz ConvertBinData
label EndBin2hex near
  ret ; return
endp bin2hex

codeseg
proc chr2ddn near
; convert char to ddname
  xor si,si ; first position
label UpdateDriverName near
  inc di ; next position
  mov al,[es:di] ; obtain
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
  mov [hdrddn+si],al ; set
  mov [msgddn+si],al ; set
  inc si ; next position
  cmp si,8 ; maximum
  jb UpdateDriverName
label EndChr2ddn near
  ret ; return
endp chr2ddn

codeseg
proc hex2bin near
; convert hex to binary
  xor dx,dx ; binary output
  xor cx,cx ; wildcard mask
label ConvertHexData near
  inc di ; next position
  mov al,[es:di] ; obtain
; convert decimal digit
  cmp al,"0" ; min
  jb NotDecimal
  cmp al,"9" ; max
  ja NotDecimal
  sub al,"0"-00h
  shl dx,4 ; output
  xor dl,al ; supply
  shl cx,4 ; ticket
  jmp ConvertHexData
label NotDecimal near
; convert character
  cmp al,"A" ; min
  jb NotHex2bin
  cmp al,"F" ; max
  ja NotHex2bin
  sub al,"A"-0Ah
  shl dx,4 ; output
  xor dl,al ; supply
  shl cx,4 ; ticket
  jmp ConvertHexData
label NotHex2bin near
; convert wildcard
  cmp al,"#" ; token
  jne EndHex2bin
  shl cx,4 ; ticket
  xor cl,0Fh ; token
  shl dx,4 ; output
  jmp ConvertHexData
label EndHex2bin near
; prepare wildcard
  not cx ; mask
  ret ; return
endp hex2bin

codeseg
proc Initialize near
; address driver parameters
  push es ; save register
  les di,[dword(es:bx+18)]
label ScanParmString near
; search for forward slash
  mov al,[es:di] ; data
  inc di ; next position
  cmp al,00h ; terminator
  je EndScanParmString
  cmp al,"/" ; parameter
  jne ScanParmString
; obtain /D: parameter
  cmp [byte(es:di)],"D"
  jne NotParmDevice
  inc di ; next position
  cmp [byte(es:di)],":"
  jne ScanParmString
; update vendor specification
  call hex2bin ; obtain vendor
  mov [adsvid],dx ; spec idVendor
  mov [adxvid],cx ; mask idVendor
  mov si,offset(msgvid) ; vendor
  call bin2hex ; supply vendor
  cmp [byte(es:di)],":"
  jne ScanParmString
; update product specification
  call hex2bin ; obtain product
  mov [adspid],dx ; spec idProduct
  mov [adxpid],cx ; mask idProduct
  mov si,offset(msgpid) ; product
  call bin2hex ; supply product
  cmp [byte(es:di)],":"
  jne ScanParmString
; update release specification
  call hex2bin ; obtain release
  mov [adsdrn],dx ; spec bcdDevice
  mov [adxdrn],cx ; mask bcdDevice
  mov si,offset(msgdrn) ; release
  call bin2hex ; supply release
  jmp ScanParmString
label NotParmDevice near
; obtain /N: parameter
  cmp [byte(es:di)],"N"
  jne NotParmDriver
  inc di ; next position
  cmp [byte(es:di)],":"
  jne ScanParmString
; update driver ddname
  call chr2ddn ; update
  jmp ScanParmString
label NotParmDriver near
; obtain /S parameter
  cmp [byte(es:di)],"S"
  jne NotParmSilent
; update silence flag
  mov [flsilence],1
  jmp ScanParmString
label NotParmSilent near
; obtain /V parameter
  cmp [byte(es:di)],"V"
  jne ScanParmString
; update verbose flag
  mov [flverbose],1
  jmp ScanParmString
label EndScanParmString near
  pop es ; restore register
; save devhlp entry point
  mov ax,[es:bx+14]
  mov [word(devhlp+00)],ax
  mov ax,[es:bx+16]
  mov [word(devhlp+02)],ax
; reduce module size
  mov ax,offset(EndCode)
  mov [es:bx+14],ax
  mov ax,offset(EndData)
  mov [es:bx+16],ax
; write startup message
  mov si,InitMsg1-InitMsg0
  mov di,offset(InitMsg0)
label ReduceLength near
  dec si ; use offset
  cmp [InitMsg0+si]," "
  je ReduceLength
  add si,2 ; length
  call IssueMessage
; verify driver ddname
  push bx ; save register
  mov bx,offset(hdrddn)
  mov di,offset(idcepi)
  mov dl,2Ah ; attachdd
  call [devhlp] ; helper
  pop bx ; restore register
  mov si,InitMsg2-InitMsg1
  mov di,offset(InitMsg1)
  jnc InitFailure ; used
; obtain USBD$ idc info
  push bx ; save register
  mov bx,offset(ddname)
  mov di,offset(idcepi)
  mov dl,2Ah ; attachdd
  call [devhlp] ; helper
  pop bx ; restore register
  mov si,InitMsg3-InitMsg2
  mov di,offset(InitMsg2)
  jc InitFailure ; error
; allocate 2 GDT selectors
  push es ; save register
  push ds ; data selector
  pop es ; selector(gdtsel)
  mov di,offset(gdtsel)
  mov dl,2Dh ; allocgdtselector
  mov cx,0002h ; 2 selectors
  call [devhlp] ; helper
  pop es ; restore register
  mov si,InitMsg4-InitMsg3
  mov di,offset(InitMsg3)
  jc InitFailure ; error
; write success message
  mov si,InitMsg5-InitMsg4
  mov di,offset(InitMsg4)
  call IssueMessage
; set success status code
  mov ax,0100h ; ok/done
  jmp EndStrategy ; success
label InitFailure near
; indicate init failure
  sub ax,ax ; ensure zeroes
  mov [es:bx+13],al ; data byte
  mov [es:bx+14],ax ; code size
  mov [es:bx+16],ax ; data size
; write failure message
  call IssueMessage
; set failure status code
  mov ax,8115h ; error/done/quiet
  jmp EndStrategy ; failure
endp Initialize

codeseg
proc IssueMessage near
; issue message to stdout
  cmp [flverbose],1 ; verbose
  jne EndIssueMessage ; suppressed
  call Dos16Write pascal,0,ds,di,si,ds,offset(Written)
label EndIssueMessage near
  ret ; return
endp IssueMessage

end
