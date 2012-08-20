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
// $Version:0.6.2$ $Revision:1.3$ $Author:masroore$ $RevDate:9/30/2007 21:38:08$
//
////////////////////////////////////////////////////////////////////////////////

(*
 * Fast directory listing cache. Provides significant performance boost
 * on a heavily loaded server.
 *
 * Generates listing of directories and caches the results so that subsequent
 * requests will be fast.
 *
 * The caching and non-caching versions of file listers were executed
 * 1000 times.
 * Result:
 *   Routine                  Time taken   CPU usage
 *   -----------------------  ----------   ---------
 *   DirListGenerateCached     6.6 secs    25-60%
 *   DirListGenerate          18.4 secs    75-90%
 *)

unit FastDirLister;

interface

{$I NITROHTTPD.inc}

uses
  Windows, SysUtils;

{$IFDEF CACHE_DIR_LIST}
const
  DIR_LIST_PURGE_TIMEOUT = 30;  

function DirListGenerateCached(Directory, URL: String;
  var HTML: String;
  var CntLength: Integer): Boolean;
procedure FListCachePurge(TimeoutSecs: Cardinal);
{$ENDIF}
function DirListGenerate(const Directory, URL: String;
  var HTML: String;
  var CntLength: Cardinal): Boolean;

implementation

uses
  HashTable,
  Common,
  FastLock;

{$IFDEF CACHE_DIR_LIST}
type
  PDirListing = ^TDirListing;
  TDirListing = record
    Directory,
    URL,
    Listing: string;
    CreatedOn,
    ContLen,
    CkSum: Cardinal;
  end;

const
  FLIST_HASHTABLE_SIZE = 319;

var
  g_DirListingCache: THashTable;
  g_Lock: TFastLock;
{$ENDIF}

function DirListGenerate(const Directory, URL: String;
  var HTML: String; var CntLength: Cardinal): Boolean;
var
  FindResult: Word;
  RStart, RLen: Integer;
  SearchFile: TSearchRec;
  RealPath:   String;
  ActualURL:  String;
  TotalFileCount: Integer;
  TotalFileSize: Int64;
