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
// $Version:0.6.1$ $Revision:1.6$ $Author:masroore$ $RevDate:9/20/2007 2:03:10$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPProcessor;

interface

{$I NITROHTTPD.INC}

uses
  Common, Windows;

function ProcessRequests(var Ctx: PClientContext): Boolean;

implementation

uses
{$IFDEF XBUG}
  uDebug,
  {$IFDEF TRACK_METHOD}
  SiAuto,
  {$ENDIF}
{$ENDIF}
  CachedLogger,
  SysUtils,
  Buffer,
  IOCPWorker,
  MimeType,
{$IFDEF ENABLE_STATS}
  ServerStats,
{$ENDIF}
{$IFDEF PHP_DIRECT_EXECUTE}
  PHPEngine,
{$ENDIF}
  FileInfoCache,
  FileDataCache,
  HTTPRequests,
  HTTPResponse,
  HTTPConn,
  VirtualFileIO,
  FastDateCache,
{$IFDEF CACHE_HTTP_HEADERS}
  HTTPHeaderCache,
{$ENDIF}
  FastDirLister,
{$IFDEF GZIP_COMPRESS}
  GZipEncoder,
{$ENDIF}
  ScriptThreadPool,
  CGIEngine,
  ISAPIEngine,
  GZipDataCache,
  HTTPAuth;

function ProcessHeadRequest(var Ctx: PClientContext;
                           const IsDir, AllowDirList: Boolean;
                           const FDateTime: TDateTime;
                           const FLen: Cardinal;
                           const FAttribute, FMimeType: Integer ): Boolean;
begin
  with Ctx^ do
  begin
    if not IsDir then
    begin
      if (not IsDir) and
         (HTTPReq^.IfModSince <> -1) and
         (FDateTime <= HTTPReq^.IfModSince) then
      begin
  {$IFDEF XBUG}
        INFO(Ctx^.Sock, 'FileDate <= If_mod_since');
  {$ENDIF}
        HTTPReq^.StatusCode := 304;
        HTTPReq^.KeepAlive  := False;

        HTTPEmitBadRequest(Ctx);
        Result := True;
        Exit;
      end;

{$IFDEF CACHE_HTTP_HEADERS}
      GetHeaderFromCache(Ctx, HTTPReq^.Filename,
        FDateTime, FLen, HTTPReq, SendBuf);
{$ELSE}
      HTTPBuildHeader(SendBuf, GetMIMEType(HTTPReq^.Filename),
        FDateTime, FLen, HTTPReq);
{$ENDIF}

      SockSend(Ctx);
      Result := True;
    end
    else
    begin
      HTTPReq^.StatusCode := 404;
      HTTPReq^.KeepAlive  := False;
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      HTTPEmitBadRequest(Ctx);
      Result := True;

      //HTTPEmitBadRequest(HTTPReq);
    end;
  end;
end;

{$IFDEF GZIP_COMPRESS}
function ProcessGetRequestGZip(var Ctx: PClientContext;
                               const IsDir, AllowCaching, AllowDirList: Boolean;
                               const FDateTime: TDateTime;
                               const FLen: Cardinal;
                               const FAttribute, FMimeType: Integer ): Boolean;
var
  S:    String;
  BytesToSend: Integer;
  Data: Pointer;
  CacheEntry: PFileGZCache;
  FileInfo: TByHandleFileInformation;
  hFile: THandle;
begin
{$IFDEF XBUG}
  {$IFDEF TRACK_METHOD}
    SiMain.TrackMethod('ProcessGetRequestGZip');
  {$ENDIF}
{$ENDIF}

  with Ctx^ do
  begin
    if not IsDir then
    begin
      BytesToSend := FLen;
