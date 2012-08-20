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
// $Version:0.6.2$ $Revision:1.5.1.1$ $Author:masroore$ $RevDate:10/29/2007 14:03:12$
//
////////////////////////////////////////////////////////////////////////////////

unit HashTable;

interface

uses
  SysUtils;

{$I NITROHTTPD.INC} 

type
  PHashNode = ^THashNode;
  THashNode = record
    Key: string;
    Data: Pointer;
    Next: PHashNode;
  end;
  THashTable = array of PHashNode;
  THashFindCallback = function(Item: Pointer): Boolean;
  THashClearCallback = procedure(Item: Pointer);
  THashPurgeCallback = function(Item: Pointer; Param: LongInt): Boolean;

function HashInsert(HashTable: THashTable; const AKey: string; const AHash: Cardinal; const AData: Pointer): PHashNode;
function HashInsertEx(HashTable: THashTable; const AKey: string; const AHash: Cardinal; const AData: Pointer; CallBack: THashFindCallback): PHashNode;
function HashFind(HashTable: THashTable; const AKey: string; const AHash: Cardinal): PHashNode;
function HashFindEx(HashTable: THashTable; const AKey: string; const AHash: Cardinal; CallBack: THashFindCallback): PHashNode;
function HashGetItemsCount(HashTable: THashTable; const Size: Integer): Integer;
procedure HashIterate(HashTable: THashTable; const Size: Integer; CallBack: THashFindCallback);
procedure HashClear(HashTable: THashTable; const Size: Integer; CallBack: THashClearCallback);
procedure HashPurge(HashTable: THashTable; const Size: Integer; const Param: LongInt; CallBack: THashPurgeCallback);

// Paul Hsieh's fast hash function. Pascal translation by Dr. Masroor Ehsan
// More info: http://www.azillionmonkeys.com/qed/hash.html
function SuperFastHash(const str: PAnsiChar; len: Integer): Cardinal;
  {$IFDEF HASH_CPP_VER} external; {$ENDIF}


{
  Based on analysis by D. Knuth, the following prime numbers are good
  choices for HashTableSize:
      59 61 67 71 73 127 131 137 191 193 197 199 251 257 263 311 313
   317 379 383 389 439 443 449 457 503 509 521 569 571 577 631 641
   643 647 701 709 761 769 773 823 827 829 839 887 953 967
}
const
  DEFAULT_HASHTABLE_SIZE    = 509;

implementation

function HashInsert(HashTable: THashTable; const AKey: string; const AHash: Cardinal; const AData: Pointer): PHashNode;
var
  Curr, Trailer: PHashNode;
begin
  Result := nil;
  if AKey = '' then
    Exit;

  Curr := HashTable[AHash];
  while Curr <> nil do
  begin
    if CompareStr(Curr^.Key, AKey) = 0 then
    begin
      // Don't add duplicate items
      Result := Curr;
      Exit;
    end;

    if Curr^.Next <> nil then
      Curr := Curr^.Next
    else
      Break;
  end;

  // Not found
  Trailer := AllocMem(SizeOf(THashNode));
  with Trailer^ do
  begin
    Key   := AKey;
    Data  := AData;
    Next  := nil;
  end;

  if Curr = nil then
    HashTable[AHash] := Trailer    // no entries for this hash value
  else
    Curr^.Next := Trailer;

  Result := Trailer;
end;

function HashInsertEx(HashTable: THashTable; const AKey: string; const AHash: Cardinal; const AData: Pointer; CallBack: THashFindCallback): PHashNode;
var
  Curr, Trailer: PHashNode;
begin
  Result := nil;
  if AKey = '' then
    Exit;

  Curr := HashTable[AHash];
  while Curr <> nil do
  begin
    if (CompareStr(Curr^.Key, AKey) = 0) and  CallBack(Curr^.Data) then
    begin
      // Don't add duplicate items
      Result := Curr;
      Exit;
    end;

    if Curr^.Next <> nil then
      Curr := Curr^.Next
    else
      Break;
  end;

  // Not found
  Trailer := AllocMem(SizeOf(THashNode));
  with Trailer^ do
  begin
    Key   := AKey;
    Data  := AData;
    Next  := nil;
  end;

  if Curr = nil then
    HashTable[AHash] := Trailer    // no entries for this hash value
  else
    Curr^.Next := Trailer;

  Result := Trailer;
