// dosread.c - Test USBECD.SYS device driver

#include <stdio.h>
#include <process.h>
#include <string.h>

#define INCL_DOS
#include <os2.h>

BYTE Buffer[32] = {0xEE,0xEE,0xEE,0xEE,0xEE,0xEE,0xEE,0xEE}; // Eye Catcher

CHAR pszName[15] = "\\DEV\\$\0";  // Refers to DEVICE=USBECD.SYS /N:$

void main()
{
//USHORT cbTransfer, hDevice, index, ulAction, ulrc; // IBM 16 bit
  ULONG cbTransfer, hDevice, index, ulAction, ulrc; // Borland 32 bit

//ulrc=DosOpen(pszName,&hDevice,&ulAction,0L,0,1,18,0L); // IBM 16 bit
  ulrc=DosOpen(pszName,&hDevice,&ulAction,0,0,1,18,0); // Borland 32 bit
  printf("\nDosOpen ulrc=%hu ulAction=%hu",ulrc,ulAction);

  if (!ulrc)
  {
    printf("\nSetup Packet:");
    for (index=0;index<8;index++) printf(" %02X",Buffer[index]);
    ulrc=DosRead(hDevice,Buffer,32,&cbTransfer);
    printf("\nDosRead ulrc=%hu cbTransfer=%hu",ulrc,cbTransfer);
    printf("\nSetup Packet:");
    for (index=0;index<8;index++) printf(" %02X",Buffer[index]);
    printf("\nData Packet:");
    for (index=8;index<26;index++) printf(" %02X",Buffer[index]);

    ulrc=DosClose(hDevice);
    printf("\nDosClose ulrc=%hu",ulrc);
  }

  // skip line and exit
  printf("\n\n"); exit(0);
}
