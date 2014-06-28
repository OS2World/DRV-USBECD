/* test with the USBECD.SYS device driver */
rc=RxFuncAdd('SysGetMessage','RexxUtil','SysGetMessage')

/* obtain device driver name */
parse upper arg ddName SuperfluousArguments
if ddName = '' then ddName = '$' /* default device driver name */

/* protect the file system from inadvertent access */
if stream(ddName,'command','query exists') \= '\DEV\' || ddName
then do
  say 'ERROR: The device driver' ddName 'cannot be used! Please refer'
  say 'to the installation instructions in the usbecd.txt file.'
  /* wait */
  '@pause'
  exit
  end

/* acquire the device driver */
rc=stream(ddName,'command','open')
if rc \= 'READY:'
then do
  /* obtain and issue error message */
  parse value rc with sState ':' mNumber
  say SysGetMessage(mNumber,,ddName)
  /* wait */
  '@pause'
  exit
  end

/* get descriptor - device */
oiBuffer = substr(x2c(80 06 00 01 00 00 12 00),1,32,x2c(EE))
oiHeader = 'GetDescriptor: Device'
call IssueWriteFunction
iString.1 = substr(oiBuffer,23,1)
iString.2 = substr(oiBuffer,24,1)
iString.3 = substr(oiBuffer,25,1)
/* wait */
'@pause'

/* get descriptor - configuration */
oiBuffer = substr(x2c(80 06 00 02 00 00 27 00),1,56,x2c(EE))
oiHeader = 'GetDescriptor: Configuration'
call IssueWriteFunction
iString.4 = substr(oiBuffer,15,1)
/* wait */
'@pause'

/* get descriptor - string languages */
oiBuffer = substr(x2c(80 06 00 03 00 00 04 00),1,16,x2c(EE))
oiHeader = 'GetDescriptor: StringLanguages'
call IssueWriteFunction
language = substr(oiBuffer,11,2)
/* wait */
'@pause'

do i = 1 to 4
  if c2d(iString.i) > 0
  then do
    /* get descriptor - string length */
    oiBuffer = substr(x2c(80 06 00 03 00 00 01 00),1,16,x2c(EE))
    oiBuffer = overlay(language,oiBuffer,5) /* string language */
    oiBuffer = overlay(iString.i,oiBuffer,3) /* string index */
    oiHeader = 'GetDescriptor: String(' || i || ') Length'
    call IssueWriteFunction
    szBuffer = substr(oiBuffer,9,1)
    /* wait */
    '@pause'
    /* get descriptor - string unicode */
    oiBuffer = overlay(szBuffer,oiBuffer,7,c2d(szBuffer)+2,x2c(00))
    oiHeader = 'GetDescriptor: String(' || i || ') Unicode'
    call IssueWriteFunction
    call ShowUnicodeString
    /* wait */
    '@pause'
    end
  end

/* get configuration - device */
oiBuffer = substr(x2c(80 08 00 00 00 00 01 00),1,16,x2c(EE))
oiHeader = 'GetConfiguration: Device'
call IssueWriteFunction
/* wait */
'@pause'

/* set configuration - configured */
oiBuffer = substr(x2c(00 09 01 00 00 00 00 00),1,16,x2c(EE))
oiHeader = 'SetConfiguration: Configured'
call IssueWriteFunction
/* wait */
'@pause'

/* get status - device */
oiBuffer = substr(x2c(80 00 00 00 00 00 02 00),1,16,x2c(EE))
oiHeader = 'GetStatus: Device'
call IssueWriteFunction
/* wait */
'@pause'

/* get status - interface */
oiBuffer = substr(x2c(81 00 00 00 00 00 02 00),1,16,x2c(EE))
oiHeader = 'GetStatus: Interface'
call IssueWriteFunction
/* wait */
'@pause'

/* get status - endpoint */
oiBuffer = substr(x2c(82 00 00 00 00 00 02 00),1,16,x2c(EE))
oiHeader = 'GetStatus: Endpoint'
call IssueWriteFunction
/* wait */
'@pause'

/* release the device driver */
rc=stream(ddName,'command','close')
if rc \= 'READY:'
then do
  /* obtain and issue error message */
  parse value rc with sState ':' mNumber
  say SysGetMessage(mNumber,,ddName)
  /* wait */
  '@pause'
  end
exit

IssueWriteFunction:
/* usb control transfer */
say
say oiHeader
say c2x(oiBuffer) /* show supplied data */
rc=charout(ddName,oiBuffer) /* supply and obtain setup and data packet */
say c2x(oiBuffer) /* show obtained data */
say
/* check completion code */
rc=stream(ddName,'description')
if rc \= 'READY:'
then do
  /* obtain and issue error message */
  parse value rc with sState ':' mNumber
  if mNumber == 95 /* character i/o call interrupted */
  then say "I/O canceled (4 seconds time-out) ..."
  else say SysGetMessage(mNumber,,ddName)
  /* wait */
  '@pause'
  exit
  end
return

ShowUnicodeString:
/* default to english */
rc=charout(stdout,'In English: ')
szString=c2d(substr(oiBuffer,9,1)); xPos=11
do while szString > 2
  rc=charout(stdout,substr(oiBuffer,xPos,1))
  szString=SzString-2
  xPos=xPos+2
  end
say
say
return
