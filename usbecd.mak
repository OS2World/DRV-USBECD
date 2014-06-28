usbecd.sys: usbecd.def usbecd.mak usbecd.obj
  link /a:16 /map /nod usbecd,usbecd.sys,,os2,usbecd

usbecd.obj: usbecd.asm usbecd.mak
  tasm /la /m /oi usbecd.asm,usbecd.obj
