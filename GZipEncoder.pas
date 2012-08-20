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
// $Version:0.6.2$ $Revision:1.0.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:10$
//
////////////////////////////////////////////////////////////////////////////////

unit GZipEncoder;

{$I NITROHTTPD.inc}

interface

{$IFDEF GZIP_COMPRESS}

uses
  Windows, Messages;

function GZCompressBuffer(const inBuffer: Pointer; inSize: Integer;
                          out outBuffer: Pointer; out outSize: Integer): Boolean;  
function GZCompressFileData(const FileName: string;
                            const OffSet, Count: Integer;
                            out outBuffer: Pointer; out outSize: Integer): Boolean;
function GZCompressFileData2(const FHandle: THandle;
                            const OffSet, Count: Integer;
                            out outBuffer: Pointer; out outSize: Integer): Boolean;
function GZCanCompress(const FN: String): Boolean;

{$ENDIF}

implementation

{$IFDEF GZIP_COMPRESS}

uses
  SysUtils, Common, zlib_interface;

const
	OS_FAT       =   0;
	OS_UNIX      =   3;
	OS_OS2       =   6;
	OS_MACINTOSH =   7;
	OS_NTFS      =  11;
	OS_UNKNOWN   = 255;

const
  GZIP_HEADER_LEN = 10;
  GZIP_FOOTER_LEN =  8;

const
  GZip_Header: array[0..Pred(GZIP_HEADER_LEN)] of Byte =
    (
      $1F, $8B,     // 16 bits: IDentification
      Z_DEFLATED,   //  8 bits: Compression Method
      0,            //  8 bits: FLags
      0, 0, 0, 0,   // 32 bits: Modification TIME
      0,            //  8 bits: Extra Flags
      OS_UNIX       //  8 bits: Operating System
    );

const
  GZIP_DOCUMENTS: array [1..10] of String =
  (
    '.html',      '.htm',
    '.txt',       '.css',
    '.js',        '.xml',
    '.xsl',       '.ini',
    '.doc',       '.bmp'
  );

(* GZIP
 * ====
 * gzip_header (10 bytes) + [gzip_encoder_content] + crc32 (4 bytes) + length (4 bytes)
 *
 *)

function GZCompressBuffer(const inBuffer: Pointer; inSize: Integer;
                        out outBuffer: Pointer; out outSize: Integer): Boolean;
const
  MEM_DELTA = 256;
var
  ret:     Integer;
  zstream: z_stream;
  ChkSum: Cardinal;
  GZip_Footer: array [0..Pred(GZIP_FOOTER_LEN)] of Byte;
begin
  Result := False;
  FillChar(zstream, SizeOf(z_stream), 0);
  FillChar(GZip_Footer, SizeOf(GZip_Footer), 0);

  outSize := (((inSize + (inSize div 10) + 12) + 255) and not 255) + GZIP_HEADER_LEN;
  GetMem(outBuffer, outSize);

	(* Add the GZip header:
	 * +---+---+---+---+---+---+---+---+---+---+
   * |ID1|ID2|CM |FLG|     MTIME     |XFL|OS |
   * +---+---+---+---+---+---+---+---+---+---+
 *)
  System.Move(GZip_Header[0], outBuffer^, GZIP_HEADER_LEN);

  zstream.next_in := inBuffer;
  zstream.avail_in := inSize;
  zstream.next_out := PBytef(Integer(outBuffer) + GZIP_HEADER_LEN);
  zstream.avail_out := outSize - GZIP_HEADER_LEN;

  ret := deflateInit2(zstream, Z_DEFAULT_COMPRESSION, Z_DEFLATED,
                      -MAX_WBITS, 9, Z_DEFAULT_STRATEGY);
  if ret <> Z_OK then
  begin
    // Error in deflateInit2() = %s
    FreeMem(outBuffer);
    Exit;
  end;

  ChkSum := CalcCRC32(inBuffer, inSize);

  while deflate(zstream, Z_FINISH) <> Z_STREAM_END do
  begin
    Inc(outSize, MEM_DELTA);
    ReallocMem(outBuffer, outSize);

    zstream.next_out := PBytef(Integer(outBuffer) + GZIP_HEADER_LEN + zstream.total_out);
    zstream.avail_out := MEM_DELTA;
  end;

  ret := deflateEnd(zstream);
  if ret <> Z_OK then
  begin
    //Error in deflateEnd(): err=%s
    FreeMem(outBuffer);
    Exit;
  end;

  outSize := GZIP_HEADER_LEN + zstream.total_out + GZIP_FOOTER_LEN;
  ReallocMem(outBuffer, outSize);

	(* Add the footer:
	 * +---+---+---+---+---+---+---+---+
	 * |     CRC32     |     ISIZE     |
         * +---+---+---+---+---+---+---+---+
	 *)

  GZip_Footer[0] := Byte(ChkSum          AND $FF);
  GZip_Footer[1] := Byte((ChkSum SHR  8) AND $FF);
  GZip_Footer[2] := Byte((ChkSum SHR 16) AND $FF);
  GZip_Footer[3] := Byte((ChkSum SHR 24) AND $FF);

  GZip_Footer[4] := Byte(inSize          AND $FF);
  GZip_Footer[5] := Byte((inSize SHR  8) AND $FF);
  GZip_Footer[6] := Byte((inSize SHR 16) AND $FF);
  GZip_Footer[7] := Byte((inSize SHR 24) AND $FF);

  System.Move(GZip_Footer[0], PBytef(Integer(outBuffer) + GZIP_HEADER_LEN + zstream.total_out)^, GZIP_FOOTER_LEN);

  Result := True;