(*
      if (HTTPReq^.IfModSince <> -1) and (FDateTime <= HTTPReq^.IfModSince) then
      begin
  {$IFDEF XBUG}
        INFO(Ctx^.Sock, 'FileDate <= If_mod_since');
  {$ENDIF}
        HTTPReq^.StatusCode := 304;
        HTTPReq^.KeepAlive  := False;

        Result := True;
        HTTPEmitBadRequest(Ctx);
        Exit;
      end;
*)
      if AllowCaching then
      begin
        CacheEntry := GzGetFileBufFromCache(Ctx, HTTPReq^.Filename,
                                            BytesToSend, Data);
        if (CacheEntry <> nil) then
        begin
  {$IFDEF XBUG}
          INFO(Ctx^.Sock, 'Grabbed file data from gzip cache. Orig:' + IntToStr(FLen) + ' Compressed:' + IntToStr(BytesToSend));
  {$ENDIF}
          HTTPBuildHeader(SendBuf, GetMIMEType(HTTPReq^.Filename),
                          FDateTime, BytesToSend, HTTPReq);
  {$IFDEF XBUG}
          DUMP('Header', Pointer(SendBuf^.Data), SendBuf^.Used);
  {$ENDIF}
          SockSendCachedGzFile(Ctx, Data, BytesToSend, CacheEntry);
        end
        else
        begin
    {$IFDEF XBUG}
          ERROR(Ctx^.Sock, 'Could not grab file from gzip cache!');
    {$ENDIF}
          HTTPReq^.StatusCode := 500;
          HTTPReq^.KeepAlive  := False;

          Result := True;
          HTTPEmitBadRequest(Ctx);
          Exit;
        end;
      end
      else
      begin
        hFile := CreateFileA(PAnsiChar(HTTPReq^.Filename),
                            GENERIC_READ,
                            0,
                            nil,
                            OPEN_EXISTING,
                            FILE_ATTRIBUTE_NORMAL,
                            0);

        if (hFile <> INVALID_HANDLE_VALUE) then
          if GetFileInformationByHandle(hFile, FileInfo) then
            if (FileInfo.nFileSizeLow > 0) then
                GZCompressFileData2(hFile, 0, FileInfo.nFileSizeLow, Data, BytesToSend);

        CloseHandle(hFile);
  {$IFDEF XBUG}
        INFO(Ctx^.Sock, 'Document was gzip-ped. Orig:' + IntToStr(FileInfo.nFileSizeLow) + ' Compressed:' + IntToStr(BytesToSend));
  {$ENDIF}

        HTTPBuildHeader(SendBuf, GetMIMEType(HTTPReq^.Filename),
                        FDateTime, BytesToSend, HTTPReq);

  {$IFDEF XBUG}
        DUMP('Header', Pointer(SendBuf^.Data), SendBuf^.Used);
  {$ENDIF}
        BufReserve(SendBuf, BytesToSend);
        BufAppendData(SendBuf, @Data, BytesToSend);

        FreeMem(Data, BytesToSend);
        SockSend(Ctx);
      end;
    end
    else
    if AllowDirList and IsDir then
    begin
{$IFDEF CACHE_DIR_LIST}
      DirListGenerateCached(HTTPReq^.Filename, HTTPReq^.URI, S, BytesToSend);
{$ELSE}
      DirListGenerate(HTTPReq^.Filename, HTTPReq^.URI, S, BytesToSend);
{$ENDIF}
      //RangeEnd := BytesToSend;
      GZCompressBuffer(@S[1], BytesToSend, Data, BytesToSend);

  {$IFDEF XBUG}
      INFO(Ctx^.Sock, 'Sending gzipped dir listing. Compressed:' + IntToStr(BytesToSend));
  {$ENDIF}

      HTTPBuildHeader(SendBuf, 'text/html',
                      Now, BytesToSend, HTTPReq);
  {$IFDEF XBUG}
      DUMP('Header', Pointer(SendBuf^.Data), SendBuf^.Used);
  {$ENDIF}
      BufAppendData(SendBuf, Data, BytesToSend);
      //BufAppendStrZ(SendBuf, PAnsiChar(S));

      FreeMem(Data, BytesToSend);
      SockSend(Ctx);
    end
    else
    begin
      HTTPReq^.StatusCode := 404;
      HTTPReq^.KeepAlive  := False;
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}
      s := BuildCustomErrorPage(Ctx, Ctx^.HTTPReq^.OrigURL, 404);
      s := s + #13#10 + DumpRequest(HTTPReq);
      HTTPBuildHeader(SendBuf, '', Now, Length(s), HTTPReq);
      BufAppendStrZ(SendBuf, PAnsiChar(S));
      SockSend(Ctx);
    end;

    Result := True;
  end;
