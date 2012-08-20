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
// THAT THE FOLLOWING CONDITIONS ARE MET:
//
// 1. REDISTRIBUTIONS OF SOURCE CODE MUST RETAIN THE ABOVE COPYRIGHT NOTICE, 
//    THIS LIST OF CONDITIONS AND THE FOLLOWING DISCLAIMER.
//
// 2. REDISTRIBUTIONS IN BINARY FORM MUST REPRODUCE THE ABOVE
//    COPYRIGHT NOTICE, THIS LIST OF CONDITIONS AND THE FOLLOWING
//    DISCLAIMER IN THE DOCUMENTATION AND/OR OTHER MATERIALS
//    PROVIDED WITH THE DISTRIBUTION.
// 
// 3. THE NAME OF THE AUTHOR MAY NOT BE USED TO ENDORSE OR PROMOTE
//    PRODUCTS DERIVED FROM THIS SOFTWARE WITHOUT SPECIFIC PRIOR
//    WRITTEN PERMISSION.
//
// IN NO EVENT SHALL THE AUTHOR BE LIABLE TO ANY PARTY FOR ANY DIRECT, 
// INDIRECT, SPECIAL, INCIDENTAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES, 
// (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
// HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, 
// STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING
// IN ANY WAY OUT OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN 
// IF THE AUTHOR HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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
// DOCUMENTATION IS MANDATORY. IF YOUR PROGRAM HAS AN "ABOUT BOX", THE
// FOLLOWING CREDIT MUST BE DISPLAYED IN IT:
//   "nitroServer (C) 2007 Dr. Masroor Ehsan Choudhury <nitroserver@gmail.com>"
//
// ALTERED SOURCE VERSIONS MUST BE PLAINLY MARKED AS SUCH, AND MUST NOT BE
// MISREPRESENTED AS BEING THE ORIGINAL SOFTWARE.
//
// $Version:0.6.2$ $Revision:1.5$ $Author:masroore$ $RevDate:9/30/2007 21:38:02$
//
////////////////////////////////////////////////////////////////////////////////

unit Buffer;

interface

uses
  SysUtils;

type
  PSmartBuffer = ^TSmartBuffer;

  TSmartBuffer = record
    TotalSize,
    Available,
    Used:    Integer;
    Data,
    CurPos:  PAnsiChar;
  end;

procedure BufCreate(var P: PSmartBuffer; InitialSize: Integer);
procedure BufFree(var P: PSmartBuffer);
procedure BufAppendStrZ(P: PSmartBuffer; PStr: PAnsiChar);
function BufAppendData(S: PSmartBuffer; P: Pointer; SizeData: Integer): Integer;
procedure BufRemove(P: PSmartBuffer; Bytes: Integer);
procedure BufReserve(var P: PSmartBuffer; Bytes: Integer);
procedure BufShrink(var P: PSmartBuffer; MinSize: Integer);
procedure BufSetUsed(var P: PSmartBuffer; Bytes: Integer);
function BufGetWritePos(P: PSmartBuffer): PAnsiChar;

implementation

const
  BUFFER_GRANULARITY = 4096;

function AlignSize(ASize: Integer): Integer;
begin
  Result  := ((ASize + (BUFFER_GRANULARITY - 1)) and -BUFFER_GRANULARITY);
end;

procedure BufCreate(var P: PSmartBuffer; InitialSize: Integer);
begin
  P := AllocMem(SizeOf(TSmartBuffer));

  with P^ do
  begin
    Used    := 0;
    Data    := nil;
    Data    := AllocMem(AlignSize(InitialSize));
    if (Data <> nil) then
    begin
      CurPos    := Data;
      Available := InitialSize;
      TotalSize := InitialSize;
    end
    else
    begin
      TotalSize := 0;
      Available := 0;
      CurPos    := nil;
    end;
  end;
end;

procedure BufFree(var P: PSmartBuffer);
begin
  with P^ do
    if (Data <> nil) then
    begin
      FreeMem(Data, TotalSize);
      Data := nil;
    end;

  FreeMem(p);
  P := nil;
