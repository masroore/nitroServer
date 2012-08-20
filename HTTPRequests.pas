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
// $Version:0.6.2$ $Revision:1.5.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPRequests;

interface

{$I NITROHTTPD.INC}

uses
  Common, Buffer;

procedure HTTPRequestCreate(var Req: PHTTPRequest; const Ctx: Pointer);
procedure HTTPRequestReset(var Req: PHTTPRequest);
procedure HTTPRequestFree(var Req: PHTTPRequest);
function HTTPRequestComplete(Buf: PSmartBuffer; Req: PHTTPRequest): Boolean;
function HTTPParseRequest(var Req: PHTTPRequest; Buf: PSmartBuffer): Boolean;
function ParseDate(const str: PAnsiChar): TDateTime;

implementation

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  SysUtils, CachedLogger, IOCPWorker, VHosts;

procedure HTTPRequestCreate(var Req: PHTTPRequest; const Ctx: Pointer);
begin
  Req := AllocMem(SizeOf(THTTPRequest));
  HTTPRequestReset(Req);
  Req^.Context := Ctx;
end;

procedure HTTPRequestReset(var Req: PHTTPRequest);
begin
  with Req^ do
  begin
    Method := hmGet;
    Version := hv1_1;
    URI := nil;
    Query := nil;
    Accept := nil;
    AcceptCharset := nil;
    AcceptEncoding := nil;
    AcceptLanguage := nil;
    Authorization := nil;
    Connection := nil;
    PostData := nil;
    ContentType := nil;
    ContentLen := 0;
    PostLen := 0;
    Cookie := nil;
    Cookie2:= nil;
    Host := nil;
    TE := nil;
    IfModSince  := -1;
    BytesSent   := 0;
    RangeLWM    := 0;
    RangeHWM    := 0;
    RangeType   := rtNone;
    Referrer    := nil;
    UserAgent   := nil;
    StatusCode  := 200;
    ClientPort  := 0;
    HeaderRcvd  := False;
    AcceptGZip  := False;
    VirtualHost := nil;

    SetLength(OrigURL, 0);
    SetLength(ClientAddr, 0);
    SetLength(OrigHdr, 0);
    SetLength(AuthUser, 0);
    SetLength(AuthType, 0);
    SetLength(AuthPass, 0);
    SetLength(Filename, 0);
  end;
end;

procedure HTTPRequestFree(var Req: PHTTPRequest);
begin
  with Req^ do
  begin
    SetLength(OrigURL, 0);
    SetLength(ClientAddr, 0);
    SetLength(OrigHdr, 0);
    SetLength(AuthPass, 0);
    SetLength(AuthPass, 0);
    SetLength(AuthType, 0);
    SetLength(Filename, 0);
  end;

  FreeMem(Req);
  Req := nil;
end;

