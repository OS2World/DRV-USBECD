/* write to the USBECD.SYS device driver */
rc=RxFuncAdd('SysGetMessage','RexxUtil','SysGetMessage')

/* obtain device driver name */
parse upper arg ddName SuperfluousArguments
if ddName = '' then ddName = '$' /* default device driver name */

/* protect the file system from inadvertent access */
if stream(ddName,'command','query exists') \= '\DEV\' || ddName
then do
  say 'ERROR: The device driver' ddName 'cannot be used! Please refer'
  say 'to the installation instructions in the usbecd.txt file.'
  exit
  end

/* acquire the device driver */
rc=stream(ddName,'command','open')
if rc \= 'READY:'
then do
  say rc 'Device driver' ddName 'currently in use. Please try later.'
  exit
  end

/* provide description */
call OutputDeviceDescription

/* release the device driver */
rc=stream(ddName,'command','close')
exit

OutputDeviceDescription:
oiBuffer = substr(x2c(80 06 00 01 00 00 12 00),1,26,x2c(00))
call WriteSetupAndReadDescriptor
Index = 9 /* data position */
say ' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
say ' ³             bLength ³'db()'³ Descriptor Length                  ³'
say ' ³     bDescriptorType ³'db()'³ Descriptor Type                    ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³              bcdUSB ³'dw()'³ USB specification release number   ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³        bDeviceClass ³'db()'³ Device Class code                  ³'
say ' ³     bDeviceSubClass ³'db()'³ Device Sub Class code              ³'
say ' ³     bDeviceProtocol ³'db()'³ Device Protocol code               ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³     bMaxPacketSize0 ³'db()'³ Maximum Packet Size for endpoint 0 ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³            idVendor ³'dw()'³ Vendor identification              ³'
say ' ³           idProduct ³'dw()'³ Product identification             ³'
say ' ³           bcdDevice ³'dw()'³ Device release number              ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³       iManufacturer ³'dis('³ Manufacturer string index          ³')
say ' ³            iProduct ³'dis('³ Product string index               ³')
say ' ³       iSerialNumber ³'dis('³ Device Serial Number string index  ³')
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³  bNumConfigurations ³'db()'³ Number of possible Configurations  ³'
say ' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
say '   Device Driver' ddName '- Device Descriptor'
say
nConfiguration = 0
tConfiguration = c2d(substr(oiBuffer,26,1))
do while nConfiguration < tConfiguration
  call OutputConfigurationDescription
  end
return

OutputConfigurationDescription:
oiBuffer = substr(x2c(80 06 00 02 00 00 09 00),1,17,x2c(00))
oiBuffer = overlay(d2c(nConfiguration),oiBuffer,3)
call WriteSetupAndReadDescriptor
Index = 9 /* data position */
nConfiguration = nConfiguration + 1
dSize = c2d(substr(oiBuffer,Index,1)) - 9
say ' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
say ' ³             bLength ³'db()'³ Descriptor Length                  ³'
say ' ³     bDescriptorType ³'db()'³ Descriptor Type                    ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³        wTotalLength ³'dw()'³ Total Length of data returned      ³'
say ' ³      bNumInterfaces ³'db()'³ Number of Interfaces supported     ³'
say ' ³ bConfigurationValue ³'db()'³ Set Configuration parameter Value  ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³      iConfiguration ³'dis('³ Configuration string index         ³')
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³        bmAttributes ³'db()'³ Configuration characteristics      ³'
say ' ³            MaxPower ³'db()'³ Maximum Power consumption          ³'
say ' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
say '   Device Driver' ddName '- Configuration Descriptor' nConfiguration
say
Index = Index + dSize
nEndpoint = 0
nInterface = -1
scBuffer = substr(oiBuffer,11,2)
sdBuffer = c2d(reverse(scBuffer))
if dSize < 0 then return /* too small */
if sdBuffer < dSize then return /* too small */
oiBuffer = overlay(scBuffer,oiBuffer,7,sdBuffer+2+2,x2c(00))
call WriteSetupAndReadDescriptor
Limit = sdBuffer + 8
do while Index <= Limit
  dType = substr(oiBuffer,Index+1,1)
  select
    when dType = x2c(04) then call OutputInterfaceDescription
    when dType = x2c(05) then call OutputEndpointDescription
    otherwise call OutputUnknownDescription
    end
  end
return