end;

function HashFind(HashTable: THashTable; const AKey: string; const AHash: Cardinal): PHashNode;
var
  Curr: PHashNode;
begin
  Result := nil;

  Curr := HashTable[AHash];
  while Curr <> nil do
  begin
    if CompareStr(Curr^.Key, AKey) = 0 then
    begin
      Result := Curr;
      Break;
    end;
    Curr := Curr^.Next;
  end;
end;

function HashFindEx(HashTable: THashTable; const AKey: string; const AHash: Cardinal; CallBack: THashFindCallback): PHashNode;
var
  Curr: PHashNode;
begin
  Result := nil;

  Curr := HashTable[AHash];
  while Curr <> nil do
  begin
    if (CompareStr(Curr^.Key, AKey) = 0) and CallBack(Curr^.Data) then
    begin
      Result := Curr;
      Break;
    end;
    Curr := Curr^.Next;
  end;
end;

function HashGetItemsCount(HashTable: THashTable; const Size: Integer): Integer;
var
  I: Integer;
  Curr: PHashNode;
begin
  Result := 0;

  for I := 0 to Pred(Size) do
  begin
    Curr := HashTable[I];

    while Curr <> nil do
    begin
      Inc(Result);
      Curr := Curr^.Next;
    end;
  end;
end;

procedure HashIterate(HashTable: THashTable; const Size: Integer; CallBack: THashFindCallback);
var
  I: Integer;
  Temp: PHashNode;
begin
  if Assigned(CallBack) then
  begin
    for I := 0 to Pred(Size) do
    begin
      Temp := HashTable[I];
      while Temp <> nil do
      begin
        CallBack(Temp^.Data);

        Temp := Temp^.Next;
      end;
    end;
  end;
end;

procedure HashClear(HashTable: THashTable; const Size: Integer; CallBack: THashClearCallback);
var
  I: Integer;
  Temp, Next: PHashNode;
begin
  for I := 0 to Pred(Size) do
  begin
    Temp := HashTable[I];
    while Temp <> nil do
    begin
      Next := Temp^.Next;
      SetLength(Temp^.Key, 0);
      if Assigned(CallBack) then
        CallBack(Temp^.Data)
      else
        Dispose(Temp^.Data);
      FreeMem(Temp);
      Temp := Next;
    end;
    HashTable[I] := nil;
  end;
end;

procedure HashPurge(HashTable: THashTable; const Size: Integer; const Param: LongInt; CallBack: THashPurgeCallback);
var
  I: Integer;
  Temp, Next: PHashNode;
begin
  if not Assigned(CallBack) then
    Exit;

  for I := 0 to Pred(Size) do
  begin
    Temp := HashTable[I];
    while (Temp <> nil) do
    begin
      Next := Temp^.Next;
      if CallBack(Temp^.Data, Param) then
      begin
        if Temp = HashTable[I] then
          HashTable[I] := Next;

        SetLength(Temp^.Key, 0);
        FreeMem(Temp);
      end;
      Temp := Next;
    end;
  end;
end;


