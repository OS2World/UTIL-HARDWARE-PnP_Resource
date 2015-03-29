program pnp_stuffdir;

{$m 32768,0,655350}

{$g+}
{$s-}
{$d+}
{$R+}



{

A diagnostic PnP resource lister for PnP Equipped PC's.

This is freeware - do anything you like with it!


Note:

The unit newdelay may be omitted; it fixes the bug in TP that causes runtime
error 200 at startup on PentiumII-266 and faster CPU's, but does not otherwise
impact the program in any way.


Please visit http://members.hyperlink.net.au/~chart to contact the author,
obtain the latest version, or see what other hardware diagnostic tools I make.


}




uses newdelay, crt;

type
  pnpisatype = record
    rev		: byte;
    CSNs	: byte;
    isaport	: word;
    reserved	: word;
  end;



const
  version	: string[5] = '0.14á';


var
  pnp_f		: text;


  pnpisa	: pnpisatype;

  crd,
  bootype,
  retncode,
  nodesize,
  i,
  j,
  e,
  f,
  g,
  h,
  k,
  x,
  wh,
  bl,
  flen,
  crn,
  where,
  vv,
  xx,
  pt,
  gh,
  minescdsize,
  escdsize,
  ld,
  numnodes,
  logicaldevs	: word;

  nvstoragebase	: longint;

  found,
  exit,
  pnp		: boolean;

  static,
  entrypoint	: pointer;

  tempnode,
  a,b,c,d,
  slot,
  escdslots	: byte;

  try_string	: string[7];
  pnp_string	: string;
  inp		: string[80];


  nodes		: array[0..50] of pointer;	{ biggest it can be }
  escdbuff	: array[0..32767] of byte;	{ biggest it can be }
  pnpres	: array[0..16383] of byte;
  csni		: array[$40..$ff] of byte;





function cvtb(b:byte) : byte;
begin
  if b>9 then cvtb:=b+ord('A')-10 else cvtb:=b+ord('0');
end;

function wrhex(byt:byte) : string;
begin
  wrhex:=chr(cvtb((byt and $f0) shr 4))+chr(cvtb(byt and $0f));
end;

function wrhexw(wor:word): string;
var b: byte;
  hex : string[4];
begin
  asm
    mov dx,wor
    mov cl,4
    shr dh,cl
    and dh,0fh
    mov b,dh
  end;
  hex:=chr(cvtb(b));
  asm
    mov dx,wor
    and dh,0fh
    mov b,dh
  end;
  hex:=hex+chr(cvtb(b));
  asm
    mov dx,wor
    mov cl,4
    shr dl,cl
    and dl,0fh
    mov b,dl
  end;
  hex:=hex+chr(cvtb(b));
  asm
    mov dx,wor
    and dl,0fh
    mov b,dl
  end;
  hex:=hex+chr(cvtb(b));
  wrhexw:=hex;
end;


procedure displayEISAid(a,b,c,d:byte);
begin
  write(chr(a shr 2 + $40));
  write(chr(((a and $3) shl 3) + (b shr 5) + $40));
  write(chr((b and $1f) + $40));
  write(wrhex(c));
  write(wrhex(d));
  write(' - ');

{ new read-from-file routine }
  reset(pnp_f);
  found:=false;
  try_string:=chr(a shr 2 + $40)+chr(((a and $3) shl 3) + (b shr 5) + $40)+chr((b and $1f) + $40)+wrhex(c)+wrhex(d);

  repeat
    readln(pnp_f,pnp_string);
    if copy(pnp_string,1,7)=try_string then
    begin
      found:=true;
      writeln(copy(pnp_string,9,length(pnp_string)-8));
    end;
  until found or eof(pnp_f);
  close(pnp_f);
{ end read-from-file code }

  if not found then writeln('Unrecognised PnP ID!');
end;




procedure ansistr;
var stlen,ii : word;

begin
  stlen:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  write('ID String       : ');

  for ii:=0 to stlen-1 do write(chr(mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3+ii]));

  where:=where+stlen+3;
  writeln;
end;



procedure pnpver;
begin
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  where:=where+3;
  writeln('Version         : ',wrhex(b shr 4),'h; Revision : ',wrhex(b and $0f),'h');
end;

procedure logicaldevid;
begin
  write('LogicalDevID    : ');
  a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+2];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3];
  d:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+4];
  displayEISAid(a,b,c,d);
  where:=where+(mem[seg(nodes[i]^):ofs(nodes[i]^)+where] and 7)+1;
end;