end;

function GZCompressFileData(const FileName: string;
                            const OffSet, Count: Integer;
                        out outBuffer: Pointer; out outSize: Integer): Boolean;
var
  inBuffer: Pointer;
  inSize: Integer;
  Sz, Rd: DWORD;
  hFile: THandle;
  FileInfo: TByHandleFileInformation;
  BytesToCopy: Integer;
begin
  Result := False;
  hFile := CreateFile(PChar(FileName),
                      GENERIC_READ,
                      0,
                      nil,
                      OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                      0);

  BytesToCopy := Count;
  if (hFile <> INVALID_HANDLE_VALUE) then
  begin
    if GetFileInformationByHandle(hFile, FileInfo) then
    begin
      if (FileInfo.nFileSizeLow > 0) then
      begin
        if (OffSet > 0) then
          inSize  := Count
        else
          inSize := FileInfo.nFileSizeLow;

        GetMem(inBuffer, inSize);

        Rd := 0;
        Sz := 0;
        SetFilePointer(hFile, Offset, nil, FILE_BEGIN);

        repeat
          if not ReadFile(hFile, PChar(Integer(inBuffer) + Sz)^, READ_BUFFER_SIZE, Rd, nil) then
            Break;

          Inc(Sz, Rd);
          if (Rd > 0) then
          begin
            if (BytesToCopy > Rd) then
              Dec(BytesToCopy, Rd)
            else
              BytesToCopy := 0;
          end;
        until (Rd < READ_BUFFER_SIZE) or (BytesToCopy = 0);
      end;
    end;
  end;

  CloseHandle(hFile);
  Result := GZCompressBuffer(inBuffer, inSize, outBuffer, outSize);
  FreeMem(inBuffer, inSize);
end;


function GZCompressFileData2(const FHandle: THandle;
                            const OffSet, Count: Integer;
                            out outBuffer: Pointer; out outSize: Integer): Boolean;
var
  inBuffer: Pointer;
  inSize: Integer;
  Sz, Rd: DWORD;
  FileInfo: TByHandleFileInformation;
  BytesToCopy: Integer;
begin
  BytesToCopy := Count;

  if (FHandle <> INVALID_HANDLE_VALUE) then
  begin
    if GetFileInformationByHandle(FHandle, FileInfo) then
    begin
      if (FileInfo.nFileSizeLow > 0) then
      begin
        if (OffSet > 0) then
          inSize  := Count
        else
          inSize := FileInfo.nFileSizeLow;

        GetMem(inBuffer, inSize);

        Rd := 0;
        Sz := 0;
        SetFilePointer(FHandle, Offset, nil, FILE_BEGIN);

        repeat
          if not ReadFile(FHandle, PChar(Integer(inBuffer) + Sz)^, READ_BUFFER_SIZE, Rd, nil) then
            Break;

          Inc(Sz, Rd);
          if (Rd > 0) then
          begin
            if (BytesToCopy > Rd) then
              Dec(BytesToCopy, Rd)
            else
              BytesToCopy := 0;
          end;
        until (Rd < READ_BUFFER_SIZE) or (BytesToCopy = 0);
      end;
    end;
  end;

  Result := GZCompressBuffer(inBuffer, inSize, outBuffer, outSize);
  FreeMem(inBuffer, inSize);
end;

function GZCanCompress(const FN: String): Boolean;
var
  I: Integer;
  Ext: string;
begin
  Result := False;
  Ext := LowerCase(ExtractFileExt(FN));

  for I := 1 to Length(GZIP_DOCUMENTS) do
  begin
    if CompareStr(Ext, GZIP_DOCUMENTS[I]) = 0 then
    begin
      Result := True;
      Break;
    end;
  end;
end;

{$ENDIF}

end.
