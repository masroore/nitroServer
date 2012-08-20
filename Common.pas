////////////////////////////////////////////////////////////////////////////////
//
// nitroServer
// The FASTest and most SCALABLE webserver written in Delphi
//
// Author: Dr. Masroor Ehsan Choudhury
// <nitroserver@gmail.com>
// http://nitrohttpd.blogspot.com/
//
// Copyright (C) 2007 Dr. Masroor Ehsan Choudhury
// All rights reserved.
//
// PERMISSION TO USE, COPY, MODIFY, AND DISTRIBUTE THIS SOFTWARE AND ITS
// DOCUMENTATION FOR NON-COMMERCIAL PURPOSE IS HEREBY GRANTED, PROVIDED
// THAT THE ABOVE COPYRIGHT NOTICE AND THIS PARAGRAPH AND THE FOLLOWING
// PARAGRAPHS APPEAR IN ALL COPIES.
//
// IN NO EVENT SHALL THE AUTHOR BE LIABLE TO ANY PARTY FOR DIRECT, INDIRECT,
// SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, INCLUDING LOST PROFITS,
// ARISING OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF
// THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// THE AUTHOR SPECIFICALLY DISCLAIMS ANY WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
// PARTICULAR PURPOSE. THE SOFTWARE PROVIDED HEREUNDER IS ON AN "AS IS" BASIS,
// AND THE AUTHOR HAS NO OBLIGATIONS TO PROVIDE MAINTENANCE, SUPPORT, UPDATES,
// ENHANCEMENTS, OR MODIFICATIONS.
//
// THE ORIGIN OF THIS SOFTWARE MUST NOT BE MISREPRESENTED, YOU MUST NOT CLAIM
// THAT YOU WROTE THE ORIGINAL SOFTWARE.
//
// IF YOU USE THIS SOFTWARE IN A PRODUCT, AN ACKNOWLEDGMENT IN THE PRODUCT
// DOCUMENTATION IS REQUIRED. IF YOUR PROGRAM HAS AN "ABOUT BOX" THE
// FOLLOWING CREDIT SHOULD BE DISPLAYED IN IT:
//   "nitroServer (C) Dr. Masroor Ehsan Choudhury <nitroserver@gmail.com>"
//
// ALTERED SOURCE VERSIONS MUST BE PLAINLY MARKED AS SUCH, AND MUST NOT BE
// MISREPRESENTED AS BEING THE ORIGINAL SOFTWARE.
//
// $Version:0.6.2$ $Revision:1.5.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:04$
//
////////////////////////////////////////////////////////////////////////////////

unit Common;

interface

{$I NITROHTTPD.INC}

uses
  Windows, WinSock, WinSock2, Buffer, VHosts;

const
  MAX_RECV_BUF_SIZE     = 2048;
  MAX_SEND_BUF_SIZE     = 4096;
  SHUTDOWN_FLAG         = $FFFFFFFF;
  SOCKADDRIN_SIZE       = SizeOf(sockaddr_in);
  ACCEPT_BUF_SIZE       = MAX_RECV_BUF_SIZE - (2 * (SOCKADDRIN_SIZE + 16));

  SERVER_SOFTWARE = 'Agni HTTPd';
  SERVER_VERSION  = '0.6.1 (Win32)/' + {$IFDEF BORLAND} 'Delphi' {$ELSE} 'FPC' {$ENDIF};
  SERVER_SIGNATURE = SERVER_SOFTWARE + '/' + SERVER_VERSION;
  SERVER_PORT     = 5000;

  KEEPALIVE_MAX   = 8;
  MIN_REQ_LEN     = 5;

  WATCHDOG_INTERVAL = 30;

  EOL_CR          = #13;
  EOL_LF          = #10;

  EOL_MARKER      = #13#10;
  EOH_MARKER      = #13#10#13#10;
  EOH_MARKER_LEN  = 4;

  HDR_END_CRLF    = EOH_MARKER;
  HDR_END_LF      = #10#10;

  SIZE_KB         = 1024;
  SIZE_MB         = 1024 * 1024;

const
  READ_BUFFER_SIZE       =   32 * 1024;
  CACHEFILE_THRESHOLD    =   64 * 1024;
  TRANSMITFILE_THRESHOLD =  128 * 1024;
  GZIP_MINSIZE           =   16 * 1024;
  GZIP_MAXSIZE           = 1024 * 1024;   	