begin
  (* Assume the function succeeds *)
  Result := True;
  (* Try generating the HTML *)
  try
    (* Append "/" to the URL if necessary *)
    ActualURL := URL;
    if (ActualURL = '') then
    begin
      ActualURL := '/';
    end
    else
    begin
      RStart := Length(ActualURL);
      RLen  := 0;

      while (ActualURL[RStart] = '/') do
      begin
        Inc(RLen);
        Dec(RStart);
        //Delete(ActualURL, Length(ActualURL), 1);
        //if (ActualURL = '') then
        //  Break;
      end;

      if (RLen > 0) then
        Delete(ActualURL, RStart + 1, RLen);

      ActualURL := ActualURL + '/';
    end;

    (* Generate HTML "header" *)
    HTML     :=
      '<html><head><title>Index of ' + ActualURL + '</title></head>' +
      '<FONT FACE=VERDANA FONT SIZE=+2 COLOR=RED><B>Index of '
      + URL
      + '</B></FONT><P><BODY BGCOLOR=#FAF9E0 TEXT=BLACK ALINK=RED><FONT FACE=TAHOMA FONT SIZE=-2>'
      + '<TABLE background-color=#FAF9E0 color=#000000 BORDER=0 CELLSPACING=4 CELLPADDING=4>'
      + '<TR><TD COLSPAN="2"><A HREF="../">Parent directory</A></TD></TR>' + #13#10;
    (* Search for directories *)
    RealPath := Directory;
    if (RealPath <> '') then
    begin
      RStart := Length(RealPath);
      RLen   := 0;

      while (RealPath[RStart] = '\') do
      begin
        Dec(RStart);
        Inc(RLen);
        //Delete(RealPath, Length(RealPath), 1);
        //if (RealPath = '') then
        //  Break;
      end;

      if (RLen > 0) then
        Delete(RealPath, RStart + 1, RLen);
    end;

    // Find the folders first
    FindResult := FindFirst(RealPath + '\*.*', faDirectory, SearchFile);

    while (FindResult = 0) do
    begin
      if (SearchFile.Attr and faDirectory <> 0) then
      begin
        if (SearchFile.Name[1] <> '.') then
        begin
          HTML := HTML + '<TR><TD>' + #13#10 +
            '<IMG SRC=/images/folder.gif  alt="[DIR]">&nbsp;<A HREF="' +
            ActualURL + EncodeURL(SearchFile.Name) + '/">' + SearchFile.Name +
            '</A></TD>' + #13#10 + '<TD ALIGN="right">DIR</TD></TR>' + #13#10;
        end;
      end;

      FindResult := FindNext(SearchFile);
    end;
    FindClose(SearchFile);

    // Second pass: Generate files
    TotalFileCount  := 0;
    TotalFileSize   := 0;

    FindResult := FindFirst(RealPath + '\*.*', faAnyFile, SearchFile);
    while (FindResult = 0) do
    begin
      if (SearchFile.Attr and (faDirectory or faVolumeID) = 0) then
      begin
        Inc(TotalFileCount);
        Inc(TotalFileSize, SearchFile.Size);
        HTML := HTML + '<TR><TD>' + #13#10 +
          '<IMG SRC=/images/default.gif  alt="[DOC]">&nbsp;<A HREF="' +
          ActualURL + EncodeURL(SearchFile.Name) + '">' + SearchFile.Name +
          '</A></TD>' + #13#10 + '<TD ALIGN="right NOWRAP">' +
          StorageSize(SearchFile.Size) + '</TD>' + #13#10 + '<TD ALIGN="right NOWRAP">' +
          DateTimeToStr(FileDateToDateTime(SearchFile.Time)) + '</TD></TR>' + #13#10;
      end;

      FindResult := FindNext(SearchFile);
    end;
    FindClose(SearchFile);

    (* Generate HTML "footer" *)

    HTML      := HTML + '<tr class="bottom"><td>' + IntToStr(TotalFileCount)
                 + ' files</td><td>'
                 + StorageSize(TotalFileSize)
                 + '</td><td></td></tr></table>'
                 + '<hr><address><FONT FACE=VERDANA FONT SIZE=+1 COLOR=RED><B>Powered By:' +
                 SERVER_SIGNATURE + '</B></FONT></address></body></html>';

    CntLength := Length(HTML);
  except
    HTML      := '';
    CntLength := 0;
    Result    := False;
  end;
end;

{$IFDEF CACHE_DIR_LIST}

function InternalAddDirListing(Directory, URL: string; CkSum: Cardinal): PDirListing;
begin
  New(Result);
  Result^.Directory := Directory;
  Result^.URL       := URL;
  DirListGenerate(Directory, URL, Result^.Listing, Result^.ContLen);
  Result^.CkSum     := CkSum;
  Result^.CreatedOn := GetTickCount;

  HashInsert(g_DirListingCache, Directory, CkSum, Result);
end;

function InternalFindFileDirListing(const Directory: string; const Hash: Cardinal; var FList: PDirListing): Boolean;
var
  H: PHashNode;
begin
  Result := False;
  FList  := nil;

  H := HashFind(g_DirListingCache, Directory, Hash);
  if Assigned(H) then
  begin
    FList  := PDirListing(H^.Data);
    Result := True;
  end;
end;

function DirListGenerateCached(Directory, URL: String;
  var HTML: String;
  var CntLength: Integer): Boolean;
var
  Hash: Cardinal;
  P: PDirListing;
begin
  Result    := False;
  Directory := LowerCase(Trim(Directory));
  Hash      := SuperFastHash(PAnsiChar(Directory), Length(Directory)) mod FLIST_HASHTABLE_SIZE;

  g_Lock.Enter;
  try
    if not InternalFindFileDirListing(Directory, Hash, P) then
      P := InternalAddDirListing(Directory, URL, Hash);

    SetLength(HTML, P^.ContLen);
    HTML      := P^.Listing;
    CntLength := P^.ContLen;
    
    //P^.CreatedOn := GetTickCount;

    Result := True;   
  finally
    g_Lock.Leave;
  end;
end;

procedure FListClearCallBack(Item: Pointer);
var
  P: PDirListing;
begin
  P := PDirListing(Item);

  SetLength(P^.Directory, 0);
  SetLength(P^.URL, 0);
  SetLength(P^.Listing, 0);

  Dispose(P);
  P := nil;
end;

function FListPurgeCallBack(Item: Pointer; Param: LongInt): Boolean;
var
  P: PDirListing;
  TimeOut: Cardinal;
begin
  TimeOut := Cardinal(Param);
  P := PDirListing(Item);
  Result := (TimeOut > P^.CreatedOn);
  
  if Result then
  begin
    SetLength(P^.Directory, 0);
    SetLength(P^.URL, 0);
    SetLength(P^.Listing, 0);

    Dispose(P);
    P := nil;
  end;
end;

procedure FListCachePurge(TimeoutSecs: Cardinal);
begin
  g_Lock.Enter;
  try
    HashPurge(g_DirListingCache, FLIST_HASHTABLE_SIZE, GetTickCount - (TimeoutSecs * 1000), FListPurgeCallBack);
  finally
    g_Lock.Leave;
  end;
end;

initialization
  g_Lock := TFastLock.Create(0, False);
  SetLength(g_DirListingCache, FLIST_HASHTABLE_SIZE);

finalization
  HashClear(g_DirListingCache, FLIST_HASHTABLE_SIZE, FListClearCallBack);
  SetLength(g_DirListingCache, 0);
  FreeAndNil(g_Lock);
  
{$ENDIF}

end.