end;
{$ENDIF}

function ProcessGetRequest(var Ctx: PClientContext;
                           const IsDir, AllowCaching, AllowDirList: Boolean;
                           const FDateTime: TDateTime;
                           const FLen: Cardinal;
                           const FAttribute, FMimeType: Integer ): Boolean;
var
  S:    String;
  Buf:  array [0..Pred(READ_BUFFER_SIZE)] of Byte;
  R: Integer;
  F: Integer;
  RangeStart, RangeEnd, BytesToSend, BytesToCopy: Integer;
  CacheEntry: PFileDataCache;
  Data: Pointer;
begin
  {
  SetLength(s, RecvBuf^.Used);
  Move(RecvBuf^.Data^, S[1], RecvBuf^.Used);
  }
{$IFDEF XBUG}
  {$IFDEF TRACK_METHOD}
    SiMain.TrackMethod('ProcessGetRequest');
  {$ENDIF}
{$ENDIF}

  with Ctx^ do
  begin
    //if GetFileInfo(HTTPReq^.Filename, FDt, FLen, FIsDir, MimeType) then
    if not IsDir then
    begin
      RangeStart  := 0;
      RangeEnd    := FLen;
      BytesToSend := FLen;

      if (HTTPReq^.IfModSince <> -1) and (FDateTime <= HTTPReq^.IfModSince) then
      begin
  {$IFDEF XBUG}
        INFO(Ctx^.Sock, 'FileDate <= If_mod_since');
  {$ENDIF}
        HTTPReq^.StatusCode := 304;
        HTTPReq^.KeepAlive  := False;

        Result := True;
        HTTPEmitBadRequest(Ctx);
        Exit;
      end
      else
      if (HTTPReq^.RangeType <> rtNone) then
      begin
        if HTTPReq^.RangeType = rtLWMOnly then
        begin
          RangeStart := HTTPReq^.RangeLWM;
          RangeEnd   := FLen;
        end
        else
        begin
          RangeStart := HTTPReq^.RangeLWM;
          RangeEnd   := HTTPReq^.RangeHWM;
        end;

        if (RangeStart >= FLen) or (RangeEnd > FLen) then
        begin
          HTTPReq^.StatusCode := 416;
{$IFDEF ENABLE_STATS}
          StatsFailedReq;
{$ENDIF}  
          HTTPEmitBadRequest(Ctx);
          Result := True;
          Exit;
        end
        else
        begin
          BytesToSend := RangeEnd - RangeStart;
          HTTPReq^.StatusCode := 206;
        end;
      end;

