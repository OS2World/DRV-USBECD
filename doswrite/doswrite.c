// doswrite.c - Test USBECD.SYS device driver

#include <stdio.h>
#include <process.h>
#include <string.h>

#define INCL_DOS
#include <os2.h>

// control transfers: setup packets (to be sent to device)
//BYTE Buffer[32] = {0x80,0,0,0,0,0,2,0}; // GetStatus: Device
//BYTE Buffer[32] = {0x81,0,0,0,0,0,2,0}; // GetStatus: Interface
//BYTE Buffer[32] = {0x82,0,0,0,0,0,2,0}; // GetStatus: Endpoint
//BYTE Buffer[32] = {0x80,6,0,1,0,0,18,0}; // GetDescriptor: Device
//BYTE Buffer[32] = {0x80,6,0,2,0,0,24,0}; // GetDescriptor: Configuration
//BYTE Buffer[32] = {0x80,6,0,3,0,0,24,0}; // GetDescriptor: StringLanguages
//BYTE Buffer[32] = {0x80,6,1,3,0,0,24,0}; // GetDescriptor: 1st StringIndex
//BYTE Buffer[32] = {0x80,6,2,3,0,0,24,0}; // GetDescriptor: 2nd StringIndex
//BYTE Buffer[32] = {0x80,6,3,3,0,0,24,0}; // GetDescriptor: 3rd StringIndex
//BYTE Buffer[32] = {0x80,6,4,3,0,0,24,0}; // GetDescriptor: 4th StringIndex
//BYTE Buffer[32] = {0x80,6,5,3,0,0,24,0}; // GetDescriptor: 5th StringIndex
//BYTE Buffer[32] = {0x80,8,0,0,0,0,1,0}; // GetConfiguration: device
//BYTE Buffer[32] = {0x00,9,0,0,0,0,0,0}; // SetConfiguration: AddressState
//BYTE Buffer[32] = {0x00,9,1,0,0,0,0,0}; // SetConfiguration: Configured

// data transfers: parameter packets (not sent to device)
//BYTE Buffer[32] = {0xEC,0,0,0,0x81,2,24,0}; //GetBulkData: Endpoint:81
//BYTE Buffer[32] = {0xEC,0,0,0,0x81,3,24,0}; //GetInterruptData: Endpoint:81
//BYTE Buffer[32] = {0xEC,0,0,0,0x01,2,24,0}; //PutBulkData: Endpoint:01
//BYTE Buffer[32] = {0xEC,0,0,0,0x01,3,24,0}; //PutInterruptData: Endpoint:01

BYTE Buffer[32] = {0x80,6,0,1,0,0,18,0}; // GetDescriptor: Device

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
    ulrc=DosWrite(hDevice,Buffer,32,&cbTransfer);
    printf("\nDosWrite ulrc=%hu cbTransfer=%hu",ulrc,cbTransfer);
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
