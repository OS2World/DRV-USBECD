/* load all RexxUtil functions */
Call RxFuncAdd 'SysLoadFuncs', 'RexxUtil', 'SysLoadFuncs'
Call SysLoadFuncs
'@echo off'

/* invoke test program */
CurrentDirectory = directory()
CurrentDirectory'\dosread.exe'

if rc \=0 then do
  /* obtain and issue error message */
  say SysGetMessage(rc, 'OSO001.MSG')
  say 'ReturnCode:' rc
  end

/* wait */
'@pause'