OutputInterfaceDescription:
nInterface = nInterface + 1
dSize = c2d(substr(oiBuffer,Index,1)) - 9
if dSize < 0 then dSize = Limit - Index /* too small */
say ' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
say ' ³             bLength ³'db()'³ Descriptor Length                  ³'
say ' ³     bDescriptorType ³'db()'³ Descriptor Type                    ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³    bInterfaceNumber ³'db()'³ Number of this Interface           ³'
say ' ³   bAlternateSetting ³'db()'³ Set Interface parameter Value      ³'
say ' ³       bNumEndpoints ³'db()'³ Number of Endpoints supported      ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³     bInterfaceClass ³'db()'³ Interface Class code               ³'
say ' ³  bInterfaceSubClass ³'db()'³ Interface Sub Class code           ³'
say ' ³  bInterfaceProtocol ³'db()'³ Interface Protocol code            ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³          iInterface ³'dis('³ Interface string index             ³')
say ' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
say '   Device Driver' ddName '- Interface Descriptor' nConfiguration'.'nInterface
say
Index = Index + dSize
nEndpoint = 0
return

OutputEndpointDescription:
nEndpoint = nEndpoint + 1
dSize = c2d(substr(oiBuffer,Index,1)) - 7
if dSize < 0 then dSize = Limit - Index /* too small */
say ' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
say ' ³             bLength ³'db()'³ Descriptor Length                  ³'
say ' ³     bDescriptorType ³'db()'³ Descriptor Type                    ³'
say ' ÃÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÅÄÄÄÄÄÄÅÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ´'
say ' ³    bEndpointAddress ³'db()'³ Endpoint Address direction/number  ³'
say ' ³        bmAttributes ³'db()'³ Endpoint Attributes transfer type  ³'
say ' ³      wMaxPacketSize ³'dw()'³ Maximum Packet Size when selected  ³'
say ' ³           bInterval ³'db()'³ Polling Interval data transfers    ³'
say ' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
say '   Device Driver' ddName '- Endpoint Descriptor' nConfiguration'.'nInterface'.'nEndpoint
say
Index = Index + dSize
return

OutputUnknownDescription:
dSize = c2d(substr(oiBuffer,Index,1)) - 2
if dSize < 0 then dSize = Limit - Index /* too small */
say ' ÚÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÂÄÄÄÄÄÄÂÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄ¿'
say ' ³             bLength ³'db()'³ Descriptor Length                  ³'
say ' ³     bDescriptorType ³'db()'³ Descriptor Type                    ³'
say ' ÀÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÁÄÄÄÄÄÄÁÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÄÙ'
say '   Device Driver' ddName '- Unknown Descriptor' nConfiguration
say
Index = Index + dSize
return

db:
/* display hexadecimal(byte) */
Byte = '  ' || c2x(substr(oiBuffer,Index,1)) || '  '
if Index <= Limit then Index = Index + 1
return Byte

dis:
parse arg ioString
/* display hexadecimal(byte) */
ixString = substr(oiBuffer,Index,1)
Byte = '  ' || c2x(ixString) || '  '
/* display unicode string(index) */
szUpdate = length(ioString) - 4
String = overlay(substr(ReadUnicodeString(),1,szUpdate),ioString,3)
if Index <= Limit then Index = Index + 1
return Byte || String

dw:
/* display hexadecimal(word) */
Word = ' ' || c2x(reverse(substr(oiBuffer,Index,2))) || ' '
if Index <= Limit then Index = Index + 2
return Word

ReadUnicodeString:
/* obtain string size */
if c2d(ixString) = 0 then return 'No String!'
siBuffer = substr(x2c(80 06 00 03 09 04 01 00),1,9,x2c(00))
siBuffer = overlay(ixString,siBuffer,3)
rc=charout(ddName,siBuffer)
rc=stream(ddName,'description')
if rc \= 'READY:' then return 'String Error!'
szBuffer = substr(siBuffer,9,1)
/* obtain string data */
if c2d(szBuffer) = 0 then return 'No String!'
siBuffer = overlay(szBuffer,siBuffer,7,c2d(szBuffer)+2,x2c(00))
rc=charout(ddName,siBuffer)
rc=stream(ddName,'description')
if rc \= 'READY:' then return 'String Error!'
szString=c2d(substr(siBuffer,9,1))
/* default to english */
usString = '' /* clear */
xPos = 11 /* position */
do while szString > 2
  usString = usString || substr(siBuffer,xPos,1)
  szString = SzString - 2
  xPos = xPos + 2
  end
return usString

WriteSetupAndReadDescriptor:
rc=charout(ddName,oiBuffer)
rc=stream(ddName,'description')
/* check completion code */
if rc \= 'READY:'
then do
  /* obtain and issue error message */
  parse value rc with sState ':' mNumber
  say SysGetMessage(mNumber,,ddName)
  exit
  end
return
