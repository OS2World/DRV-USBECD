stream.exe: stream.def stream.obj
  link386 /a:16 /map /nod stream,stream.exe,,os2,stream
  markexe mpunsafe stream.exe

stream.obj: stream.asm stream.mak
  tasm /la /m /oi stream.asm,stream.obj