procedure mem16bit;
begin
  write('ISA Memory range: ');
  a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3];
  e:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+4];
  f:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+6];
  g:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+8];
  h:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+$a];
  where:=where+memw[seg(nodes[i]^):ofs(nodes[i]^)+where+1]+3;
  writeln('min ',wrhexw(e),'00h max ',wrhexw(f),'00h step ',wrhexw(g),'h length ',wrhexw(h*256),'h');

  write('ISA Memory flags: ');
  if a and $40=$40 then write('ExpROM, ');
  if a and $20=$20 then write('ShadowOK, ');
  case a and $18 of
    $00 : write('8-bit, ');
    $08 : write('16-bit, ');
    $10 : write('8 or 16-bit, ');
  end;
  if a and 4=4 then write('DecodeHigh, ') else write('DecodeLength, ');
  if a and 2=2 then write('WriteThru Cached, ');
  if a and 1=1 then write('Writeable') else write('Write Protected');
  writeln;
end;

procedure compatabledevid;
begin
  write('CompatableDevID : ');
  a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+2];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3];
  d:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+4];
  displayeisaid(a,b,c,d);
  where:=where+5;
end;

procedure fixedio;
begin
  e:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3]-1;
  where:=where+4;
  writeln('Fixed I/O Range : ',wrhex(hi(e)),wrhex(lo(e)),'h to ',wrhex(hi(e+b)),wrhex(lo(e+b)),'h');
end;

procedure irqresource;
var
  n : byte;
  k : word;
begin
  e:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3]-1;
  where:=where+(a and 3)+1;

  write('IRQ(s)          : ');
  k:=1;
  for n:=0 to 15 do
  begin
    if e and k=k then write(n,' ');
    k:=k shl 1;
  end;
  if a and 3=3 then
  begin
    if b=1 then writeln(' Edge, High') else
    if b=2 then writeln(' Edge, low') else
    if b=4 then writeln(' Level, High') else
    if b=8 then writeln(' Level, low') else
  end;
  writeln;
end;

procedure dmaresource;
var
  n : byte;
  k : word;
begin
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+2];
  where:=where+3;
  write('DMA(s)          : ');
  k:=1;
  for n:=0 to 7 do
  begin
    if b and k=k then write(n,' ');
    k:=k shl 1;
  end;
  case c and $60 of
    $60 : write('- DMA Type F');
    $40 : write('- DMA Type B');
    $20 : write('- DMA Type A');
    $00 : write('- DMA Type 8237');
  end;
  case c and $18 of
    $18 : write(' Word or Byte count');
    $10 : write(' Word Count');
    $08 : write(' Byte Count');
    $00 : write(' Reserved');
  end;
  if c and 4=4 then write(' Bus Master');
  case c and 3 of
    3 : write(' Reserved');
    2 : write(' 16 Bit Transfers');
    1 : write(' 8 or 16 bit Transfers');
    0 : write(' 8 bit transfers');
  end;
  writeln;
end;

procedure startdep;
begin
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  if a and 3=0 then where:=where+1 else where:=where+2;
  write('Alternate config start');
  if a and 3=1 then
  begin
    if b=0 then write(' (Perferred Config)');
    if b=1 then write(' (Other Config)');
    if b=2 then write(' (Sub-Optimal Config)');
  end;
  writeln;
end;

procedure enddep;
begin
  where:=where+1;
  writeln('Alternate config end');
end;

procedure iorange;
begin
  d:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+1]; { size }
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+6]; { align }
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+7]; { length }
  e:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+2]; { minbase }
  f:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+4]; { maxbase }
  where:=where+8;

  if c=1 then
  begin
    write('I/O Port        : ');
    writeln(wrhex(hi(e)),wrhex(lo(e)),'h');
  end else
  begin
    write('I/O Range       : ');
    if e=f then writeln(wrhex(hi(e)),wrhex(lo(e)),'h to ',wrhex(hi(e+(c-1))),wrhex(lo(e+(c-1))),'h')
    else
    begin
      write('Min ',wrhex(hi(e)),wrhex(lo(e)),'h max ');
      writeln(wrhex(hi(f)),wrhex(lo(f)),'h step ',wrhex(b),'h length ',wrhex(c),'h');
    end;
  end;
end;

procedure vendor;
begin
  where:=where+(a and 7)+1;
  writeln('VendorSpecificData');
end;

procedure mem32bit;
begin
  e:=memw[seg(nodes[i]^):ofs(nodes[i]^)+where+1];
  d:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+3];
  write('Memory          : Base ');

  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+7];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+6];
  write(wrhex(b),wrhex(c));
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+5];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+4];
  write(wrhex(b),wrhex(c),'h Length ');
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+11];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+10];
  write(wrhex(b),wrhex(c));
  b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+9];
  c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where+8];
  write(wrhex(b),wrhex(c),'h');
  if d and $40=$40 then write(' ExpROM');
  if d and $20=$20 then write(' ShadowOK');
  case (d and $18) shr 3 of
    0 : write(' 8 bit');
    1 : write(' 16 bit');
    2 : write(' 8+16 bit');
    3 : write(' 32 bit');
  end;
  if d and $10=$10 then write(' ExpROM');
  if d and $8=$8 then write(' ExpROM');
  if d and $2=0 then write(' Cacheable');
  if d and $1=0 then write(' ROM');
  writeln;
  where:=where+e+3;