type
  THTTPMethod     = (hmGet, hmHead, hmPost,
                     hmOptions, hmPut, hmDelete,  // Not supported
                     hmTrace, hmConnect );        // Not supported
  THTTPVersion    = (hv0_9, hv1_0, hv1_1);
  THTTPRangeType  = (rtNone, rtLWMOnly, rtBoth);
  THTTPScriptType = (stNone, stPHP, stCGI, stISAPI, stFastCGI);

  PHTTPRequest    = ^THTTPRequest;
  THTTPRequest = record
    Method:  THTTPMethod;
    Version: THTTPVersion;
    URI:     PAnsiChar;
    Query:   PAnsiChar;
    Accept:  PAnsiChar;
    AcceptCharset: PAnsiChar;
    AcceptEncoding: PAnsiChar;
    AcceptLanguage: PAnsiChar;
    Authorization: PAnsiChar;
    Connection: PAnsiChar;
    PostData: PAnsiChar;
    ContentType: PAnsiChar;
    ContentLen: Integer;
    PostLen: Cardinal;
    Cookie,
    Cookie2:  PAnsiChar;
    Host:    PAnsiChar;
    TE:      PAnsiChar;
    IfModSince: TDateTime;
    BytesSent: Integer;
    RangeLWM,
    RangeHWM: Integer;
    RangeType: THTTPRangeType;
    Referrer: PAnsiChar;
    UserAgent: PAnsiChar;
    StatusCode: Cardinal;
    AuthUser,
    AuthPass,
    AuthType: AnsiString;
    ClientAddr: AnsiString;
    ClientPort: Word;
    OrigURL: AnsiString;
    OrigHdr: AnsiString;
    Filename: AnsiString;
    Context: Pointer;
    HeaderRcvd: Boolean;
    KeepAlive: Boolean;
    KACount: Cardinal;
    AcceptGZip: Boolean;
    ScriptType: THTTPScriptType;
    VirtualHost: TVirtualHost;
  end;

type
  TIOState      = (stClosed, stAccepting, stReading, stWriting, stSendingFile, stDisconnect);
  TSendCacheType = (scNone, scDataCache, scGZipCache);

  PClientContext = ^TClientContext;
  TClientContext = record
    Ovl:      TOverlapped;
    hIOCP:    THandle;
    State:    TIOState;
    ListenSock: TSocket;
    Sock:     TSocket;
    Bytes:    Cardinal;
    saLocal,
    saPeer:   TSockAddrIn;
    ReuseCount: Integer;
    SendFile,
    DisconnectAfterSend: Boolean;
    FileHandle: Integer;
    FileSize: Cardinal;
    RecvBuf,
    SendBuf:  PSmartBuffer;
    HTTPReq:  PHTTPRequest;
    wbRecv:   TWSABuf;
{$IFDEF TRANSMIT_PACKETS}
    tpSend:   array [0..1] of TTransmitPacketsElement;
{$ELSE}
    wbSend: array[0..1] of TWSABuf;
{$ENDIF}
    TxBuf:    PTransmitFileBuffers;
    SendCacheType: TSendCacheType;
    DataCache: Pointer;
{$IFDEF TRACK_SOCKET_SESSION}
    xSession: Integer;
{$ENDIF}
  end;

type
  THTTPMethodRec = record
    Meth: THTTPMethod;
    Str:  PAnsiChar;
  end;

  THTTPVersionRec = record
    Ver: THTTPVersion;
    Str: PAnsiChar;
  end;

const
  METHOD_TABLE: array [hmGet..hmPost] of THTTPMethodRec =
    (
    (Meth: hmGet; Str: 'GET'),
    (Meth: hmHead; Str: 'HEAD'),
    (Meth: hmPost; Str: 'POST')
    );
  VERSION_TABLE: array [hv0_9..hv1_1] of THTTPVersionRec =
    (
    (Ver: hv0_9; Str: 'HTTP/0.9'),
    (Ver: hv1_0; Str: 'HTTP/1.0'),
    (Ver: hv1_1; Str: 'HTTP/1.1')
    );
  CONN_TABLE: array [False..True] of AnsiString =
    ('Close', 'Keep-Alive');


function CalcCRC32(Buf: Pointer; Len: Cardinal): LongWord;
procedure CalcCRC16(var CRC: word; Msg: pointer; Len: longint);
function CRC16String(const S: AnsiString): Word;
procedure DecodeURL(var URI: PAnsiChar);
function EncodeURL(FName: AnsiString): AnsiString;
function HTTPEncode(const AStr: AnsiString): AnsiString;
procedure PurgeURI(var URI: PAnsiChar);
procedure ConsolidateSlashes(var P: PAnsiChar);
function StrPBrk(const Str, Chr: PAnsiChar): PAnsiChar;
procedure StrReplaceChar(var Str: AnsiString; const cFrom, cTo: AnsiChar);
function atoi(const s: PAnsiChar): Integer;
function StorageSize(const Bytes: Int64): AnsiString;
function KBSizeToString(const S : Integer) : Ansistring;
function ScanULong(const src: PAnsiChar; var dest: Cardinal): Integer;
function PathDOSToUnix(const S: AnsiString): AnsiString;
function PathAddSlash(const Path: AnsiString): AnsiString;
function FastCharPos(const Source: AnsiString; X:AnsiChar; Start:Integer = 1): Integer;
procedure Base64Initialise;
function Base64DecodeFast(const Src: PAnsiChar; Dst: PAnsiChar): Boolean;

