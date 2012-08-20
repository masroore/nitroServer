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
// $Version:0.6.2$ $Revision:1.5$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

unit MimeType;

interface

const
  GZIP_MIME_INDEX = 12;

function GetMIMEType(const FName: String): String;
function GetMIMEIndex(const FName: String): Integer;
function GetMIMETypeStr(const AIndex: Integer): string;

implementation

uses
  SysUtils;

const
  MAX_MIME_TYPE = 35;
  MIME_TABLE: array  [0..Pred(MAX_MIME_TYPE), 0..1] of String[30] =
    (
    ('.html', 'text/html'),
    ('.htm', 'text/html'),
    ('.css', 'text/css'),
    ('.gif', 'image/gif'),
    ('.jpeg', 'image/jpeg'),
    ('.jpe', 'image/jpeg'),
    ('.jpg', 'image/jpeg'),
    ('.png', 'image/png'),
    ('.txt', 'text/plain'),
    ('.zip', 'application/x-zip-compressed'),
    ('.rar', 'application/x-rar-compressed'),
    ('.tgz', 'application/x-compressed'),
    ('.gz', 'application/x-compressed'),
    ('.bz2', 'application/x-compressed'),
    ('.7z', 'application/x-compressed'),
    ('.z', 'application/x-compress'),
    ('.php', 'text/html'),
    ('.shtml', 'text/html'),
    ('.mdb', 'application/msaccess'),
    ('.xls', 'application/msexcel'),
    ('.doc', 'application/msword'),
    ('.pdf', 'application/pdf'),
    ('.rtf', 'application/rtf'),
    ('.swf', 'application/x-shockwave-flash'),
    ('.tar', 'application/x-tar'),
    ('.ra', 'audio/x-pn-realaudio'),
    ('.ram', 'audio/x-pn-realaudio'),
    ('.wav', 'audio/x-wav'),
    ('.avi', 'video/avi'),
    ('.mp3', 'video/mpeg'),
    ('.mpeg', 'video/mpeg'),
    ('.mpg', 'video/mpeg'),
    ('.qt', 'video/quicktime'),
    ('.mov', 'video/quicktime'),
    ('.exe', 'application/octet-stream')
    );

function GetMIMEType(const FName: String): String;
var
  Ext: String;
  I:   Integer;
begin
  Ext := ExtractFileExt(FName);
  if Ext <> '' then
  begin
    for I := 0 to 31 do
      if CompareStr(MIME_TABLE[I, 0], Ext) = 0 then
      begin
        Result := MIME_TABLE[I, 1];
        Break;
      end;
  end
  else
    Result := 'text/plain';

  if Result = '' then
    Result := 'application/octet-stream';
end;

function GetMIMEIndex(const FName: String): Integer;
var
  Ext: String;
  I:   Integer;
begin
  Result := Pred(MAX_MIME_TYPE);
  Ext := ExtractFileExt(FName);
  if Ext <> '' then
  begin
    for I := 0 to 34 do
      if CompareStr(MIME_TABLE[I, 0], Ext) = 0 then
      begin
        Result := I;
        Break;
      end;
  end
  else
    Result := 0;
end;

function GetMIMETypeStr(const AIndex: Integer): string;
begin
  Assert((AIndex >= 0) and (AIndex< MAX_MIME_TYPE));

  Result := MIME_TABLE[AIndex, 1];
end;  

end.