function HTTPRequestComplete(Buf: PSmartBuffer; Req: PHTTPRequest): Boolean;
begin
{
  Result := StrLComp(Buf^.CurPos - 4, #13#10#13#10, 4) = 0;
  if not Result then
    Result := StrLComp(Buf^.CurPos - 2, #10#10, 2) = 0;
}

  Result := Req^.HeaderRcvd;
  if not Result then
    Result := StrPos(Buf^.Data, #13#10#13#10) <> nil;
  if not Result then
    Result := StrPos(Buf^.Data, #10#10) <> nil;
end;

function ParseTime(const src: PAnsiChar; var tm: TDateTime): Boolean;
var
  tmp: Cardinal;
  c:   PAnsiChar;
  h, m, s: Word;
begin
  Result := False;
  c      := src;

  c := c + ScanULong(c, tmp);
  if c^ <> ':' then
    Exit;

  h := tmp;
  Inc(c);

  c := c + ScanULong(c, tmp);
  if c^ <> ':' then
    Exit;

  m := tmp;
  Inc(c);

  c := c + ScanULong(c, tmp);
  if c^ <> ' ' then
    Exit;

  s      := tmp;
  tm     := EncodeTime(h, m, s, 0);
  Result := True;
end;

const
  CMONTHS: PAnsiChar = 'JanFebMarAprMayJunJulAugSepOctNovDec';

function ParseDate(const str: PAnsiChar): TDateTime;
var
  c:      PAnsiChar;
  i, tmp: Cardinal;
  d, m, y: Word;
  tm:     TDateTime;

  function BuildDate: TDateTime;
  begin
    if tmp < 70 then
      y := tmp + 2000
    else if tmp < 1000 then
      y := tmp + 1900
    else
      y := tmp;
    Result := EncodeDate(y, m, d) + tm;
  end;

begin
  Result := 0;

  if str = nil then
    Exit;
  c := str;
  (* "Sun, 06 Nov 1994 08:49:37 GMT",
   * "Sunday, 06-Nov-94 08:49:37 GMT" and
   * "Sun Nov  6 08:49:37 1994" *)
  if c[3] = ',' then
    Inc(c, 5)
  else
  if c[3] = ' ' then
  begin
    Inc(c, 4);
    for i := 0 to 11 do
    begin
      if StrLIComp(c, CMONTHS + i * 3, 3) = 0 then
      begin
        m := i + 1;
        Break;
      end;
    end;

    Inc(c, 4);
    if (c^ = ' ') then
      Inc(c);

    c := c + ScanULong(c, tmp);
    d := tmp;
    Inc(c);

    if (not ParseTime(c, tm)) then
      Exit;

    Inc(c, 9);
    c := c + ScanULong(c, tmp);
    y := tmp;

    Result := BuildDate;
    Exit;
  end
  else
  begin
    while (c^ <> ',') and (c^ <> #0) do
      Inc(c);

    Inc(c);
  end;

  c := c + ScanULong(c, tmp);
  d := tmp;

  Inc(c);
  for i := 0 to 11 do
  begin
    if StrLIComp(c, CMONTHS + i * 3, 3) = 0 then
    begin
      m := i + 1;
      Break;
    end;
  end;

  Inc(c, 4);

  c := c + ScanULong(c, tmp);

  Inc(c);
  if (not ParseTime(c, tm)) then
    Exit;

  Result := BuildDate;
end;

function ParseRange(Req: PHTTPRequest; P: PAnsiChar): Boolean;
var
  str: PAnsiChar;
begin
  Result := False;
  if StrScan(P, ',') <> nil then
  begin
    Req^.StatusCode := 416;
{$IFDEF ENABLE_LOGGING}
    LogWarn(Req^.Context, 'unsupported range');
{$ENDIF}
    Exit;
  end;

  if StrLComp(P, 'bytes=', 6) <> 0 then
  begin
    Req^.StatusCode := 416;
  {$IFDEF ENABLE_LOGGING}
    LogWarn(Req^.Context, 'invalid range');
  {$ENDIF}
    Exit;
  end;

  str := P + 6;
  while (str^ <> #0) and ((str^ = #9) or (str^ = #32)) do
    Inc(str);

  if (str^ = '-') then
  begin
    Inc(str);
    Req^.RangeHWM := atoi(str);
    if Req^.RangeHWM < 0 then
    begin
      Req^.StatusCode := 416;
{$IFDEF ENABLE_LOGGING}
      LogWarn(Req^.Context, 'invalid negative range');
{$ENDIF}
      Exit;
    end;
    Req^.RangeLWM  := 1;
    Req^.RangeType := rtBoth;

    Result := True;
    Exit;
  end;

  Req^.RangeLWM := atoi(str);
  if Req^.RangeLWM < 0 then
  begin
    Req^.StatusCode := 416;
{$IFDEF ENABLE_LOGGING}
    LogWarn(Req^.Context, 'invalid negative range');
{$ENDIF}
    Exit;
  end;
  if Req^.RangeLWM = 0 then
    Req^.RangeLWM := 1;

  while (str^ <> #0) and (str^ <> '-') do
    Inc(str);

  if (str^ = '-') and (str[1] <> #0) then
  begin
    Inc(str);

    while (str^ <> #0) and ((str^ = #9) or (str^ = #32)) do
      Inc(str);

    Req^.RangeHWM := atoi(str);
    if (Req^.RangeHWM <= 0) or (Req^.RangeHWM < Req^.RangeLWM) then
    begin
      Req^.StatusCode := 416;
{$IFDEF ENABLE_LOGGING}
      LogWarn(Req^.Context, 'invalid range');
{$ENDIF}
      Exit;
    end;

    Req^.RangeType := rtBoth;
    Result := True;
  end
  else
  begin
    Req^.RangeType := rtLWMOnly;
    Result := True;
  end;
end;

function ParseHeaderLine(Req: PHTTPRequest; P: PAnsiChar): Boolean;
var
  val, line, c, Pass: PAnsiChar;
  AuthBuf: array [0..255] of AnsiChar;
begin
  {
  if StrLIComp(P, 'host: ', 6) = 0 then
    Req^.Host := P + 6
  else
  if StrLIComp(P, 'host: ', 6) = 0 then
    Req^.Host := P + 6
  }

  line   := P;
  val    := StrScan(line, ':');
  if (val = nil) then
  begin
    Result := False;
{$IFDEF ENABLE_LOGGING}
    LogWarn(Req^.Context, 'malformed header');
{$ENDIF}
    Exit;
  end;

  //val^ := #0;
  Inc(val);

  // Skip the spaces
  while (val^ <> #0) and ((val^ = #9) or (val^ = #32)) do
    Inc(val);

  if val^ = #0 then
    Exit;

  c := StrPBrk(val, #13#10);
  if c <> nil then
    c^ := #0;

  case UpCase(line[0]) of
    'A':
    begin
      if StrLIComp(line, 'ACCEPT:', 7) = 0 then
        Req^.Accept := val
      else
      if StrLIComp(line, 'ACCEPT-CHARSET:', 15) = 0 then
        Req^.AcceptCharset := val
      else
      if StrLIComp(line, 'ACCEPT-ENCODING:', 16) = 0 then
      begin
        Req^.AcceptEncoding := val;
{$IFDEF GZIP_COMPRESS}
        if (StrPos(Req^.AcceptEncoding, 'gzip') <> nil) or
           (StrPos(Req^.AcceptEncoding, 'x-gzip') <> nil) then
          Req^.AcceptGZip := True;
{$ENDIF}
      end
      else
      if StrLIComp(line, 'ACCEPT-LANGUAGE:', 16) = 0 then
        Req^.AcceptLanguage := val
      else
      if StrLIComp(line, 'AUTHORIZATION:', 14) = 0 then
      begin
        Req^.Authorization := val;
        if (StrLIComp(val, 'BASIC ', 6) <> 0) then
        begin
          // unsupported authorization type %s
          Req^.StatusCode := 400;
          Result := False;
          Exit;
        end;

        Inc(val, 6);
        if StrLen(val) > 255 then
        begin
          // "too long authorization from %s (%s%s): %s", ip2string(r->ip), r->host?:"-", r->uri, strlen(a)
          Req^.StatusCode := 413;
          Result := False;
          Exit;
        end;

        if not Base64DecodeFast(val, AuthBuf) then
        begin
          // bad encoded authorization from %s (%s%s): %s", ip2string(r->ip), r->host?:"-", r->uri, a
          Req^.StatusCode := 400;
          Result := False;
          Exit;
        end;

        Pass := StrScan(AuthBuf, ':');
        if Pass = nil then
        begin
          // bad authorization format from %s (%s%s): %s", ip2string(r->ip), r->host?:"-", r->uri, user);
          Req^.StatusCode := 400;
          Result := False;
          Exit;
        end;

        Pass^ := #0;
        Inc(Pass);
        //SetString();

        Req^.AuthUser := StrPas(AuthBuf);
        Req^.AuthPass := StrPas(Pass);
        Req^.AuthType := 'Basic';
      end;

    end;
    'C':
    begin
      if StrLIComp(line, 'CONTENT-TYPE:', 13) = 0 then
        Req^.ContentType := val
      else
      if StrLIComp(line, 'CONTENT-LENGTH:', 15) = 0 then
        Req^.ContentLen := atoi(val)
      else
      if StrLIComp(line, 'CONNECTION:', 11) = 0 then
      begin
        Req^.Connection := val;
        Req^.KeepAlive  := StrLIComp(val, 'KEEP-ALIVE', 10) = 0;
      end
      else
      if StrLIComp(line, 'COOKIE:', 7) = 0 then
        Req^.Cookie := val
      else
      if StrLIComp(line, 'COOKIE2:', 8) = 0 then
        Req^.Cookie2 := val;
    end;
    'H':
    begin
      if StrLIComp(line, 'HOST:', 5) = 0 then
      begin
        if Req^.Host = nil then
          Req^.Host := val;
      end;
    end;
    'I':
    begin
      if StrLIComp(line, 'IF-MODIFIED-SINCE:', 18) = 0 then
        Req^.IfModSince := ParseDate(val);
    end;
    'R':
    begin
      if (StrLIComp(line, 'REFERER:', 8) = 0) or
        (StrLIComp(line, 'REFERRER:', 9) = 0) then
        Req^.Referrer := val
      else
      if StrLIComp(line, 'RANGE:', 6) = 0 then
        Result := ParseRange(Req, val);
    end;
    'T':
    begin
      if StrLIComp(line, 'TE:', 3) = 0 then
        Req^.TE := val;
    end;
    'U':
    begin
      if StrLIComp(line, 'USER-AGENT:', 11) = 0 then
        Req^.UserAgent := val;
    end;
  end;
  Result := True;
end;

function ParseHeaders(var Req: PHTTPRequest; Buf: PSmartBuffer;
  const Offset, Limit: Cardinal): Boolean;
var
  P, S: PAnsiChar;
  I, J: Integer;
begin
  P := Buf^.Data + Offset;
  I := 0;
  J := Limit - Offset;
  S := P;

  while (I < J) do
  begin
    if (P[I] = #10) and (P[I - 1] = #13) then
    begin
//{$IFDEF BORLAND}
      P[I]     := #0;
      P[I - 1] := #0;
(*
{$ELSE} // FPC
      (P + I)^ := #0;
      (P + I - 1)^ := #0;
{$ENDIF}
*)
      if (S <> @P[I - 1]) then
        Result := ParseHeaderLine(Req, S);

        if not Result then
        Break;

//{$IFDEF BORLAND}
      S := @P[I + 1];
//{$ELSE} // FPC
//      S := (P + I + 1);
//{$ENDIF}
    end;

    Inc(I);
  end;
end;

procedure ExtractHostFromURI(var Req: PHTTPRequest);
var
  P, Q: PAnsiChar;
begin
  with Req^ do
  begin
    Host := nil;
    if StrLIComp(URI, 'http://', 7) = 0 then
    begin
      P   := URI + 7;
      Q   := URI + 7;

      P   := StrScan(P, '/');
      P^  := #0;

      Q   := StrScan(Q, ':');
      if (Q <> nil) then
        Q^  := #0;

      Req^.Host := URI + 7;
      URI := P + 1;
    end;
  end;
end;

function ParseURI(var Req: PHTTPRequest): Boolean;
var
  P:    PAnsiChar;
begin
  Result := StrLen(Req^.URI) > 0;

  if Result then
  begin
    if Req^.Host = nil then
      ExtractHostFromURI(Req);
    ConsolidateSlashes(Req^.URI);
    PurgeURI(Req^.URI);
    DecodeURL(Req^.URI);

    P := StrScan(Req^.URI, '?');
    if (P <> nil) then
    begin
      P^ := #0;
      Req^.Query := P + 1;
    end;

{$IFDEF XBUG}
    INFO(0, 'Parsed URL: ' + Req^.URI);
{$ENDIF}
    SetLength(Req^.Filename, StrLen(Req^.URI));
    {
    if Req^.URI^ = '/' then
      Req^.Filename := StrPas(Req^.URI + 1)
    else
    }
      Req^.Filename := StrPas(Req^.URI);

    StrReplaceChar(Req^.Filename, '/', '\');


    //StrLCat(@Req^.Filename[Length(sDir)], Req^.URI + 1, StrLen(Req^.URI) - 1);

    //Move(PAnsiChar(Req^.URI + 1)^, sDir[Length(sDir)], StrLen(Req^.URI) - 1);
    //Req^.Filename := sDir;
  end;
end;

function HTTPParseRequest(var Req: PHTTPRequest; Buf: PSmartBuffer): Boolean;
var
  P, Q: PAnsiChar;
  Skip: Integer;
begin
  if (Req^.PostLen > 0) then
  begin
    Req^.PostLen := Req^.ContentLen - (BufGetWritePos(Buf) - Req^.PostData);
    if Req^.PostLen > 0 then
    begin
{$IFDEF XBUG}
      INFO(0, 'Partial Post-data received ' + IntToStr(Integer(Buf^.CurPos) - Integer(Req^.PostData)) + ' remaining ' + IntToStr(Req^.PostLen) +' RE-READ!');
{$ENDIF}
      Result := False;
    end
    else
    begin
      Result := True;
{$IFDEF XBUG}
      INFO(0, 'Got FULL Post-data!');
{$ENDIF}

    end;
    Exit;
  end;

  Q := StrPos(Buf^.Data, EOH_MARKER);
  if (Q = nil) then
    Q := StrPos(Buf^.Data, HDR_END_LF);

  if (Q <> nil) then
  begin
    if (Q[0] = EOL_CR) and (Q[1] = EOL_LF) then
      Inc(Q, 4)
    else
      Inc(Q, 2);

    SetLength(Req^.OrigHdr, Q - Buf^.Data);
    Move(Buf^.Data^, Req^.OrigHdr[1], Q - Buf^.Data);
  end;

  if (Buf^.Used < MIN_REQ_LEN) then
  begin
    Req^.StatusCode := 400;
    //Result := False;
    // TODO: Handle data
    Exit;
  end;

  P := StrScan(Buf^.Data, ' ');
  with Req^ do
  begin
    if P = nil then
    begin
      Req.StatusCode := 400;
      Exit;
    end;
    //P^ := #0;

    if StrLIComp(Buf^.Data, 'GET', 3) = 0 then
      Method := hmGet
    else
    if StrLIComp(Buf^.Data, 'HEAD', 4) = 0 then
      Method := hmHead
    else
    if StrLIComp(Buf^.Data, 'POST', 4) = 0 then
      Method := hmPost
    else
    begin
      Req.StatusCode := 501;
      //TODO: Handle request
      Exit;
    end;

    while P^ = #32 do
      Inc(P);

    URI := P;
    P   := StrPBrk(URI, #32#13#10);

    if (P^ <> #32) then
    begin
      Version := hv0_9;
      StatusCode := 200;
      P^ := #0;

      SetLength(OrigURL, StrLen(URI));
      Move(URI^, OrigURL[1], StrLen(URI));

      Filename := StrPas(URI + 1);
      Exit;
    end
    else
    begin
      P^ := #0;

      SetLength(OrigURL, StrLen(URI));
      Move(URI^, OrigURL[1], StrLen(URI));

      Inc(P);

      while P^ = #32 do
        Inc(P);

      if StrLIComp(P, 'HTTP/1.0', 8) = 0 then
        Version := hv1_0
      else
      if StrLIComp(P, 'HTTP/1.1', 8) = 0 then
        Version := hv1_1
      else
      begin
        Req.StatusCode := 400;
        Exit;
      end;

      P := StrPBrk(P, #13#10);
    end;

    if not ParseURI(Req) then
    begin
      Req^.StatusCode := 400;
      Exit;
    end;

    Inc(P);
    if (P^ in [#13, #10]) and (P^ <> (P - 1)^) then
    begin
      (P - 1)^ := #0;
      Inc(P);
    end
    else
      P[-1] := #0;

    Skip := Buf^.Used;
    if (Q <> nil) then
      Skip := Q - Buf^.Data;

    if ParseHeaders(Req, Buf, P - Buf^.Data, Skip) then
    begin
      StatusCode := 200;
    end;

    Result  := True;
    Req^.HeaderRcvd := True;

    Req^.VirtualHost := GVirtualHosts.GetVirtualHost(Req^.Host);

    if (Req^.ContentLen > 0) then
    begin
      if (Q <> nil) then
      begin
        Req^.PostData := Q;
        if Req^.ContentLen <= (BufGetWritePos(Buf) - Q) then
        begin
          Inc(Q, Req^.ContentLen);
          Q^      := #0;
          PostLen := 0;
{$IFDEF XBUG}
          INFO(0, 'Got full POST DATA ' + IntToStr(Req^.ContentLen));
{$ENDIF}

        end
        else
          //if Req^.ContentLen > (Buf^.CurPos - Q) then
        begin
          // We have partial post data.. what to do?
          Req^.PostLen := Req^.ContentLen - (BufGetWritePos(Buf) - Q);

{$IFDEF XBUG}
          WARNING(0, 'PARTIAL POST DATA RECEIVED Total: ' + IntToStr(req^.ContentLen) + ' Remaining: ' + IntToStr(Req^.PostLen) + '. Re-reading from socket');
          DUMP('Post data', @Req^.PostData, Q - Req^.PostData);
{$ENDIF}
          Result := False;
        end;
      end;
    end;
  end;
end;

end.
