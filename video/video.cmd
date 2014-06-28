/* load all RexxUtil functions */
Call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
Call SysLoadFuncs
'@echo off'

/* This example script is tailored to the Logitech C250 Webcam */
/* DEVICE=C:\OS2\BOOT\USBECD.SYS /D:046D:0804:0009 /N:$LTC250$ */

/* invoke test program */
CurrentDirectory = directory()
CurrentDirectory'\video.exe /a5/e81/f18/i1/n$LTC250$/x2'

if rc \=0 then do
  /* obtain and issue error message */
  say SysGetMessage(rc, 'OSO001.MSG')
  say 'ReturnCode:' rc
  end

/* wait */
'@pause'
