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
// $Version:0.6.2$ $Revision:1.4.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:12$
//
////////////////////////////////////////////////////////////////////////////////

unit LockPool;

interface

uses
  Classes, FastLock;

type
  TLockPool = class
  private
    FLocks: array of TFastLock;
    FPoolSize,
    FGranularity: Integer;

    function CalcPoolIndex(Item: Integer): Integer;
  public
    constructor Create(const PoolSize, Granularity, SpinCount: Integer; PreCreateEvents: Boolean);
    destructor Destroy; override;

    procedure Enter(Index: Integer);
    procedure Leave(Index: Integer);

    procedure EnterAll;
    procedure LeaveAll;
  end;

implementation

{$I NITROHTTPD.INC}

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  SysUtils;

{ TLockPool }

function TLockPool.CalcPoolIndex(Item: Integer): Integer;
begin
  Result := Item div FGranularity;
{$IFDEF XBUG}
  INFO(0, 'Item index=' + IntToStr(Item) + ' Lock=' + IntToStr(Result), 2);
{$ENDIF}
end;

constructor TLockPool.Create(const PoolSize, Granularity, SpinCount: Integer; PreCreateEvents: Boolean);
var
  I: Integer;
begin
  inherited Create;

  SetLength(FLocks, PoolSize);
  FPoolSize := PoolSize;
  FGranularity := Granularity;
  for I := 0 to Pred(FPoolSize) do
    FLocks[I] := TFastLock.Create(SpinCount, PreCreateEvents);
end;

destructor TLockPool.Destroy;
var
  I: Integer;
begin
  for I := 0 to Pred(FPoolSize) do
    FLocks[I].Free;

  SetLength(FLocks, 0);

  inherited;
end;

procedure TLockPool.Enter(Index: Integer);
begin
  FLocks[CalcPoolIndex(Index)].Enter;
end;

procedure TLockPool.EnterAll;
var
  I: Integer;
begin
  for I := 0 to Pred(FPoolSize) do
    FLocks[I].Enter;
end;

procedure TLockPool.Leave(Index: Integer);
begin
  FLocks[CalcPoolIndex(Index)].Leave;
end;

procedure TLockPool.LeaveAll;
var
  I: Integer;
begin
  for I := Pred(FPoolSize) downto 0 do
    FLocks[I].Leave;
end;

end.