{$IFDEF CACHE_HTTP_HEADERS}
    if (HTTPReq^.RangeType = rtNone) then
    begin
      GetHeaderFromCache(Ctx, HTTPReq^.Filename,
                         FDateTime, BytesToSend,
                         HTTPReq, SendBuf)
    end
    else
{$ENDIF}
      HTTPBuildHeader(SendBuf, GetMIMEType(HTTPReq^.Filename),
                      FDateTime, BytesToSend, HTTPReq);

  {$IFDEF XBUG}
      DUMP('Header', Pointer(SendBuf^.Data), SendBuf^.Used);
  {$ENDIF}
      if (FLen < CACHEFILE_THRESHOLD) then
      begin
  {$IFDEF XBUG}
        INFO(Ctx^.Sock, 'Grabbing file data from cache.');
  {$ENDIF}
        begin
          CacheEntry := nil;
          CacheEntry := GetFileBufFromCache(Ctx, HTTPReq^.Filename, RangeStart,
                                            BytesToSend, Data);
          if (CacheEntry <> nil) then
          begin
          {$IFDEF XBUG}
            INFO(Ctx^.Sock, 'Grabbed file data from cache. Sending ' + IntToStr(BytesToSend) + ' bytes now....');
          {$ENDIF}
            SockSendCachedFile(Ctx, Data, BytesToSend, CacheEntry);
          end
          else
          begin
            F := VFileOpen(HTTPReq^.Filename);
            if (RangeStart >= 0) then
              VFileSeek(F, RangeStart, 0);
              //SetFilePointer(F, RangeStart, nil, 0);

    {$IFDEF XBUG}
            INFO(Ctx^.Sock, 'Could not retrieve file from cache. Sending file from disk.');
    {$ENDIF}

            BytesToCopy := BytesToSend;
            BufReserve(SendBuf, BytesToSend);

            repeat
              R := VFileRead(F, Buf[0], READ_BUFFER_SIZE);

              if (R > 0) then
              begin
                if (BytesToCopy > R) then
                begin
                  BufAppendData(SendBuf, @Buf, R);
                  Dec(BytesToCopy, R);
                end
                else
                begin
                  BufAppendData(SendBuf, @Buf, BytesToCopy);
                  BytesToCopy := 0;
                end;
              end;
            until (R < READ_BUFFER_SIZE) or (BytesToCopy = 0);

            VFileClose(F);
            SockSend(Ctx);
          end;
        end;
      end
      else
      begin
        F := VFileOpen(HTTPReq^.Filename);
        {
        F :=  CreateFile(PAnsiChar(HTTPReq^.Filename),
                         GENERIC_READ,
                         FILE_SHARE_READ or FILE_SHARE_WRITE,
                         nil,
                         OPEN_EXISTING,
                         FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                         0);
        }
        if (RangeStart >= 0) then
          VFileSeek(F, RangeStart, 0);
          //SetFilePointer(F, RangeStart, nil, 0);

        if (BytesToSend < TRANSMITFILE_THRESHOLD) then
        begin
  {$IFDEF XBUG}
          INFO(Ctx^.Sock, 'Sending file from disk.');
  {$ENDIF}

          BytesToCopy := BytesToSend;
          BufReserve(SendBuf, BytesToSend);

          repeat
            R := VFileRead(F, Buf[0], READ_BUFFER_SIZE);
            if (R > 0) then
            begin
              if (BytesToCopy > R) then
              begin
                BufAppendData(SendBuf, @Buf, R);
                Dec(BytesToCopy, R);
              end
              else
              begin
                BufAppendData(SendBuf, @Buf, BytesToCopy);
                BytesToCopy := 0;
              end;
            end;
          until (R < READ_BUFFER_SIZE) or (BytesToCopy = 0);

          VFileClose(F);
          SockSend(Ctx);
        end
        else
        begin
  {$IFDEF XBUG}
          INFO(Ctx^.Sock, 'Transmitting file from disk.');
  {$ENDIF}

          Ctx^.FileHandle := F;
          Ctx^.FileSize   := BytesToSend;

          SockTransmitFile(Ctx, not HTTPReq^.KeepAlive);
        end;

        Result := True;
      end;
    end
    else
    if AllowDirList and IsDir then
    begin
{$IFDEF CACHE_DIR_LIST}
      DirListGenerateCached(HTTPReq^.Filename, HTTPReq^.URI, S, BytesToSend);
{$ELSE}
      DirListGenerate(HTTPReq^.Filename, HTTPReq^.URI, S, BytesToSend);
{$ENDIF}
      HTTPBuildHeader(SendBuf, 'text/html', Now, BytesToSend, HTTPReq);
      BufAppendStrZ(SendBuf, PAnsiChar(S));

      SockSend(Ctx);
      Result := True;
    end
    else
    begin
      HTTPReq^.StatusCode := 404;
      HTTPReq^.KeepAlive  := False;
{$IFDEF ENABLE_STATS}
      StatsFailedReq;
{$ENDIF}

      //s := HTTPBuildHTMLResponse('URI Not Found', 'Error 404',
      //  'Requested URI not found. ' + DumpRequest(HTTPReq), HTTPReq);

      s := BuildCustomErrorPage(Ctx, Ctx^.HTTPReq^.OrigURL, 404);
      s := s + #13#10 + DumpRequest(HTTPReq);
      HTTPBuildHeader(SendBuf, '', Now, Length(s), HTTPReq);
      BufAppendStrZ(SendBuf, PAnsiChar(S));
      SockSend(Ctx);

      //HTTPEmitBadRequest(HTTPReq);
    end;

    Result := True;
  end;