{$IFDEF HASH_CPP_VER}
(* By Paul Hsieh (C) 2004, 2005.  Covered under the Paul Hsieh derivative
   license. See:
   http://www.azillionmonkeys.com/qed/weblicense.html for license details.
   http://www.azillionmonkeys.com/qed/hash.html *)

{$L OBJ\HASH.OBJ}

{$ENDIF}

{$IFDEF HASH_PAS_VER}

(*
  Pascal port by:
*)

function SuperFastHash(const str: PAnsiChar; len: Integer): Cardinal;
var
  pw: PWORD;
  tmp: Cardinal;
  rem: Integer;
  data: PAnsiChar;
begin
  Result := 0;
  if (len <= 0) or (str = nil) then
  begin
    Exit;
  end;

  pw  := PWord(str);
  rem := len and 3;
  len := len shr 2;

  while (len > 0) do
  begin
    Inc(Result, pw^);

    {
    tmp    := (PWord(Integer(pw)+ SizeOf(Word))^ SHL 11) xor Result;
    Result := (Result SHL 16) XOR tmp;
    Inc(pw, 2);
    }

    Inc(pw);
    tmp    := (pw^ SHL 11) xor Result;
    Inc(pw);
    Result := (Result SHL 16) XOR tmp;

    Result := Result + (Result shr 11);
    Dec(len);
  end;

  if (rem = 3) then
  begin
    Result := Result + pw^;
    Result := Result XOR (Result SHL 16);

    Inc(pw);
    Result := Result XOR (PByte(pw)^ SHL 18);

    //Result := Result XOR (Ord(PByte(Integer(pw)+ SizeOf(Word))^) SHL 18);
    Result := Result + (Result SHR 11);
  end
  else if (rem = 2) then
  begin
    Result := Result + pw^;
    Result := Result XOR (Result SHL 11);
    Result := Result + (Result SHR 17);
  end
  else if (rem = 1) then
  begin
    Result := Result + Ord(PByte(pw)^);
    Result := Result XOR (Result SHL 10);
    Result := Result + (Result SHR 1);
  end;

  Result := Result XOR (Result SHL 3);
  Result := Result + (Result SHR 5);

  Result := Result XOR (Result SHL 4);
  Result := Result + (Result SHR 17);

  Result := Result XOR (Result SHL 25);
  Result := Result + (Result SHR 6);
end;

{$ENDIF}

{$IFDEF HASH_ASM_VER}

function SuperFastHash(const str: PAnsiChar; len: Integer): Cardinal;
asm
    push  esi
    push  edi
    test  eax, eax // data
    jz    @Ret // eax is result
    xchg  edx, eax // swith data and length
    test  eax, eax // length, and hash
    jle   @Ret

@Start:
    mov   edi, eax  // remainer
    mov   esi, eax  // max
    and   edi, 3    // remainer
    shr   esi, 2    // number of loops
    jz    @Last3
    xor   eax, eax

@Loop:
    movzx ecx, word ptr [edx]
    add   eax, ecx
    movzx ecx, word ptr [edx + 2]

    shl   ecx, 11
    xor   ecx, eax
    shl   eax, 16

    xor   eax, ecx
    mov   ecx, eax

    shr   eax, 11
    add   eax, ecx
    add   edx, 4    
    dec   esi
    jnz   @Loop
@Last3:
    test  edi, edi
    jz    @Done
    dec   edi
    jz    @OneLeft
    dec   edi
    jz    @TwoLeft

    movzx ecx, word ptr [edx]
    add   eax, ecx
    mov   ecx, eax
    shl   eax, 16
    xor   eax, ecx
    movsx ecx, byte ptr [edx + 2]
    shl   ecx, 18
    xor   eax, ecx
    mov   ecx, eax
    shr   ecx, 11
    add   eax, ecx
    jmp   @Done
@TwoLeft:
    movzx ecx, word ptr [edx]
    add   eax, ecx
    mov   ecx, eax
    shl   eax, 11
    xor   eax, ecx
    mov   ecx, eax
    shr   eax, 17
    add   eax, ecx
    jmp   @Done
@OneLeft:
    movsx ecx, byte ptr [edx]
    add   eax, ecx
    mov   ecx, eax
    shl   eax, 10
    xor   eax, ecx
    mov   ecx, eax
    shr   eax, 1
    add   eax, ecx
@Done:
    // avalanche
    mov   ecx, eax
    shl   eax, 3
    xor   eax, ecx

    mov   ecx, eax
    shr   eax, 5
    add   eax, ecx

    mov   ecx, eax
    shl   eax, 4
    xor   eax, ecx

    mov   ecx, eax
    shr   eax, 17
    add   eax, ecx

    mov   ecx, eax
    shl   eax, 25
    xor   eax, ecx

    mov   ecx, eax
    shr   eax, 6
    add   eax, ecx
@Ret:
    pop   edi
    pop   esi
    ret
end;

{$ENDIF}

end.
