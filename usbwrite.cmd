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
say ' �����������������������������������������������������������������Ŀ'
say ' �             bLength �'db()'� Descriptor Length                  �'
say ' �     bDescriptorType �'db()'� Descriptor Type                    �'
say ' �����������������������������������������������������������������Ĵ'
say ' �              bcdUSB �'dw()'� USB specification release number   �'
say ' �����������������������������������������������������������������Ĵ'
say ' �        bDeviceClass �'db()'� Device Class code                  �'
say ' �     bDeviceSubClass �'db()'� Device Sub Class code              �'
say ' �     bDeviceProtocol �'db()'� Device Protocol code               �'
say ' �����������������������������������������������������������������Ĵ'
say ' �     bMaxPacketSize0 �'db()'� Maximum Packet Size for endpoint 0 �'
say ' �����������������������������������������������������������������Ĵ'
say ' �            idVendor �'dw()'� Vendor identification              �'
say ' �           idProduct �'dw()'� Product identification             �'
say ' �           bcdDevice �'dw()'� Device release number              �'
say ' �����������������������������������������������������������������Ĵ'
say ' �       iManufacturer �'dis('� Manufacturer string index          �')
say ' �            iProduct �'dis('� Product string index               �')
say ' �       iSerialNumber �'dis('� Device Serial Number string index  �')
say ' �����������������������������������������������������������������Ĵ'
say ' �  bNumConfigurations �'db()'� Number of possible Configurations  �'
say ' �������������������������������������������������������������������'
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
say ' �����������������������������������������������������������������Ŀ'
say ' �             bLength �'db()'� Descriptor Length                  �'
say ' �     bDescriptorType �'db()'� Descriptor Type                    �'
say ' �����������������������������������������������������������������Ĵ'
say ' �        wTotalLength �'dw()'� Total Length of data returned      �'
say ' �      bNumInterfaces �'db()'� Number of Interfaces supported     �'
say ' � bConfigurationValue �'db()'� Set Configuration parameter Value  �'
say ' �����������������������������������������������������������������Ĵ'
say ' �      iConfiguration �'dis('� Configuration string index         �')
say ' �����������������������������������������������������������������Ĵ'
say ' �        bmAttributes �'db()'� Configuration characteristics      �'
say ' �            MaxPower �'db()'� Maximum Power consumption          �'
say ' �������������������������������������������������������������������'
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
say ' �����������������������������������������������������������������Ŀ'
say ' �             bLength �'db()'� Descriptor Length                  �'
say ' �     bDescriptorType �'db()'� Descriptor Type                    �'
say ' �����������������������������������������������������������������Ĵ'
say ' �    bInterfaceNumber �'db()'� Number of this Interface           �'
say ' �   bAlternateSetting �'db()'� Set Interface parameter Value      �'
say ' �       bNumEndpoints �'db()'� Number of Endpoints supported      �'
say ' �����������������������������������������������������������������Ĵ'
say ' �     bInterfaceClass �'db()'� Interface Class code               �'
say ' �  bInterfaceSubClass �'db()'� Interface Sub Class code           �'
say ' �  bInterfaceProtocol �'db()'� Interface Protocol code            �'
say ' �����������������������������������������������������������������Ĵ'
say ' �          iInterface �'dis('� Interface string index             �')
say ' �������������������������������������������������������������������'
say '   Device Driver' ddName '- Interface Descriptor' nConfiguration'.'nInterface
say
Index = Index + dSize
nEndpoint = 0
return

OutputEndpointDescription:
nEndpoint = nEndpoint + 1
dSize = c2d(substr(oiBuffer,Index,1)) - 7
if dSize < 0 then dSize = Limit - Index /* too small */
say ' �����������������������������������������������������������������Ŀ'
say ' �             bLength �'db()'� Descriptor Length                  �'
say ' �     bDescriptorType �'db()'� Descriptor Type                    �'
say ' �����������������������������������������������������������������Ĵ'
say ' �    bEndpointAddress �'db()'� Endpoint Address direction/number  �'
say ' �        bmAttributes �'db()'� Endpoint Attributes transfer type  �'
say ' �      wMaxPacketSize �'dw()'� Maximum Packet Size when selected  �'
say ' �           bInterval �'db()'� Polling Interval data transfers    �'
say ' �������������������������������������������������������������������'
say '   Device Driver' ddName '- Endpoint Descriptor' nConfiguration'.'nInterface'.'nEndpoint
say
Index = Index + dSize
return

OutputUnknownDescription:
dSize = c2d(substr(oiBuffer,Index,1)) - 2
if dSize < 0 then dSize = Limit - Index /* too small */
say ' �����������������������������������������������������������������Ŀ'
say ' �             bLength �'db()'� Descriptor Length                  �'
say ' �     bDescriptorType �'db()'� Descriptor Type                    �'
say ' �������������������������������������������������������������������'
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