end;

function IORedirected : boolean ; Assembler;
asm
  push ds
  mov ax,prefixseg
  mov ds,ax
  xor bx,bx
  les bx,[bx + $34]
  mov al,es:[bx]
  mov ah,es:[bx +1]
  pop ds
  cmp al,ah
  mov al,true
  jne @exit

  mov al,false

 @exit:
end;




begin
{ the following hack permits MS-DOS display output redirection to work }
  if ioredirected then
  begin
    writeln('Plug and Play BIOS Data scanner, Version ',version,' By Craig Hart 1997,8');
    writeln;
    assign(output,'');
    rewrite(output);
  end else
  begin
    textmode(co80+font8x8);
    clrscr;
  end;

  bootype:=1;

  if paramcount>0 then
  begin
    inp:=paramstr(1);
    if upcase(inp[1])='N' then bootype:=2;
  end;


  writeln('Plug and Play BIOS Data scanner, Version ',version,' By Craig Hart 1997,8');
  writeln;

  write('Plug ''n Play BIOS : ');
  vv:=0;
  pnp:=false;
  repeat
    if (memw[$F000:vv]=$5024) and (memw[$f000:vv+2]=$506e) then pnp:=true;
    vv:=vv+16;
  until (vv=$fff0) or pnp;

  if not pnp then
  begin
    writeln('no');
    halt(1);
  end;

  vv:=vv-16;
  write('Yes, v');
  writeln(chr(mem[$f000:vv+4] shr 4+ord('0')),'.',chr(mem[$f000:vv+4] and $f+ord('0')));
  entrypoint:=ptr(memw[$f000:vv+$0f],memw[$f000:vv+$0d]);



  asm
    mov ax,0f000h			{ BiosSelector }
    push ax

    mov ax,seg nodesize			{ NodeSize }
    push ax
    mov ax,offset nodesize
    push ax

    mov ax,seg numnodes			{ NumNodes }
    push ax
    mov ax,offset numnodes
    push ax

    mov ax,0				{ Function 0 }
    push ax

    db $ff,$1e; dw entrypoint		{ call far entrypoint }

    add sp,12
    mov retncode,ax

  end;

  if retncode<>0 then writeln('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode)));

  numnodes:=numnodes and $ff;

  writeln('Num System nodes  : ',numnodes);
  writeln('Largest node size : ',nodesize,' bytes');
  write('BIOS entry point  : ',wrhex(hi(seg(entrypoint^))),wrhex(lo(seg(entrypoint^))),':');
  writeln(wrhex(hi(ofs(entrypoint^))),wrhex(lo(ofs(entrypoint^))),'h');


  write('Report for        : ');
  if bootype=1 then writeln('Current Boot') else writeln('Next Boot');
  writeln;

  i:=0;
  tempnode:=i;

  repeat
    getmem(nodes[i],nodesize);
    asm
      mov ax,0f000h
      push ax
      mov ax,bootype				{ 1=now, 2=next boot }
      push ax
      mov ax,i
      mov bx,4
      mul bx
      mov si,ax
      mov ax,word ptr [nodes+si+2]
      push ax
      mov ax,word ptr [nodes+si]
      push ax
      mov ax,seg tempnode
      push ax
      mov ax,offset tempnode
      push ax
      mov ax,1
      push ax
      db $ff,$1e; dw entrypoint		{ call far entrypoint }
      add sp,14
      mov retncode,ax
    end;
    if retncode<>0 then
    begin
      writeln('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode)),'h Reading config!');
      halt(1);
    end;
    inc(i);
  until tempnode=$ff;


  assign(pnp_f,'pnpid.txt');


    for i:=0 to numnodes-1 do
    begin
      writeln('------------------------------------------------------------------------------');
      write('Device          : ',i,', size : ',memw[seg(nodes[i]^):ofs(nodes[i]^)]);
      writeln(', Handle : ',mem[seg(nodes[i]^):ofs(nodes[i]^)+2]);
      a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+3];
      b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+4];
      c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+5];
      d:=mem[seg(nodes[i]^):ofs(nodes[i]^)+6];
      write('PnP Device ID   : ');

      displayEISAid(a,b,c,d);

      a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+7];
      b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+8];
      c:=mem[seg(nodes[i]^):ofs(nodes[i]^)+9];


      write('BaseType        : ',a,' - ');
      case a of
        0 : write('Reserved');
        1 : write('Mass Storage');
        2 : write('Network');
        3 : write('Display');
        4 : write('Multimedia');
        5 : write('Memory');
        6 : write('Bridge Controller');
        7 : write('Communications');
        8 : write('System Peripheral');
        9 : write('Input Device');
        $a : write('Docking Station');
        $b : write('CPU Type');
        $c : write('Serial Bus');
      end;

      writeln;

      write('SubType         : ',b,' - ');

      case a of
        0 : write('Reserved');

        1 : case b of
              0 : write('SCSI Controller');
              1 : write('IDE Controller');
              2 : write('Floppy Controller');
              3 : write('IPI Controller');
              4 : write('RAID Controller');
              $80 : write('Other Storage Controller');
            end;

        2 : case b of
              0 : write('Ethernet');
              1 : write('Token Ring');
              2 : write('FDDI');
              $80 : write('Other Network Controller');
            end;

        3 : case b of
              0 : write('VGA');
              1 : write('XGA');
              $80 : write('Other Display Controller');
            end;

        4 : case b of
              0 : write('Video controller');
              1 : write('Audio controller');
              $80 : write('Other Multimedia device');
            end;

        5 : case b of
              0 : write('RAM Memory');
              1 : write('FLASH Memory');
              $80 : write('Other Memory Controller');
            end;

        6 : case b of
              0 : write('Host Bridge');
              1 : write('ISA Bridge');
              2 : write('EISA Bridge');
              3 : write('MCA Bridge');
              4 : write('PCI Bridge');
              5 : write('PCMCIA Bridge');
              6 : write('NuBus Bridge');
              7 : write('Cardbus Bridge');
              $80 : write('Other Bridge');
            end;

        7 : case b of
              0 : write('RS-232 Serial port');
              1 : write('AT Parallel port');
              $80 : write('Other Communications Controller');
            end;

        8 : case b of
              0 : write('Interrupt controller');
              1 : write('DMA controller');
              2 : write('System timer');
              3 : write('Real Time Clock');
              $80 : write('Other System device');
            end;

        9 : case b of
              0 : write('Keyboard Controller');
              1 : write('Digitizer');
              2 : write('Mouse Controller');
              $80 : write('Other input device');
            end;


        $a : case b of
              0 : write('Docking Station');
              $80 : write('Other Docking Station');
            end;


        $b : case b of
              0 : write('386 CPU');
              1 : write('486 CPU');
              2 : write('Pentium CPU');
              $10 : write('Alpha CPU');
              $40 : write('Coprocessor');
            end;

        $c : case b of
              0 : write('Firewire (IEEE1394) bus');
              1 : write('ACCESS.bus');
              2 : write('SSA bus');
            end;


      end;


      writeln;
      writeln('InterfaceType   : ',c);

      a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+10];
      b:=mem[seg(nodes[i]^):ofs(nodes[i]^)+11];

      write('DevAttribs      : ');

      j:=128;
      repeat
        if b and j=j then write('1') else write('0');
        j:=j shr 1;
      until j=0;

      write(' ');

      j:=128;
      repeat
        if a and j=j then write('1') else write('0');
        j:=j shr 1;
      until j=0;

      writeln;



