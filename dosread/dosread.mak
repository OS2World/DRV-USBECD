dosread.exe: dosread.def dosread.obj dosread.mak
# link386 /a:16 /map /nod dosread,,,os2+llibce,dosread
  tlink /ap /Toe c02 dosread,dosread,,c2 os2,dosread

dosread.obj: dosread.c dosread.mak
# cl /c /Alfu /G2s /W3 dosread.c
  bcc /c dosread.c
