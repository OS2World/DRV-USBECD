doswrite.exe: doswrite.def doswrite.obj doswrite.mak
# link386 /a:16 /map /nod doswrite,,,os2+llibce,doswrite
  tlink /ap /Toe c02 doswrite,doswrite,,c2 os2,doswrite

doswrite.obj: doswrite.c doswrite.mak
# cl /c /Alfu /G2s /W3 doswrite.c
  bcc /c doswrite.c