implementation

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  SysUtils;

const
  CSPACE = Ord(' ');
  CNUM0  = Ord('0');
  CNUM9  = Ord('9');

  C_UP_A = Ord('A');
  C_UP_Z = Ord('Z');
  C_LO_A = Ord('a');
  C_LO_F = Ord('f');
  C_LO_Z = Ord('z');

const
  HEX_DIGITS = ['0'..'9', 'A'..'F', 'a'..'f'];

const
  HEX_TABLE: String[16] = '0123456789ABCDEF';

const
  CRC16_TABLE: array[0..$FF] of Word =
   ($00000, $01021, $02042, $03063, $04084, $050A5, $060C6, $070E7,
    $08108, $09129, $0A14A, $0B16B, $0C18C, $0D1AD, $0E1CE, $0F1EF,
    $01231, $00210, $03273, $02252, $052B5, $04294, $072F7, $062D6,
    $09339, $08318, $0B37B, $0A35A, $0D3BD, $0C39C, $0F3FF, $0E3DE,
    $02462, $03443, $00420, $01401, $064E6, $074C7, $044A4, $05485,
    $0A56A, $0B54B, $08528, $09509, $0E5EE, $0F5CF, $0C5AC, $0D58D,
    $03653, $02672, $01611, $00630, $076D7, $066F6, $05695, $046B4,
    $0B75B, $0A77A, $09719, $08738, $0F7DF, $0E7FE, $0D79D, $0C7BC,
    $048C4, $058E5, $06886, $078A7, $00840, $01861, $02802, $03823,
    $0C9CC, $0D9ED, $0E98E, $0F9AF, $08948, $09969, $0A90A, $0B92B,
    $05AF5, $04AD4, $07AB7, $06A96, $01A71, $00A50, $03A33, $02A12,
    $0DBFD, $0CBDC, $0FBBF, $0EB9E, $09B79, $08B58, $0BB3B, $0AB1A,
    $06CA6, $07C87, $04CE4, $05CC5, $02C22, $03C03, $00C60, $01C41,
    $0EDAE, $0FD8F, $0CDEC, $0DDCD, $0AD2A, $0BD0B, $08D68, $09D49,
    $07E97, $06EB6, $05ED5, $04EF4, $03E13, $02E32, $01E51, $00E70,
    $0FF9F, $0EFBE, $0DFDD, $0CFFC, $0BF1B, $0AF3A, $09F59, $08F78,
    $09188, $081A9, $0B1CA, $0A1EB, $0D10C, $0C12D, $0F14E, $0E16F,
    $01080, $000A1, $030C2, $020E3, $05004, $04025, $07046, $06067,
    $083B9, $09398, $0A3FB, $0B3DA, $0C33D, $0D31C, $0E37F, $0F35E,
    $002B1, $01290, $022F3, $032D2, $04235, $05214, $06277, $07256,
    $0B5EA, $0A5CB, $095A8, $08589, $0F56E, $0E54F, $0D52C, $0C50D,
    $034E2, $024C3, $014A0, $00481, $07466, $06447, $05424, $04405,
    $0A7DB, $0B7FA, $08799, $097B8, $0E75F, $0F77E, $0C71D, $0D73C,
    $026D3, $036F2, $00691, $016B0, $06657, $07676, $04615, $05634,
    $0D94C, $0C96D, $0F90E, $0E92F, $099C8, $089E9, $0B98A, $0A9AB,
    $05844, $04865, $07806, $06827, $018C0, $008E1, $03882, $028A3,
    $0CB7D, $0DB5C, $0EB3F, $0FB1E, $08BF9, $09BD8, $0ABBB, $0BB9A,
    $04A75, $05A54, $06A37, $07A16, $00AF1, $01AD0, $02AB3, $03A92,
    $0FD2E, $0ED0F, $0DD6C, $0CD4D, $0BDAA, $0AD8B, $09DE8, $08DC9,
    $07C26, $06C07, $05C64, $04C45, $03CA2, $02C83, $01CE0, $00CC1,
    $0EF1F, $0FF3E, $0CF5D, $0DF7C, $0AF9B, $0BFBA, $08FD9, $09FF8,
    $06E17, $07E36, $04E55, $05E74, $02E93, $03EB2, $00ED1, $01EF0);

