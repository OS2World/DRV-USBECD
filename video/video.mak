video.exe: video.def video.obj
  link386 /a:16 /map /nod video,video.exe,,os2,video
  markexe mpunsafe video.exe

video.obj: video.asm video.mak
  tasm /la /m /oi video.asm,video.obj