end;

function ProcessRequests(var Ctx: PClientContext): Boolean;
var
  S: string;
  AllowCaching,
  AllowDirList,
  IsDir,
  AllowExecScript,
  Authenticate: Boolean;
  DateTime:  TDateTime;
  FSize:  Cardinal;
  Attribute, MIMEType:  Integer;
  Realm: string;
begin
{$IFDEF XBUG}
  {$IFDEF TRACK_METHOD}
    SiMain.TrackMethod('ProcessRequests');
  {$ENDIF}
{$ENDIF}

  Result := False;
  with Ctx^ do
  begin
    if HTTPRequestComplete(RecvBuf, HTTPReq) then
    begin
{$IFDEF XBUG}
      INFO(Ctx^.Sock, 'Received full header. Parsing...');
{$ENDIF}

      Result := HTTPParseRequest(HTTPReq, RecvBuf);
{$IFDEF XBUG}
      INFO(Ctx^.Sock, 'Done parsing HTTP headers!');
{$ENDIF}

      if not Result then
        Exit;

      if (HTTPReq^.Version = hv1_1) and (HTTPReq^.Host = nil) then
      begin
{$IFDEF XBUG}
        INFO(Ctx^.Sock, 'HTTP/1.1 client did not specify Hostname. Shutting down conn...');
{$ENDIF}
        HTTPReq^.StatusCode := 400;
      end;

      if (HTTPReq^.StatusCode <> 200) then
      begin
        HTTPReq^.KeepAlive := False;
        HTTPEmitBadRequest(Ctx);
        Result := True;
        Exit;
      end;

      FSize := 0;
      if not MapURLToFile(HTTPReq^.Filename, HTTPReq^.VirtualHost,
                          HTTPReq^.Filename,
                          AllowCaching, IsDir, AllowExecScript,
                          AllowDirList, Authenticate,
                          DateTime, FSize, Attribute, MIMEType) then
      begin
        {
        Result := True;
        HTTPEmitBadRequest(Ctx);
        Exit;
        }
        HTTPReq^.StatusCode := 404;
        HTTPReq^.KeepAlive  := False;

        s := BuildCustomErrorPage(Ctx, Ctx^.HTTPReq^.OrigURL, 404);
        s := s + #13#10 + DumpRequest(HTTPReq);
        HTTPBuildHeader(SendBuf, '', Now, Length(s), HTTPReq);
        BufAppendStrZ(SendBuf, PAnsiChar(S));
{$IFDEF ENABLE_STATS}
        StatsFailedReq;
{$ENDIF}
        SockSend(Ctx);
        Result := True;
        Exit;
      end;
{$IFDEF XBUG}
      INFO(Ctx^.Sock, DumpRequest(HTTPReq));
{$ENDIF}

      if Authenticate then
      begin
{$IFDEF XBUG}
      INFO(Ctx^.Sock, 'Authenticating user...');
{$ENDIF}
        Ctx^.HTTPReq^.StatusCode  := 401;
        if  (Ctx^.HTTPReq^.AuthType <> '') and
            (Ctx^.HTTPReq^.AuthUser <> '') and
            (Ctx^.HTTPReq^.AuthPass <> '') then
        begin
          if AnsiCompareText(Ctx^.HTTPReq^.AuthType, 'basic') = 0 then
          begin
             if HTTPAuthBasic(Ctx) then
                Ctx^.HTTPReq^.StatusCode  := 200;
          end;
        end;

        if (Ctx^.HTTPReq^.StatusCode  = 401) then
        begin
{$IFDEF XBUG}
          INFO(Ctx^.Sock, 'Authentication FAILED!');
{$ENDIF}
          HTTPReq^.KeepAlive := False;
          Result := True;
          HTTPAuthRequired(Ctx);
          Exit;
        end;
{$IFDEF XBUG}
        INFO(Ctx^.Sock, 'Authentication SUCCESSFUL!');
{$ENDIF}
      end;

      if HTTPReq^.StatusCode = 200 then
      begin
        {
        if (HTTPReq^.Version <> hv1_1) then
        begin
          if HTTPReq^.KeepAlive then
            HTTPReq^.KeepAlive := False;
        end;
        }

        if HTTPReq^.KeepAlive then
        begin
          Inc(HTTPReq^.KACount);
          if (HTTPReq^.KACount >= KEEPALIVE_MAX) then
            HTTPReq^.KeepAlive := False;
        end;
        BufRemove(SendBuf, -1);
        
