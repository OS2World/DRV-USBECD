hybrid.exe: hybrid.def hybrid.obj
  link386 /a:16 /map /nod hybrid,hybrid.exe,,os2,hybrid
  markexe mpunsafe hybrid.exe

hybrid.obj: hybrid.asm hybrid.mak
  tasm /la /m /oi hybrid.asm,hybrid.obj