end;

procedure BufRemove(P: PSmartBuffer; Bytes: Integer);
begin
  with p^ do
  begin
    if (Bytes = -1) then
    begin
      CurPos    := Data;
      Used      := 0;
      Available := TotalSize;
    end
    else
    begin
      if (Bytes > TotalSize) then
        Bytes := TotalSize;

      if (Bytes < TotalSize) then
      begin
        Dec(Used, Bytes);
        Inc(Available, Bytes);
        Move(Pointer(Integer(Data) + Bytes)^, Data^, Used);

{$IFDEF FPC}
        CurPos := Pointer(Integer(Data) + Used);
{$ELSE}
        CurPos := Data + Used;
{$ENDIF}
      end
      else
      begin
        CurPos    := Data;
        Used      := 0;
        Available := TotalSize;
      end;
    end;

    //FillChar(CurPos^, Available, #0);
  end;
end;

procedure BufReserve(var P: PSmartBuffer; Bytes: Integer);
begin
  with P^ do
    if (Bytes > 0) and (Available < Bytes) then
    begin
      Bytes := AlignSize(Bytes);
      
      Dec(Bytes, Available);
      Inc(TotalSize, Bytes);
      Inc(Available, Bytes);
      ReAllocMem(Data, TotalSize);
      CurPos := Data + Used;
    end;
end;

procedure BufShrink(var P: PSmartBuffer; MinSize: Integer);
begin
  with P^ do
  begin
    MinSize := AlignSize(MinSize);
    if (TotalSize <> MinSize) then
      ReallocMem(Data, MinSize);

    Used      := 0;
    CurPos    := Data;
    Available := MinSize;
    TotalSize := MinSize;
  end;
end;

procedure BufAppendStrZ(P: PSmartBuffer; PStr: PAnsiChar);
var
  DLength,
  Incr: Integer;
begin
  DLength := 0;

  if PStr <> nil then
    DLength := StrLen(PStr);

  if (DLength > 0) then
    with P^ do
    begin
      Incr := AlignSize(DLength);
      if (Available < Incr) then
      begin
        Dec(Incr, Available);
        Inc(TotalSize, Incr);
        Inc(Available, Incr);
        ReAllocMem(Data, TotalSize);
        CurPos := Data + Used;
      end;

      Move(PStr^, CurPos^, DLength);
      Dec(Available, DLength);
      Inc(Used, DLength);
{$IFDEF FPC}
      CurPos := Pointer(Integer(CurPos) + DLength);
{$ELSE}
      CurPos := CurPos + DLength;
{$ENDIF}
    end;
end;

function BufAppendData(S: PSmartBuffer; P: Pointer; SizeData: Integer):
    Integer;
var
  Incr: Integer;
begin
  Result := SizeData;
  if (SizeData > 0) and (P <> nil) then
    with S^ do
    begin
      Incr := AlignSize(SizeData);
      if (Available < Incr) then
      begin
        Dec(Incr, Available);
        Inc(TotalSize, Incr);
        Inc(Available, Incr);
        ReAllocMem(Data, TotalSize);
        CurPos := Data + Used;
      end;

      Move(P^, CurPos^, SizeData);
      Dec(Available, SizeData);
      Inc(Used, SizeData);
{$IFDEF FPC}
      CurPos := Pointer(Integer(CurPos) + SizeData);
{$ELSE}
      CurPos := CurPos + SizeData;
{$ENDIF}
    end;
end;

procedure BufSetUsed(var P: PSmartBuffer; Bytes: Integer);
begin
  with P^ do
    if (Bytes > 0) and (TotalSize > Bytes) then
    begin
      Dec(Available, Bytes);
      Inc(Used, Bytes);
      CurPos := Data + Used;
    end;
end;

function BufGetWritePos(P: PSmartBuffer): PAnsiChar;
begin
  Result := P^.CurPos;
end;

end.