var
  BASE64_TABLE: array [0..255] of Byte;

const
  CRC32_Table: array[0..255] of LongWord =
    ($00000000,$77073096,$EE0E612C,$990951BA,$076DC419,$706AF48F,$E963A535,$9E6495A3,
     $0EDB8832,$79DCB8A4,$E0D5E91E,$97D2D988,$09B64C2B,$7EB17CBD,$E7B82D07,$90BF1D91,
     $1DB71064,$6AB020F2,$F3B97148,$84BE41DE,$1ADAD47D,$6DDDE4EB,$F4D4B551,$83D385C7,
     $136C9856,$646BA8C0,$FD62F97A,$8A65C9EC,$14015C4F,$63066CD9,$FA0F3D63,$8D080DF5,
     $3B6E20C8,$4C69105E,$D56041E4,$A2677172,$3C03E4D1,$4B04D447,$D20D85FD,$A50AB56B,
     $35B5A8FA,$42B2986C,$DBBBC9D6,$ACBCF940,$32D86CE3,$45DF5C75,$DCD60DCF,$ABD13D59,
     $26D930AC,$51DE003A,$C8D75180,$BFD06116,$21B4F4B5,$56B3C423,$CFBA9599,$B8BDA50F,
     $2802B89E,$5F058808,$C60CD9B2,$B10BE924,$2F6F7C87,$58684C11,$C1611DAB,$B6662D3D,
     $76DC4190,$01DB7106,$98D220BC,$EFD5102A,$71B18589,$06B6B51F,$9FBFE4A5,$E8B8D433,
     $7807C9A2,$0F00F934,$9609A88E,$E10E9818,$7F6A0DBB,$086D3D2D,$91646C97,$E6635C01,
     $6B6B51F4,$1C6C6162,$856530D8,$F262004E,$6C0695ED,$1B01A57B,$8208F4C1,$F50FC457,
     $65B0D9C6,$12B7E950,$8BBEB8EA,$FCB9887C,$62DD1DDF,$15DA2D49,$8CD37CF3,$FBD44C65,
     $4DB26158,$3AB551CE,$A3BC0074,$D4BB30E2,$4ADFA541,$3DD895D7,$A4D1C46D,$D3D6F4FB,
     $4369E96A,$346ED9FC,$AD678846,$DA60B8D0,$44042D73,$33031DE5,$AA0A4C5F,$DD0D7CC9,
     $5005713C,$270241AA,$BE0B1010,$C90C2086,$5768B525,$206F85B3,$B966D409,$CE61E49F,
     $5EDEF90E,$29D9C998,$B0D09822,$C7D7A8B4,$59B33D17,$2EB40D81,$B7BD5C3B,$C0BA6CAD,
     $EDB88320,$9ABFB3B6,$03B6E20C,$74B1D29A,$EAD54739,$9DD277AF,$04DB2615,$73DC1683,
     $E3630B12,$94643B84,$0D6D6A3E,$7A6A5AA8,$E40ECF0B,$9309FF9D,$0A00AE27,$7D079EB1,
     $F00F9344,$8708A3D2,$1E01F268,$6906C2FE,$F762575D,$806567CB,$196C3671,$6E6B06E7,
     $FED41B76,$89D32BE0,$10DA7A5A,$67DD4ACC,$F9B9DF6F,$8EBEEFF9,$17B7BE43,$60B08ED5,
     $D6D6A3E8,$A1D1937E,$38D8C2C4,$4FDFF252,$D1BB67F1,$A6BC5767,$3FB506DD,$48B2364B,
     $D80D2BDA,$AF0A1B4C,$36034AF6,$41047A60,$DF60EFC3,$A867DF55,$316E8EEF,$4669BE79,
     $CB61B38C,$BC66831A,$256FD2A0,$5268E236,$CC0C7795,$BB0B4703,$220216B9,$5505262F,
     $C5BA3BBE,$B2BD0B28,$2BB45A92,$5CB36A04,$C2D7FFA7,$B5D0CF31,$2CD99E8B,$5BDEAE1D,
     $9B64C2B0,$EC63F226,$756AA39C,$026D930A,$9C0906A9,$EB0E363F,$72076785,$05005713,
     $95BF4A82,$E2B87A14,$7BB12BAE,$0CB61B38,$92D28E9B,$E5D5BE0D,$7CDCEFB7,$0BDBDF21,
     $86D3D2D4,$F1D4E242,$68DDB3F8,$1FDA836E,$81BE16CD,$F6B9265B,$6FB077E1,$18B74777,
     $88085AE6,$FF0F6A70,$66063BCA,$11010B5C,$8F659EFF,$F862AE69,$616BFFD3,$166CCF45,
     $A00AE278,$D70DD2EE,$4E048354,$3903B3C2,$A7672661,$D06016F7,$4969474D,$3E6E77DB,
     $AED16A4A,$D9D65ADC,$40DF0B66,$37D83BF0,$A9BCAE53,$DEBB9EC5,$47B2CF7F,$30B5FFE9,
     $BDBDF21C,$CABAC28A,$53B39330,$24B4A3A6,$BAD03605,$CDD70693,$54DE5729,$23D967BF,
     $B3667A2E,$C4614AB8,$5D681B02,$2A6F2B94,$B40BBE37,$C30C8EA1,$5A05DF1B,$2D02EF8D);

