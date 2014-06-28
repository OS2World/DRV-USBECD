/* read from the USBECD.SYS device driver */
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
  /* wait */
  '@pause'
  exit
  end

/* get device descriptor */
iiBuffer=charin(ddName,,26)
rc=stream(ddName,'description')
/* check completion code */
if rc \= 'READY:'
then do
  say
  /* obtain and issue error message */
  parse value rc with sState ':' mNumber
  say SysGetMessage(mNumber,,ddName)
  /* wait */
  '@pause'
  exit
  end

/* release the device driver */
rc=stream(ddName,'command','close')

/* identify last attached usb device */
idVendor = c2x(reverse(substr(iiBuffer,17,2)))
idProduct = c2x(reverse(substr(iiBuffer,19,2)))
bcdDevice = c2x(reverse(substr(iiBuffer,21,2)))

/* build device driver usb device parameter */
dParm = '/D:' || idVendor || ':' || idProduct || ':' || bcdDevice

/* build device driver used name parameter */
if ddName = '$' then nParm = ''; else nParm = '/N:' || ddName

say
say 'Device Descriptor:'c2x(substr(iiBuffer,9,18))
say ' idVendor:'idVendor', idProduct:'idProduct', bcdDevice:'bcdDevice'.'
say
say 'To control this particular device through the' ddName 'driver,'
say 'you need the following statement in your config.sys file:'
say
say 'DEVICE=?:\OS2\BOOT\USBECD.SYS' dParm nParm
say
/* wait */
'@pause'
exit