{$IFDEF PHP_DIRECT_EXECUTE}
        if AllowExecScript and IsPHPScript(HTTPReq^.Filename) then
        begin
          HTTPReq^.ScriptType := stPHP;
          ScriptPoolQueueJob(Ctx);
          Result := True;
          Exit;
        end;
{$ENDIF}

        if AllowExecScript and IsISAPIScript(HTTPReq^.Filename) then
        begin
          HTTPReq^.ScriptType := stISAPI;
          ScriptPoolQueueJob(Ctx);
          Result := True;
          Exit;
        end;

        if AllowExecScript and IsCGIScript(HTTPReq^.Filename) then
        begin
          HTTPReq^.ScriptType := stCGI;
          ScriptPoolQueueJob(Ctx);
          Result := True;
          Exit;
        end;

        case HTTPReq^.Method of
          hmGet:
          begin
{$IFDEF GZIP_COMPRESS}
            if HTTPReq^.AcceptGZip and
               (HTTPReq^.RangeType = rtNone) and
               (HTTPReq^.IfModSince = -1) and
               (IsDir or (GZCanCompress(HTTPReq^.Filename) and
               ((FSize >= GZIP_MINSIZE) and (FSize <= GZIP_MAXSIZE)))) then
              Result := ProcessGetRequestGZip(Ctx, IsDir, AllowCaching, AllowDirList,
                                              DateTime, FSize,
                                              Attribute, MIMEType)
            else
{$ENDIF}
            begin
              HTTPReq^.AcceptGZip := False;
              Result := ProcessGetRequest(Ctx, IsDir, AllowCaching, AllowDirList,
                                          DateTime, FSize,
                                          Attribute, MIMEType);
            end;
          end;
          hmHead:
          begin
            HTTPReq^.AcceptGZip := False;
            Result := ProcessHeadRequest(Ctx, IsDir, AllowDirList,
                                        DateTime, FSize,
                                        Attribute, MIMEType);
          end;
          hmPost:
          begin
            // We should never be here.
            HTTPReq^.StatusCode := 501;
            HTTPReq^.KeepAlive  := False;
{$IFDEF ENABLE_STATS}
            StatsFailedReq;
{$ENDIF}

            HTTPEmitBadRequest(Ctx);
            Result := True;
          end;
        end;
      end
      else
      begin
        HTTPReq^.KeepAlive := False;
{$IFDEF ENABLE_STATS}
        StatsFailedReq;
{$ENDIF}

        HTTPEmitBadRequest(Ctx);
        Result := True;
      end;
    end;
  end;
end;

end.