{ decode variable resource allocations }


      if memw[seg(nodes[i]^):ofs(nodes[i]^)]>11 then
      begin
        where:=12;
        exit:=false;


        repeat
          a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where];

          if a and $80=$80 then
          begin
            case a and $7f of
              1 : mem16bit;
              2 : ansistr;
              6 : mem32bit;
            else
              begin
                writeln('Tripped out on big code ',wrhex(a and $7f));
                inc(where);
              end;
            end;
          end else
          begin
            case a shr 3 of
                1 : pnpver;
                2 : logicaldevid;
                3 : compatabledevid;
                4 : irqresource;
                5 : dmaresource;
                6 : startdep;
                7 : enddep;
                8 : iorange;
                9 : fixedio;
	       $e : vendor;
               $f : begin
	              writeln('End tag');
                      where:=where+2;
                      if mem[seg(nodes[i]^):ofs(nodes[i]^)+10] and $80<>$80 then exit:=true;
                    end;

            else
	      begin
                writeln('Tripped out on small code ',wrhex(a shr 3));
                inc(where);
              end;
            end;


          end;
         if where>=memw[seg(nodes[i]^):ofs(nodes[i]^)] then exit:=true;
        until exit;
      end;
    end;



    writeln;
    writeln;
    writeln;
    writeln('Plug ''n Play ISA Configuration');
    writeln;

    asm
      mov ax,0f000h
      push ax

      mov ax,seg pnpisa
      push ax
      mov ax,offset pnpisa
      push ax

      mov ax,040h
      push ax
      db $ff,$1e; dw entrypoint		{ call far entrypoint }
      add sp,8
      mov retncode,ax
    end;
    if retncode<>0 then writeln('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode))) else
    begin

      writeln('Revision        : ',pnpisa.rev);
      writeln('CSN''s (Cards)   : ',pnpisa.csns);
      write('ISA read port   : ');
      if pnpisa.csns=0 then writeln('Not Valid') else
      begin
        writeln(wrhex(hi(pnpisa.isaport)),wrhex(lo(pnpisa.isaport)),'h');
        writeln;



{ return cards to wait-for-key, don't clear CSN's or reset cards }

        port[$279]:=2;
        port[$a79]:=2;






{ send key sequence }

        asm
          mov dx,0279h
          mov al,0
          out dx,al
          out dx,al

          mov cx,32
          mov al,06ah

        @next:
          mov bh,al
          mov bl,al
          shr bl,1
          and bl,1
          and bh,1
          xor bh,bl
          shl bh,7
          out dx,al
          shr al,1
          or al,bh
          loop @next
        end;





        for crd:=1 to pnpisa.csns do
        begin
          port[$279]:=3; { wake command reg }
          port[$a79]:=crd; {CSN #... }

          for i:=0 to 1023 do
          begin
            port[$279]:=5;
            repeat until port[pnpisa.isaport] and 1=1;
            port[$279]:=4;
            pnpres[i]:=port[pnpisa.isaport];
          end;
          getmem(nodes[50],i);
          for x:=0 to i do mem[seg(nodes[50]^):ofs(nodes[50]^)+x]:=pnpres[x];
          x:=i;


          writeln('------------------------------------------------------------------------------');
          writeln('Possible configuration(s) for Card #',crd);
          writeln;
	  write('PnPISA Device ID: ');

	  displayeisaid(pnpres[0],pnpres[1],pnpres[2],pnpres[3]);
          writeln('Serial#         : ',wrhex(pnpres[7]),wrhex(pnpres[6]),
          wrhex(pnpres[5]),wrhex(pnpres[4]),'h');



          logicaldevs:=$ffff;

{!!!}
          begin
            where:=9;
            exit:=false;
            i:=50;
            repeat
              a:=mem[seg(nodes[i]^):ofs(nodes[i]^)+where];
              if a and $80=$80 then
              begin
                case a and $7f of
	          1 : mem16bit;
                  2 : ansistr;
                  6 : mem32bit;
                else
                  begin
                    writeln('Tripped out on big code ',wrhex(a and $7f));
                    inc(where);
                  end;
                end;
              end else
              begin
                case a shr 3 of
                  1 : pnpver;
                  2 : begin
		        logicaldevid;
                        inc(logicaldevs);
                      end;
                  3 : compatabledevid;
                  4 : irqresource;
                  5 : dmaresource;
                  6 : startdep;
                  7 : enddep;
                  8 : iorange;
                  9 : fixedio;
	         $e : vendor;
                 $f : begin
	                writeln('End tag');
                        where:=where+2;
                        exit:=true;
                      end;
                else
	        begin
                  writeln('Tripped out on small code ',wrhex(a shr 3));
                  inc(where);
                end;
              end;
            end;
            if where>=x then exit:=true;
          until exit;
        end;

{ Safeguard! }
          if logicaldevs=$ffff then logicaldevs:=1;

        writeln;
        writeln('Logical devices : ',logicaldevs+1);




        writeln;
        writeln;
        writeln('Current configuration');
        writeln;


        for ld:=0 to logicaldevs do
        begin
          writeln('--- Logical Device ',ld,' ---');



{ read enabled bit }
          port[$279]:=7;
          port[$a79]:=ld;
          write('Enabled : ');
          port[$279]:=$30;
          if port[pnpisa.isaport] and 1=1 then writeln('Yes') else writeln('No');


{ read resources for this logical device & display }
          for i:=$40 to $ff do
          begin
            port[$279]:=5;
            repeat until port[pnpisa.isaport] and 1=1;
            port[$279]:=i;
            csni[i]:=port[pnpisa.isaport];
          end;


{ IRQ }
	  if csni[$70]>0 then
	  begin
	    write('IRQ #1  : ',csni[$70],', ');
            case csni[$71] of
              00 : writeln('Edge triggered, H->L');
              01 : writeln('Active low level triggered');
              02 : writeln('Edge triggered, L->H');
              03 : writeln('Active high level triggered');
            end;
          end;

    	  if csni[$72]>0 then
	  begin
	    write('IRQ #2  : ',csni[$72],', ');
            case csni[$73] of
              00 : writeln('Edge triggered, H->L');
              01 : writeln('Active low level triggered');
              02 : writeln('Edge triggered, L->H');
              03 : writeln('Active high level triggered');
            end;
          end;

{ DMA }
	  if csni[$74]<>4 then writeln('DMA #1  : ',csni[$74]);
	  if csni[$75]<>4 then writeln('DMA #2  : ',csni[$75]);
{ i/o }
          for i:=0 to 7 do
          begin
            if (csni[$60+(i shl 1)]<>0) or (csni[$61+(i shl 1)]<>0) then
              writeln('I/O #',i,'  : ',wrhex(csni[$60+(i shl 1)]),wrhex(csni[$61+(i shl 1)]),'h');
          end;

{ isa mem }
          for i:=0 to 3 do
          begin
            if (csni[$40+(i*8)]<>00) or (csni[$41+(i*8)]<>00) or (csni[$42+(i*8)]<>00)
	      or (csni[$43+(i*8)]<>00) or (csni[$44+(i*8)]<>00) then
            begin
              write('MEM #',i,'  : ',wrhex(csni[$40+(i*8)]),wrhex(csni[$41+(i*8)]),'00h ');
              if csni[$42+(i*8)] and 1=1 then
	      begin
  	        write('to ');
                write(wrhex(csni[$43+(i*8)]),wrhex(csni[$44+(i*8)]),'00h');
              end else
	      begin
	        write('length ');
                write(wrhex(csni[$43+(i*8)]),wrhex(csni[$44+(i*8)]),'h');
              end;
              if csni[$42+(i*8)] and 2=2 then write(' 16-bit') else write(' 8-bit');
              writeln;
            end;
          end;
{ Need to implement EISA mem! }

          writeln;
        end;
      end;
    end;
  end;



    writeln;
    writeln;
    writeln;
    writeln('Static Resource Configuration');
    writeln;
    getmem(static,8192);

    asm
      mov ax,0f000h
      push ax

      mov ax,word ptr static+2
      push ax
      mov ax,word ptr static
      push ax

      mov ax,0ah
      push ax
      db $ff,$1e; dw entrypoint		{ call far entrypoint }
      add sp,8
      mov retncode,ax
    end;
    if retncode<>0 then
    begin
      write('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode)),'h');
      if retncode=$8d then writeln(' - Refer to ESCD information instead!') else writeln;
    end;

{ sorry, no further work on Static Resources yet..! ..never met a pc that uses it!!}


    writeln;
    writeln;
    writeln;
    writeln('ESCD Information');
    writeln;

    asm
      mov ax,0f000h
      push ax

      mov ax,seg nvstoragebase
      push ax
      mov ax,offset nvstoragebase
      push ax

      mov ax,seg escdsize
      push ax
      mov ax,offset escdsize
      push ax

      mov ax,seg minescdsize
      push ax
      mov ax,offset minescdsize
      push ax

      mov ax,041h
      push ax
      db $ff,$1e; dw entrypoint		{ call far entrypoint }
      add sp,14
      mov retncode,ax
    end;
    if retncode<>0 then writeln('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode)));


    writeln('ESCD Size      : ',escdsize);
    writeln('Min ESCD Size  : ',minescdsize);
    write('NVStorBase     : ',wrhex(nvstoragebase shr 24));
    write(wrhex((nvstoragebase shr 16) and $ff));
    write(wrhex((nvstoragebase shr 8) and $ff));
    writeln(wrhex(nvstoragebase and $ff),'h');

    writeln;

    if (escdsize>0) and (escdsize<32769) then
    begin
      asm
        mov ax,0f000h
        push ax

        mov bx,word ptr nvstoragebase+2
        mov ax,word ptr nvstoragebase

        shr ax,4
        shl bx,12
        add ax,bx
        push ax


        mov ax,seg escdbuff
        push ax
        mov ax,offset escdbuff
        push ax

        mov ax,042h
        push ax
        db $ff,$1e; dw entrypoint		{ call far entrypoint }
        add sp,10
        mov retncode,ax
      end;
      if retncode<>0 then writeln('Returned error code : ',wrhex(hi(retncode)),wrhex(lo(retncode)));



      writeln('Signature      : ',chr(escdbuff[2]),chr(escdbuff[3]),chr(escdbuff[4]),chr(escdbuff[5]));



      writeln('Version        : ',wrhex(escdbuff[7]),'.',wrhex(escdbuff[6]));
      writeln('Board Count    : ',escdbuff[8]);
      writeln('Size           : ',wrhex(escdbuff[1]),wrhex(escdbuff[0]),'h');
      writeln;


{ try to decode ESCD }
      escdslots:=0;

      where:=12;
      repeat
        slot:=escdbuff[where+2];

        inc(escdslots);
        if slot<>255 then
        begin
          writeln('------------------------------------------------------------------------------');
          write('Slot #',wrhex(slot),'h');

          case slot of
            0 : write(' System Board Resources');
            1..15 : write(' EISA, PnPISA or ISA Adapter');
            16..64 : write(' Virtual Adapter');
          end;


          e:=memw[seg(escdbuff):ofs(escdbuff)+where];
          writeln(' Size : ',wrhex(hi(e)),wrhex(lo(e)),'h');



          writeln;
          writeln('(Hex-dump of ESCD data for this device follows)');
          crn:=24;
          for wh:=where to (where+e)-1 do
          begin
            write(wrhex(escdbuff[wh]),' ');
            inc(crn);
            if ((crn+1) mod 25)=0 then writeln;
          end;
          writeln;
          writeln;


{ decode basic device info }

          write('EISA ID   : ');

          if (escdbuff[where+4]=0) and (escdbuff[where+5]=0) and (escdbuff[where+6]=0)
	    and (escdbuff[where+7]=0) then writeln('Not Defined')
	    else displayeisaid(escdbuff[where+4],escdbuff[where+5],escdbuff[where+6],escdbuff[where+7]);
          writeln('Slot Info : ',wrhex(escdbuff[where+8]),'h, ',wrhex(escdbuff[where+9]),'h');
          writeln('CFG Revn  : ',escdbuff[where+10],'.',escdbuff[where+11]);
          writeln;

          bl:=0;
          xx:=where+$0c;

          repeat
            flen:=escdbuff[xx+1] shl 8 + escdbuff[xx];

            if flen>0 then
            begin
              writeln;
              writeln('-- Function ',bl,' -----------------------');
              writeln;


{ Only needed for debugging ...}
               writeln('Length  : ',wrhexw(flen),'h');
               writeln('Fn info : ',wrhex(escdbuff[xx+4]),'h');



{ Decode functions }

              pt:=xx+5;

              if escdbuff[xx+4] and $80=$80 then
              begin
                { disabled record }
                writeln('(This entry is disabled)');
              end;
              if escdbuff[xx+4] and $40=$40 then
              begin
                { freeform record }
                writeln('(This entry is really freeform data)');
              end;

              if escdbuff[xx+4] and $1=$1 then
              begin
                { ?? record }
                writeln('(Type 01h - Not implemented)');
                inc(pt,80);
              end;

              if escdbuff[xx+4] and $20=$20 then
              begin
                { ?? record }
                writeln('(Type 20h - Not implemented)');
                inc(pt,3);
              end;

              if escdbuff[xx+4] and 2=2 then
              begin
                { Memory record }
                repeat
                  gh:=escdbuff[pt+6] shl 8 + escdbuff[pt+5];
                  write('MEM     : ',wrhex(escdbuff[pt+4]),wrhex(escdbuff[pt+3]),wrhex(escdbuff[pt+2]),'0h');
                  write(' Length ',gh,'kb, ');

                  if escdbuff[pt] and 1=1 then write('RAM, ') else write('ROM, ');
                  if escdbuff[pt] and 2=2 then write('Cached, ') else write('Not Cached, ');
                  if escdbuff[pt] and $20=$20 then write('Shared, ') else write('Not Shared, ');

{                  case escdbuff[pt] and $18 of
                    $00 : write('System ');
                    $08 : write('Expanded ');
                    $10 : write('Virtual ');
                    $18 : write('Other ');
                  end;
                  write('Memory, ');
}

                  case escdbuff[pt+1] and 3 of
                    00 : write('8-bit');
                    01 : write('16-bit');
                    02 : write('32-bit');
                    03 : write('??-bit');
                  end;

                  writeln;



                  inc(pt,7);
                until escdbuff[pt-7] and $80=$0;
              end;

              if escdbuff[xx+4] and 4=4 then
              begin
                { IRQ record }
                repeat
                  write('IRQ     : ',(escdbuff[pt] and $f),', ');

                  if escdbuff[pt] and $20=$20 then write('Level ') else write('Edge ');
                  write('Triggered, ');

                  if escdbuff[pt] and $40=0 then write('Not ');
                  writeln('Shared');

                  inc(pt,2);
                until escdbuff[pt-2] and $80=$0;
              end;

              if escdbuff[xx+4] and 8=8 then
              begin
                { DMA record }
                repeat
                  write('DMA     : ',(escdbuff[pt] and $f),', ');

                  if escdbuff[pt] and $40=0 then write('Not ');
                  write('Shared, ');

                  case escdbuff[pt+1] and $30 of
                    $00 : write('ISA');
                    $10 : write('Type A');
                    $20 : write('Type B');
                    $30 : write('Burst');
                  end;
                  write(' Timing, ');

                  case escdbuff[pt+1] and $c0 of
                    $00 : writeln('8-bit');
                    $40 : writeln('16-bit');
                    $80 : writeln('32-bit');
                    $c0 : writeln('Reserved');
                  end;

                  inc(pt,2);
                until escdbuff[pt-2] and $80=$0;
              end;

              if escdbuff[xx+4] and $10=$10 then
              begin
                { I/O record }
                repeat
                  gh:=escdbuff[pt+2] shl 8 + escdbuff[pt+1];
                  write('I/O     : ',wrhexw(gh),'h to ',wrhexw(gh+(escdbuff[pt] and $7f)),'h, ');

                  if escdbuff[pt] and $40=0 then write('Not ');
                  writeln('Shared');


                  inc(pt,3);
                until escdbuff[pt-3] and $80=$0;
              end;


            end else
	    begin
              writeln;
	      writeln('-- Last Function -- Checksum ',wrhex(escdbuff[xx+flen+2]),wrhex(escdbuff[xx+flen+3]),'h --');
              writeln;
            end;
            inc(bl);
            xx:=xx+flen+2;
          until flen=0;


{ Scan for any (optional) ESCD extras }

          for xx:=where to where+e do
          begin
            if (escdbuff[xx]=ord('A')) and
               (escdbuff[xx+1]=ord('C')) and
               (escdbuff[xx+2]=ord('F')) and
               (escdbuff[xx+3]=ord('G')) then
            begin

              writeln;
              writeln('-- Freeform board header found for this device --');
              writeln;
              write('    Signature  : ');
              writeln(chr(escdbuff[xx]),chr(escdbuff[xx+1]),chr(escdbuff[xx+2]),chr(escdbuff[xx+3]));
              writeln('    Version    : ',escdbuff[xx+5],'.',escdbuff[xx+4]);
              write('    DeviceType : ');


              case escdbuff[xx+6] of
                $01 : writeln('Non-PnP ISA');
                $02 : writeln('EISA');
                $04 : begin
		        writeln('PCI');
                        writeln('    PCI BUS#   : ',wrhex(escdbuff[xx+$10]),'h');
                        writeln('    PCI Func#  : ',wrhex(escdbuff[xx+$10+1]),'h');
                        writeln('    PCI Vendor : ',wrhex(escdbuff[xx+$10+5]),wrhex(escdbuff[xx+$10+4]),'h');
                        writeln('    PCI Device : ',wrhex(escdbuff[xx+$10+3]),wrhex(escdbuff[xx+$10+2]),'h');
                      end;
                $08 : writeln('PCMCIA');
                $10 : begin
		        writeln('PnPISA');
              		write('    DeviceID   : ');
                        displayeisaid(escdbuff[xx+$10],escdbuff[xx+$11],escdbuff[xx+$12],escdbuff[xx+$13]);
                        writeln('    Serial#    : ',wrhex(escdbuff[xx+$17]),wrhex(escdbuff[xx+$16]),
  			  wrhex(escdbuff[xx+$15]),wrhex(escdbuff[xx+$14]),'h');
                        end;
                $20 : writeln('MCA');
                $40 : begin
		        writeln('PCI Bridge');
                        writeln('    PCI BUS#   : ',wrhex(escdbuff[xx+$10]),'h');
                        writeln('    PCI Func#  : ',wrhex(escdbuff[xx+$10+1]),'h');
                        writeln('    PCI Vendor : ',wrhex(escdbuff[xx+$10+5]),wrhex(escdbuff[xx+$10+4]),'h');
                        writeln('    PCI Device : ',wrhex(escdbuff[xx+$10+3]),wrhex(escdbuff[xx+$10+2]),'h');
                      end;
                else writeln('Unknown (',wrhex(escdbuff[xx+6]),'h)');
              end;
              writeln;
              writeln('-- Freeform board header ends -------------------');
              writeln;
            end;
          end;
          where:=where+e;
          writeln('------------------------------------------------------------------------------');
          writeln;
          writeln;
        end;
      until (where>=escdsize) or (slot=255) or (escdslots=escdbuff[8]);
    end else
    begin
      if escdsize=0 then writeln('ESCD size 0 bytes !?!?!') else
      writeln('ESCD size >32k, cannot read!!!');
    end;
  freemem(static,8192);
  for i:=0 to numnodes-1 do
  begin
    freemem(nodes[i],nodesize);
  end;
end.