function CalcCRC32(Buf: Pointer; Len: Cardinal): LongWord;
asm
        PUSH    EBX
        MOV     EBX,EAX
        MOV     EAX,$FFFFFFFF
        PUSH    ESI
        TEST    EDX,EDX
        JE      @@qt
@@lp:   MOVZX   ESI,BYTE PTR [EBX]
        MOVZX   ECX,AL
        XOR     ECX,ESI
        SHR     EAX,8
        XOR     EAX,DWORD PTR [ECX*4+CRC32_Table]
        INC     EBX
        DEC     EDX
        JNE     @@lp
@@qt:   POP     ESI
        NOT     EAX
        POP     EBX
end;

procedure CalcCRC16(var CRC: word; Msg: pointer; Len: longint);
  {-update CRC16 with Msg data}
begin
  asm
       push    ebx
       mov     ecx,[Len]
       jecxz   @@2                       {no update if Len=0}
       mov     ebx,[CRC]
       mov     ax, [ebx]
       mov     edx,[Msg]
  @@1: xor     ah,[edx]
       movzx   ebx,ah
       shl     ax,8
       inc     edx
       xor     ax,word ptr CRC16_TABLE[ebx*2]
       dec     ecx
       jnz     @@1
       mov     ebx,[CRC]
       mov     [ebx],ax
  @@2: pop     ebx
  end;
end;

function CRC16String(const S: AnsiString): Word;
var
  I, J: Integer;
begin
  Result := $FFFF;
  J      := Length(S);

  for I := 1 to J do
    Result := CRC16_TABLE[Byte(Result xor Word(Ord(S[I])))] xor
      ((Result shr 8) and $00FF);
end;

{
function GetFileInfo(var FName: AnsiString; var FTime: TDateTime;
  var FSize: Cardinal): Boolean;
var
  FPath: AnsiString;
  SR:    TSearchRec;
begin
  FPath  := FName;
  Result := FileExists(FPath);

  if (not Result) then
  begin
    FPath  := PathAddSlash(FPath) + 'index.html';
    Result := FileExists(FPath);
    if not Result then
    begin
      FPath  := PathAddSlash(FPath) + 'index.htm';
      Result := FileExists(FPath);
      if not Result then
      begin
        FPath  := PathAddSlash(FPath) + 'default.htm';
        Result := FileExists(FPath);
      end;
    end;
  end;


  if Result then
  begin
    Result := FindFirst(FPath, faAnyFile, SR) = 0;

    FTime := FileDateToDateTime(SR.Time);
    FSize := SR.FindData.nFileSizeLow;
    FName := FPath;

    FindClose(SR);
  end;
end;
}

procedure DecodeURL(var URI: PAnsiChar);

  function HexToInt(C: Byte): Integer;
  begin
    Result := -1;
    if ((C >= CNUM0) and (C <= CNUM9)) then
      Result := C - CNUM0
    else
    begin
      C := C or CSPACE;
      if ((C >= C_LO_A) and (C <= C_LO_F)) then
        Result := C - C_LO_A + $0A;
    end;
  end;

var
  v: Integer;
  p, s, w: PAnsiChar;
