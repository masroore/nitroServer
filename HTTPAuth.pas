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
// $Version:0.6.2$ $Revision:1.0$ $Author:masroore$ $RevDate:9/30/2007 21:37:42$
//
////////////////////////////////////////////////////////////////////////////////

unit HTTPAuth;

interface

uses
  SysUtils, Windows, Common;

function HTTPAuthBasic(Ctx: PClientContext): Boolean;

implementation

uses
  HashTable, FastLock, MD5;

type
  PUserRec = ^TUserRec;
  TUserRec = record
    UserName: string;
    Password: string;
    CkSum:    Cardinal;
  end;

const
  USERS_HASHTABLE_SIZE = 127;

var
  g_UserRecs: THashTable;
  g_Lock: TFastLock;

procedure InternalAddUserRec(const User, Pass: string; CkSum: Cardinal);
var
  P: PUserRec;
begin
  New(P);
  P^.UserName  := User;
  P^.Password  := Pass;
  P^.CkSum     := CkSum;

  HashInsert(g_UserRecs, User, CkSum, P);
end;

function InternalFindUserRec(const User: string; const Hash: Cardinal; var Info: PUserRec): Boolean;
var
  H: PHashNode;
begin
  Result := False;
  Info  := nil;

  H := HashFind(g_UserRecs, User, Hash);
  if Assigned(H) then
  begin
    Info  := PUserRec(H^.Data);
    Result := True;
  end;
end;

procedure ParseLine(Line: string);
var
  User, Pass: string;
  I, Len: Integer;
  ChkSum: Cardinal;
begin
  Line := Trim(Line);
  Len := Length(Line);

  if Len > 0 then
  begin
    I := FastCharPos(Line, ':');
    if I <> -1 then
    begin
      User := LowerCase(Trim(Copy(Line, 1, I - 1)));
      Pass := Trim(Copy(Line, I + 1, Len));

      if (User <> '') and (Pass <> '') then
      begin
        ChkSum  := SuperFastHash(PAnsiChar(User), Length(User)) mod USERS_HASHTABLE_SIZE;
        Pass    := MD5String(Pass);

        InternalAddUserRec(User, Pass, ChkSum);
      end;
    end;
  end;
end;

procedure ParsePasswordFile(const Data: PAnsiChar; const Len: Integer);
var
  P, Start: PAnsiChar;
  S: string;
begin
  P := Data;
  if P <> nil then
  begin
    while (P^ <> #0) do
    begin
      Start := P;
      while not (P^ in [#0, #10, #13]) do
        Inc(P);

      SetString(S, Start, P - Start);
      ParseLine(S);

      while (P^ in [#10, #13]) and (P^ <> #0) do
        Inc(P);
    end;
  end;
end;

procedure LoadUserRecs(const PasswordFile: string);
var
  Buffer: PAnsiChar;
  Size: Integer;
  Sz, Rd: DWORD;
  hFile: THandle;
  FileInfo: TByHandleFileInformation;
begin
  Buffer := nil;
  hFile := CreateFileA(PAnsiChar(PasswordFile),
                      GENERIC_READ,
                      0,
                      nil,
                      OPEN_EXISTING,
                      FILE_ATTRIBUTE_NORMAL or FILE_FLAG_SEQUENTIAL_SCAN,
                      0);

  if (hFile <> INVALID_HANDLE_VALUE) then
  begin
    if GetFileInformationByHandle(hFile, FileInfo) then
    begin
      if (FileInfo.nFileSizeLow > 0) then
      begin
        Size := FileInfo.nFileSizeLow;

        GetMem(Buffer, Size);

        Rd := 0;
        Sz := 0;
        SetFilePointer(hFile, 0, nil, FILE_BEGIN);

        repeat
          if not ReadFile(hFile, PAnsiChar(Integer(Buffer) + Sz)^, READ_BUFFER_SIZE, Rd, nil) then
            Break;

          Inc(Sz, Rd);
        until (Rd < READ_BUFFER_SIZE);
      end;
    end;
  end;

  CloseHandle(hFile);
  if (Buffer <> nil) then
  begin
    ParsePasswordFile(Buffer, Size);

    FreeMem(Buffer, Size);
  end;
end;

function GetPassword(UserName: string): string;
var
  Hash: Cardinal;
  P: PUserRec;
begin
  Result    := '';
  UserName := LowerCase(Trim(UserName));
  Hash      := SuperFastHash(PAnsiChar(UserName), Length(UserName)) mod USERS_HASHTABLE_SIZE;

  g_Lock.Enter;

  if InternalFindUserRec(UserName, Hash, P) then
    Result := P^.Password;

  g_Lock.Leave;
end;

procedure CBUserRecsDelete(Item: Pointer);
var
  P: PUserRec;
begin
  P := PUserRec(Item);

  SetLength(P^.UserName, 0);
  SetLength(P^.Password, 0);

  Dispose(P);
  P := nil;
end;

function HTTPAuthBasic(Ctx: PClientContext): Boolean;
var
  AUser, APass, Pass: string;
begin
  AUser   := Ctx.HTTPReq.AuthUser;
  APass   := MD5String(Trim(Ctx.HTTPReq.AuthPass));
  Pass    := GetPassword(AUser);
  Result  := CompareStr(Pass, Pass) = 0;
end;

initialization
  g_Lock := TFastLock.Create(0, False);
  SetLength(g_UserRecs, USERS_HASHTABLE_SIZE);
  LoadUserRecs('passwd.conf');

finalization
  HashClear(g_UserRecs, USERS_HASHTABLE_SIZE, CBUserRecsDelete);
  SetLength(g_UserRecs, 0);
  FreeAndNil(g_Lock);
end.