begin
  p := URI;
  if (p <> nil) then
  begin
    w := p;
    while (p^ <> #0) do
    begin
      v := 0;
      if (p^ = '+') then
        w^ := ' '
      else
      if (p^ = '%') then
      begin
        s := p;
        Inc(s);

        if (s[0] in HEX_DIGITS) and (s[1] in HEX_DIGITS) then
        begin
          v := (HexToInt(Ord(s[0])) shl 4) + HexToInt(Ord(s[1]));
          if (v > 0) then
          begin
            // do not decode %00 to null char
            w^ := AnsiChar(v);
            p  := s + 1;
          end;
        end;
      end;
      if v = 0 then
        w^ := p^;
      Inc(w);
      Inc(p);
    end;
    w^ := #0;
  end;
end;

procedure ConsolidateSlashes(var P: PAnsiChar);
var
  L, R:   Integer;
  bSlash: Boolean;
begin
  if (P = nil) then
    Exit;

  L      := 0;
  R      := 0;
  bSlash := False;

  while (P[R] <> #0) do
  begin
    if bSlash then
    begin
      if (P[R] = '/') then
        Inc(R)
      else
      begin
        bSlash := False;
        P[L]   := P[R];
        Inc(L);
        Inc(R);
      end;
    end
    else
    begin
      if (P[R] = '/') then
        bSlash := True;
      P[L] := P[R];
      Inc(L);
      Inc(R);
    end;
  end;
  P[L] := #0;
end;

procedure PurgeURI(var URI: PAnsiChar);

  procedure OverlapCopy(Dst, Src: PAnsiChar);
  begin
    while (Src^ <> #0) do
    begin
      Dst^ := Src^;
      Inc(Src);
      Inc(Dst);
    end;
    Dst^ := #0;
  end;

var
  p, nxt: PAnsiChar;
begin
{$IFDEF XBUG}
  INFO(0, 'Before: ' + StrPas(URI));
{$ENDIF}
  if (URI = nil) or (URI^ = #0) or (StrScan(URI, '/') = nil) then
    Exit;

  p := StrPos(URI, '//');
  while (p <> nil) do
  begin
    OverlapCopy(p, p + 1);
    p := StrPos(URI, '//');
  end;

  p := StrPos(URI, '/./');
  while (p <> nil) do
  begin
    OverlapCopy(p, p + 2);
    p := StrPos(URI, '/./');
  end;

  while StrLComp(URI, '../', 3) = 0 do
  begin
    URI := URI + 3;
  end;

  p := StrPos(URI, '/../');
  if (p <> nil) then
  begin
    if (p = URI) then
    begin
      while StrLComp(URI, '/../', 4) = 0 do
      begin
        OverlapCopy(URI, URI + 3);
      end;
      p := StrPos(URI, '/../');
    end;

    while (p <> nil) do
    begin
      nxt := p + 4;
      if (p <> URI) and (p^ = '/') then
        Dec(p);

      while (p <> URI) and (p^ <> '/') do
        Dec(p);

      if (p^ = '/') then
        Inc(p);

      OverlapCopy(p, nxt);
      p := StrPos(URI, '/../');
    end;
  end;

  p := URI + StrLen(URI);
  repeat
    if StrComp(p, '/.') = 0 then
      p^ := #0
    else
    if StrComp(p, '/..') = 0 then
    begin
      if (p <> URI) then
      begin
        Dec(p);
        while (p <> URI) do
        begin
          if (p^ = '/') then
          begin
            Inc(p);
            p^ := #0;
{$IFDEF XBUG}
            INFO(0, 'Pass 1: ' + StrPas(URI));
{$ENDIF}
            Break;
          end;
          Dec(p);
        end;
      end
      else
        p^ := #0;
    end;
    Dec(p);
  until (p < URI);

  if (URI^ = #0) then
    StrPCopy(URI, '/');

  p := URI;
  if (p^ = '.') then
  begin
    Inc(p);
    if (p^ = #0) then
      Exit;

    if (p^ = '/') then
    begin
      while (p^ = '/') do
      begin
        Inc(p);
      end;

      OverlapCopy(URI, p);
    end;
  end;

{$IFDEF XBUG}
  INFO(0, 'Finally: ' + StrPas(URI));
{$ENDIF}
end;

function StrPBrk(const Str, Chr: PAnsiChar): PAnsiChar;
var
  I, L: Integer;
begin
  Result := Str;
  L      := Pred(StrLen(Chr));

  while Result^ <> #0 do
  begin
    for I := 0 to L do
      if Result^ = Chr[I] then
        Exit;
    Inc(Result);
  end;

  Result := nil;
end;

procedure StrReplaceChar(var Str: AnsiString; const cFrom, cTo: AnsiChar);
var
  I, J: Integer;
begin
  J := Length(Str);
  if J > 0 then
    for I := 1 to J do
    begin
      if Str[I] = cFrom then
        Str[I] := cTo;
    end;
end;

function atoi(const s: PAnsiChar): Integer;
var
  v:   Integer;
  neg: Boolean;
  x:   PByte;
begin
  neg := False;
  v   := 0;
  x   := PByte(s);

  //while (x^ <= Ord(' ')) and (x^ > 0) do
  while (x^ = CSPACE) or (Cardinal(x^ - 9) < 5) do
    Inc(x);

  if x^ = Ord('-') then
  begin
    neg := True;
    Inc(x);
  end
  else if x^ = Ord('+') then
    Inc(x);

  //while (x^ >= Ord('0')) and (x^ <= Ord('9')) do
  while (Cardinal((x^ - CNUM0)) < 10) do
  begin
    v := (v * 10) + (x^ - CNUM0);
    Inc(x);
  end;

  if neg then
    Result := -v
  else
    Result := v;
end;

function StorageSize(const Bytes: Int64): Ansistring;
var
  Size, Suffix: Ansistring;
  Fmt: Ansistring;
begin
  Fmt := '%0.1f';

  if (Bytes < SIZE_KB) then
  begin
    Size   := IntToStr(Bytes);
    Suffix := 'Byte';
  end
  else
  if (Bytes < SIZE_MB) then
  begin
    Size   := Format(Fmt, [Bytes / 1024.0]);
    Suffix := 'KB';
  end
  else
  if Bytes < (1024 * SIZE_MB) then
  begin
    Size   := Format(Fmt, [Bytes / (1024.0 * 1024.0)]);
    Suffix := 'MB';
  end
  else
  if Bytes < (Int64(1024) * 1024 * 1024 * 1024) then
  begin
    Size   := Format(Fmt, [Bytes / (1024.0 * 1024.0 * 1024.0)]);
    Suffix := 'GB';
  end;

  Result := Size + ' ' + Suffix;
end;

function KBSizeToString(const S : Integer) : Ansistring;
Var
  tmpr : Real;
Begin
  If s < (SIZE_KB * 2) Then
  Begin
    tmpr := S / 1024;
    Result := Format('%.2f', [tmpr]) + ' KB';
  End
  Else
    If s < 1.0 * 1024 * 2048 Then
    Begin
      tmpr := 1.0 * S / 1024;
      Result := Format('%.2f', [tmpr]) + ' MB';
    End
    Else
    Begin
      tmpr := 1.0 * S / (1024 * 1024);
      Result := Format('%.2f', [tmpr]) + ' KB';
    End;
End;

function EncodeURL(FName: AnsiString): AnsiString;
var
  I, Len: Integer;
  D:      Byte;
begin
  Len    := Length(FName);
  I      := 1;
  Result := '';

  while (I <= Len) do
  begin
    if (Byte(FName[I]) > 32) and (Byte(FName[I]) < 127) and
      (FName[I] <> '%') and (FName[I] <> '+') then
      Result := Result + FName[I]
    else
    begin
      D      := Byte(FName[I]) div 16;
      Result := Result + '%' + HEX_TABLE[D mod 16 + 1] +
        HEX_TABLE[Byte(FName[I]) mod 16 + 1];
    end;
    Inc(I);
  end;
end;

function HTTPEncode(const AStr: AnsiString): AnsiString;
// The NoConversion set contains characters as specificed in RFC 1738 and
// should not be modified unless the standard changes.
const
  NoConversion = ['A'..'Z','a'..'z','*','@','.','_','-',
                  '0'..'9','$','!','''','(',')'];
var
  Sp, Rp: PAnsiChar;
begin
  SetLength(Result, Length(AStr) * 3);
  Sp := PAnsiChar(AStr);
  Rp := PAnsiChar(Result);
  while Sp^ <> #0 do
  begin
    if Sp^ in NoConversion then
      Rp^ := Sp^
    else
      if Sp^ = ' ' then
        Rp^ := '+'
      else
      begin
        FormatBuf(Rp^, 3, '%%%.2x', 6, [Ord(Sp^)]);
        Inc(Rp,2);
      end;
    Inc(Rp);
    Inc(Sp);
  end;
  SetLength(Result, Rp - PAnsiChar(Result));
end;

function ScanULong(const src: PAnsiChar; var dest: Cardinal): Integer;
var
  l: Cardinal;
  x: PByte;
begin
  x := PByte(src);
  l := 0;

  while (x^ = CSPACE) or (Cardinal(x^ - 9) < 5) do
    Inc(x);

  while (Cardinal((x^ - CNUM0)) < 10) do
  begin
    l := (l * 10) + (x^ - CNUM0);
    Inc(x);
  end;

  {
  c   := Ord(tmp^) - Ord('0');

  while (c < 10) do
  begin
    l := l * 10 + c;
    Inc(tmp);
    c   := Ord(tmp^) - Ord('0');
  end;
  }
  dest   := l;
  {$IFDEF BORLAND}
  Result := x - src;
  {$ELSE}
  Result := PAnsiChar(x) - src;
  {$ENDIF}
end;

function PathDOSToUnix(const S: AnsiString): AnsiString;
var
  Loop:    Integer;
  MaxLoop: Integer;
begin
  Result  := S;
  MaxLoop := Length(Result);
  for Loop := 1 to MaxLoop do
    if Result[Loop] = '\' then
      Result[Loop] := '/';
end;

function PathAddSlash(const Path: AnsiString): AnsiString;
begin
  Result := Path;
  if (Path = '') or (AnsiLastChar(Path) <> '\') then
    Result := Path + '\';
end;

function FastCharPos(const Source: AnsiString; X:AnsiChar; Start:Integer):Integer;
asm
  Push  EDI
  Push  ESI
  Push  EBX
  Push  EBP

  Or    EAX,EAX
  Jz    @Done
  Mov   EDI,EAX
  Xor   EAX,EAX

  Mov   EBP,[EDI-4]
  Cmp   ECX,EBP
  Ja    @Done
  Dec   ECX
  Js    @Done
  Mov   EAX,EDX
  Mov   ESI,EDI
  Add   EDI,ECX
  Sub   EBP,ECX

  Cld
  Mov   ECX,EBP
  Shr   ECX,2
  Jz    @Skip

  Mov   AH,AL
  Mov   BX,AX
  Shl   EBX,16
  Mov   BX,AX
@Top:
  Mov   EAX,[EDI]
  Add   EDI,4
  Xor   EAX,EBX

  Lea   EDX,[EAX-$01010101]
  Not   EAX
  And   EDX,EAX
  And   EDX,$80808080
  Jnz   @GotIt

  Dec   ECX
  Jnz   @Top

  Mov   AL,BL
@Skip:
  And   EBP,3
  Jz    @Bail
  Mov   ECX,EBP
  repnz scasb
  Jz    @OK
@Bail:
  Xor   EAX,EAX
  Jmp   @Done
@GotIt:
  Test  EDX,$8080
  Jz    @L1
  Sub   EDI,2
  Shl   EDX,16
@L1:
  Shl   EDX,9
@OK:
  Sbb   EDI,ESI
  Mov   EAX,EDI

@Done:
  Pop   EBP
  Pop   EBX
  Pop   ESI
  Pop   EDI
end;

procedure Base64Initialise;
var
  I: Byte;
begin
  if (BASE64_TABLE[0] <> 0) then
    Exit;

  FillChar(BASE64_TABLE, SizeOf(BASE64_TABLE), #64);
  for I := C_UP_A to C_UP_Z do
    BASE64_TABLE[I] := I - C_UP_A;
  for I := C_LO_A to C_LO_Z do
    BASE64_TABLE[I] := I - C_LO_A + 26;
  for I := CNUM0 to CNUM9 do
    BASE64_TABLE[I] := I - CNUM0 + 52;
  BASE64_TABLE[Ord('+')] := 62;
  BASE64_TABLE[Ord('/')] := 63;
  BASE64_TABLE[Ord('=')] := 0;
end;

function Base64DecodeFast(const Src: PAnsiChar; Dst: PAnsiChar): Boolean;
var
  t1, t2, u1, u2, u3: Byte;
  c: Byte;
  Enc, Dec: PByte;
begin
  Result := False;
  Enc := PByte(Src);
  Dec := PByte(Dst);

  while True do
  begin
    c := Enc^;
    Inc(Enc);
    if (c = 0) then
    begin
      Dec^ := 0;
      Exit;
    end;

    t1 := BASE64_TABLE[c];
    if (t1 = 64) then
    begin
      Result := True;
      Exit;
    end;

    c := Enc^;
    Inc(Enc);
    if (c = 0) then
    begin
      Result := True;
      Exit;
    end;

    t2 := BASE64_TABLE[c];
    if (t2 = 64) then
    begin
      Result := True;
      Exit;
    end;

    u1 := t1 shl 2 or t2 shr 4;

    c := Enc^;
    Inc(Enc);
    if (c = 0) then
    begin
      Result := True;
      Exit;
    end;

    t1 := BASE64_TABLE[c];
    if (t1 = 64) then
    begin
      Result := True;
      Exit;
    end;

    u2 := (t2 and $F) shl 4 or t1 shr 2;

    c := Enc^;
    Inc(Enc);
    if (c = 0) then
    begin
      Result := True;
      Exit;
    end;

    t2 := BASE64_TABLE[c];
    if (t2 = 64) then
    begin
      Result := True;
      Exit;
    end;

    u3 := (t1 and $3) shl 6 or t2;

    Dec^ := u1;
    if u1 = 0 then
    begin
      Result := True;
      Exit;
    end;
    Inc(Dec);
    Dec^ := u2;
    if (u2 = 0) then
    begin
      Result := True;
      Exit;
    end;
    Inc(Dec);
    Dec^ := u3;
    if (u3 = 0) then
    begin
      Result := True;
      Exit;
    end;
    Inc(Dec);
  end;

  Result := True;
end;

initialization
  Base64Initialise;
end.
