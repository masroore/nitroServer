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

unit MD5;

interface

type
  PMD5_CTX = ^MD5_CTX;
  MD5_CTX = record
    Count:       Cardinal;
    DataBuffer:  packed array [0..127] of Byte;
    Digest:      packed array [0..63] of Byte;
  end;

procedure MD5_Init(var CTX: MD5_CTX);
procedure MD5_Update(var CTX: MD5_CTX; const Data; Count: Cardinal);
procedure MD5_Final(Digest: Pointer; var CTX: MD5_CTX);

function  MD5_DigestToString(CTX: MD5_CTX): String;

function MD5Print(CTX: MD5_CTX): string;
function  MD5_CalcDigest(const Data; Count: Cardinal): String;
function  MD5String(Str: string): String;

implementation

const
  MD5_DIGEST_SIZE = 16;

procedure MD5_Init(var CTX: MD5_CTX);

  procedure InitDigest(var CTX: MD5_CTX);
  asm
    lea EDX,dword ptr CTX.Digest;
    mov dword [EDX     ],$67452301;
    mov dword [EDX +  4],$EFCDAB89;
    mov dword [EDX +  8],$98BADCFE;
    mov dword [EDX + 12],$10325476;
  end;

begin
  FillChar(CTX, SizeOf(CTX), $00);
  InitDigest(CTX);
end;

procedure Calc(CTX: MD5_CTX); 
asm
  push EBX
  push ESI
  push EDI
  push EBP

  lea EBP,dword ptr CTX.DataBuffer;

// Copy Digest to state:
  push EAX
  lea ESI,dword ptr CTX.Digest;
  mov EAX,[ESI]
  mov EBX,[ESI + 4]
  mov ECX,[ESI + 8]
  mov EDX,[ESI + 12]

// Compress:
//  Inc(A, Buffer[ 0] + $D76AA478 + (D xor (B and (C xor D)))); A := A rol  7 + B;
  mov ESI,[EBP]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EBX
  xor EDI,EDX
  add EAX,ESI
  lea EAX,[EAX + EDI + $D76AA478]
  ror EAX,25
  add EAX,EBX
//  Inc(D, Buffer[ 1] + $E8C7B756 + (C xor (A and (B xor C)))); D := D rol 12 + A;
  mov ESI,[EBP + 4]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EAX
  xor EDI,ECX
  add EDX,ESI
  lea EDX,[EDX + EDI + $E8C7B756]
  ror EDX,20
  add EDX,EAX
//  Inc(C, Buffer[ 2] + $242070DB + (B xor (D and (A xor B)))); C := C rol 17 + D;
  mov ESI,[EBP + 8]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,EDX
  xor EDI,EBX
  add ECX,ESI
  lea ECX,[ECX + EDI + $242070DB]
  ror ECX,15
  add ECX,EDX
//  Inc(B, Buffer[ 3] + $C1BDCEEE + (A xor (C and (D xor A)))); B := B rol 22 + C;
  mov ESI,[EBP + 12]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,ECX
  xor EDI,EAX
  add EBX,ESI
  lea EBX,[EBX + EDI + $C1BDCEEE]
  ror EBX,10
  add EBX,ECX
//  Inc(A, Buffer[ 4] + $F57C0FAF + (D xor (B and (C xor D)))); A := A rol  7 + B;
  mov ESI,[EBP + 16]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EBX
  xor EDI,EDX
  add EAX,ESI
  lea EAX,[EAX + EDI + $F57C0FAF]
  ror EAX,25
  add EAX,EBX
//  Inc(D, Buffer[ 5] + $4787C62A + (C xor (A and (B xor C)))); D := D rol 12 + A;
  mov ESI,[EBP + 20]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EAX
  xor EDI,ECX
  add EDX,ESI
  lea EDX,[EDX + EDI + $4787C62A]
  ror EDX,20
  add EDX,EAX
//  Inc(C, Buffer[ 6] + $A8304613 + (B xor (D and (A xor B)))); C := C rol 17 + D;
  mov ESI,[EBP + 24]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,EDX
  xor EDI,EBX
  add ECX,ESI
  lea ECX,[ECX + EDI + $A8304613]
  ror ECX,15
  add ECX,EDX
//  Inc(B, Buffer[ 7] + $FD469501 + (A xor (C and (D xor A)))); B := B rol 22 + C;
  mov ESI,[EBP + 28]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,ECX
  xor EDI,EAX
  add EBX,ESI
  lea EBX,[EBX + EDI + $FD469501]
  ror EBX,10
  add EBX,ECX
//  Inc(A, Buffer[ 8] + $698098D8 + (D xor (B and (C xor D)))); A := A rol  7 + B;
  mov ESI,[EBP + 32]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EBX
  xor EDI,EDX
  add EAX,ESI
  lea EAX,[EDI + EAX + $698098D8]
  ror EAX,25
  add EAX,EBX
//  Inc(D, Buffer[ 9] + $8B44F7AF + (C xor (A and (B xor C)))); D := D rol 12 + A;
  mov ESI,[EBP + 36]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EAX
  xor EDI,ECX
  add EDX,ESI
  lea EDX,[EDI + EDX + $8B44F7AF]
  ror EDX,20
  add EDX,EAX
//  Inc(C, Buffer[10] + $FFFF5BB1 + (B xor (D and (A xor B)))); C := C rol 17 + D;
  mov ESI,[EBP + 40]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,EDX
  xor EDI,EBX
  add ECX,ESI
  lea ECX,[EDI + ECX + $FFFF5BB1]
  ror ECX,15
  add ECX,EDX
//  Inc(B, Buffer[11] + $895CD7BE + (A xor (C and (D xor A)))); B := B rol 22 + C;
  mov ESI,[EBP + 44]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,ECX
  xor EDI,EAX
  add EBX,ESI
  lea EBX,[EDI + EBX + $895CD7BE]
  ror EBX,10
  add EBX,ECX
//  Inc(A, Buffer[12] + $6B901122 + (D xor (B and (C xor D)))); A := A rol  7 + B;
  mov ESI,[EBP + 48]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EBX
  xor EDI,EDX
  add EAX,ESI
  lea EAX,[EDI + EAX + $6B901122]
  ror EAX,25
  add EAX,EBX
//  Inc(D, Buffer[13] + $FD987193 + (C xor (A and (B xor C)))); D := D rol 12 + A;
  mov ESI,[EBP + 52]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EAX
  xor EDI,ECX
  add EDX,ESI
  lea EDX,[EDI + EDX + $FD987193]
  ror EDX,20
  add EDX,EAX
//  Inc(C, Buffer[14] + $A679438E + (B xor (D and (A xor B)))); C := C rol 17 + D;
  mov ESI,[EBP + 56]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,EDX
  xor EDI,EBX
  add ECX,ESI
  lea ECX,[EDI + ECX + $A679438E]
  ror ECX,15
  add ECX,EDX
//  Inc(B, Buffer[15] + $49B40821 + (A xor (C and (D xor A)))); B := B rol 22 + C;
  mov ESI,[EBP + 60]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,ECX
  xor EDI,EAX
  add EBX,ESI
  lea EBX,[EDI + EBX + $49B40821]
  ror EBX,10
  add EBX,ECX

//  Inc(A, Buffer[ 1] + $F61E2562 + (C xor (D and (B xor C)))); A := A rol  5 + B;
  mov ESI,[EBP + 4]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  lea EAX,[EDI + EAX + $F61E2562]
  rol EAX,5
  add EAX,EBX
//  Inc(D, Buffer[ 6] + $C040B340 + (B xor (C and (A xor B)))); D := D rol  9 + A;
  mov ESI,[EBP + 24]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  lea EDX,[EDI + EDX + $C040B340]
  rol EDX,9
  add EDX,EAX
//  Inc(C, Buffer[11] + $265E5A51 + (A xor (B and (D xor A)))); C := C rol 14 + D;
  mov ESI,[EBP + 44]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  lea ECX,[EDI + ECX + $265E5A51]
  rol ECX,14
  add ECX,EDX
//  Inc(B, Buffer[ 0] + $E9B6C7AA + (D xor (A and (C xor D)))); B := B rol 20 + C;
  mov ESI,[EBP]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  lea EBX,[EDI + EBX + $E9B6C7AA]
  rol EBX,20
  add EBX,ECX
//  Inc(A, Buffer[ 5] + $D62F105D + (C xor (D and (B xor C)))); A := A rol  5 + B;
  mov ESI,[EBP + 20]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  lea EAX,[EDI + EAX + $D62F105D]
  rol EAX,5
  add EAX,EBX
//  Inc(D, Buffer[10] + $02441453 + (B xor (C and (A xor B)))); D := D rol  9 + A;
  mov ESI,[EBP + 40]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  lea EDX,[EDI + EDX + $02441453]
  rol EDX,9
  add EDX,EAX
//  Inc(C, Buffer[15] + $D8A1E681 + (A xor (B and (D xor A)))); C := C rol 14 + D;
  mov ESI,[EBP + 60]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  lea ECX,[EDI + ECX + $D8A1E681]
  rol ECX,14
  add ECX,EDX
//  Inc(B, Buffer[ 4] + $E7D3FBC8 + (D xor (A and (C xor D)))); B := B rol 20 + C;
  mov ESI,[EBP + 16]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  lea EBX,[EDI + EBX + $E7D3FBC8]
  rol EBX,20
  add EBX,ECX
//  Inc(A, Buffer[ 9] + $21E1CDE6 + (C xor (D and (B xor C)))); A := A rol  5 + B;
  mov ESI,[EBP + 36]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  lea EAX,[EDI + EAX + $21E1CDE6]
  rol EAX,5
  add EAX,EBX
//  Inc(D, Buffer[14] + $C33707D6 + (B xor (C and (A xor B)))); D := D rol  9 + A;
  mov ESI,[EBP + 56]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  lea EDX,[EDI + EDX + $C33707D6]
  rol EDX,9
  add EDX,EAX
//  Inc(C, Buffer[ 3] + $F4D50D87 + (A xor (B and (D xor A)))); C := C rol 14 + D;
  mov ESI,[EBP + 12]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  lea ECX,[EDI + ECX + $F4D50D87]
  rol ECX,14
  add ECX,EDX
//  Inc(B, Buffer[ 8] + $455A14ED + (D xor (A and (C xor D)))); B := B rol 20 + C;
  mov ESI,[EBP + 32]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  lea EBX,[EDI + EBX + $455A14ED]
  rol EBX,20
  add EBX,ECX
//  Inc(A, Buffer[13] + $A9E3E905 + (C xor (D and (B xor C)))); A := A rol  5 + B;
  mov ESI,[EBP + 52]
  mov EDI,ECX
  xor EDI,EBX
  and EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  lea EAX,[EDI + EAX + $A9E3E905]
  rol EAX,5
  add EAX,EBX
//  Inc(D, Buffer[ 2] + $FCEFA3F8 + (B xor (C and (A xor B)))); D := D rol  9 + A;
  mov ESI,[EBP + 8]
  mov EDI,EBX
  xor EDI,EAX
  and EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  lea EDX,[EDI + EDX + $FCEFA3F8]
  rol EDX,9
  add EDX,EAX
//  Inc(C, Buffer[ 7] + $676F02D9 + (A xor (B and (D xor A)))); C := C rol 14 + D;
  mov ESI,[EBP + 28]
  mov EDI,EAX
  xor EDI,EDX
  and EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  lea ECX,[EDI + ECX + $676F02D9]
  rol ECX,14
  add ECX,EDX
//  Inc(B, Buffer[12] + $8D2A4C8A + (D xor (A and (C xor D)))); B := B rol 20 + C;
  mov ESI,[EBP + 48]
  mov EDI,EDX
  xor EDI,ECX
  and EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  lea EBX,[EDI + EBX + $8D2A4C8A]
  rol EBX,20
  add EBX,ECX

//  Inc(A, Buffer[ 5] + $FFFA3942 + (B xor C xor D)); A := A rol  4 + B;
  mov ESI,[EBP + 20]
  mov EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  xor EDI,EBX
  lea EAX,[EAX + EDI + $FFFA3942]
  rol EAX,4
  add EAX,EBX
//  Inc(D, Buffer[ 8] + $8771F681 + (A xor B xor C)); D := D rol 11 + A;
  mov ESI,[EBP + 32]
  mov EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  xor EDI,EAX
  lea EDX,[EDX + EDI + $8771F681]
  rol EDX,11
  add EDX,EAX
//  Inc(C, Buffer[11] + $6D9D6122 + (D xor A xor B)); C := C rol 16 + D;
  mov ESI,[EBP + 44]
  mov EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  xor EDI,EDX
  lea ECX,[ECX + EDI + $6D9D6122]
  rol ECX,16
  add ECX,EDX
//  Inc(B, Buffer[14] + $FDE5380C + (C xor D xor A)); B := B rol 23 + C;
  mov ESI,[EBP + 56]
  mov EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  xor EDI,ECX
  lea EBX,[EBX + EDI + $FDE5380C]
  rol EBX,23
  add EBX,ECX
//  Inc(A, Buffer[ 1] + $A4BEEA44 + (B xor C xor D)); A := A rol  4 + B;
  mov ESI,[EBP + 4]
  mov EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  xor EDI,EBX
  lea EAX,[EAX + EDI + $A4BEEA44]
  rol EAX,4
  add EAX,EBX
//  Inc(D, Buffer[ 4] + $4BDECFA9 + (A xor B xor C)); D := D rol 11 + A;
  mov ESI,[EBP + 16]
  mov EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  xor EDI,EAX
  lea EDX,[EDX + EDI + $4BDECFA9]
  rol EDX,11
  add EDX,EAX
//  Inc(C, Buffer[ 7] + $F6BB4B60 + (D xor A xor B)); C := C rol 16 + D;
  mov ESI,[EBP + 28]
  mov EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  xor EDI,EDX
  lea ECX,[ECX + EDI + $F6BB4B60]
  rol ECX,16
  add ECX,EDX
//  Inc(B, Buffer[10] + $BEBFBC70 + (C xor D xor A)); B := B rol 23 + C;
  mov ESI,[EBP + 40]
  mov EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  xor EDI,ECX
  lea EBX,[EBX + EDI + $BEBFBC70]
  rol EBX,23
  add EBX,ECX
//  Inc(A, Buffer[13] + $289B7EC6 + (B xor C xor D)); A := A rol  4 + B;
  mov ESI,[EBP + 52]
  mov EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  xor EDI,EBX
  lea EAX,[EAX + EDI + $289B7EC6]
  rol EAX,4
  add EAX,EBX
//  Inc(D, Buffer[ 0] + $EAA127FA + (A xor B xor C)); D := D rol 11 + A;
  mov ESI,[EBP]
  mov EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  xor EDI,EAX
  lea EDX,[EDX + EDI + $EAA127FA]
  rol EDX,11
  add EDX,EAX
//  Inc(C, Buffer[ 3] + $D4EF3085 + (D xor A xor B)); C := C rol 16 + D;
  mov ESI,[EBP + 12]
  mov EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  xor EDI,EDX
  lea ECX,[ECX + EDI + $D4EF3085]
  rol ECX,16
  add ECX,EDX
//  Inc(B, Buffer[ 6] + $04881D05 + (C xor D xor A)); B := B rol 23 + C;
  mov ESI,[EBP + 24]
  mov EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  xor EDI,ECX
  lea EBX,[EBX + EDI + $04881D05]
  rol EBX,23
  add EBX,ECX
//  Inc(A, Buffer[ 9] + $D9D4D039 + (B xor C xor D)); A := A rol  4 + B;
  mov ESI,[EBP + 36]
  mov EDI,EDX
  xor EDI,ECX
  add EAX,ESI
  xor EDI,EBX
  lea EAX,[EAX + EDI + $D9D4D039]
  rol EAX,4
  add EAX,EBX
//  Inc(D, Buffer[12] + $E6DB99E5 + (A xor B xor C)); D := D rol 11 + A;
  mov ESI,[EBP + 48]
  mov EDI,ECX
  xor EDI,EBX
  add EDX,ESI
  xor EDI,EAX
  lea EDX,[EDX + EDI + $E6DB99E5]
  rol EDX,11
  add EDX,EAX
//  Inc(C, Buffer[15] + $1FA27CF8 + (D xor A xor B)); C := C rol 16 + D;
  mov ESI,[EBP + 60]
  mov EDI,EBX
  xor EDI,EAX
  add ECX,ESI
  xor EDI,EDX
  lea ECX,[ECX + EDI + $1FA27CF8]
  rol ECX,16
  add ECX,EDX
//  Inc(B, Buffer[ 2] + $C4AC5665 + (C xor D xor A)); B := B rol 23 + C;
  mov ESI,[EBP + 8]
  mov EDI,EAX
  xor EDI,EDX
  add EBX,ESI
  xor EDI,ECX
  lea EBX,[EBX + EDI + $C4AC5665]
  rol EBX,23
  add EBX,ECX

//  Inc(A, Buffer[ 0] + $F4292244 + (C xor (B or not D))); A := A rol  6 + B;
  mov ESI,[EBP]
  mov EDI,EDX
  not EDI
  or  EDI,EBX
  add EAX,ESI
  xor EDI,ECX
  lea EAX,[EAX + EDI + $F4292244]
  rol EAX,6
  add EAX,EBX
//  Inc(D, Buffer[ 7] + $432AFF97 + (B xor (A or not C))); D := D rol 10 + A;
  mov ESI,[EBP + 28]
  mov EDI,ECX
  not EDI
  or  EDI,EAX
  add EDX,ESI
  xor EDI,EBX
  lea EDX,[EDX + EDI + $432AFF97]
  rol EDX,10
  add EDX,EAX
//  Inc(C, Buffer[14] + $AB9423A7 + (A xor (D or not B))); C := C rol 15 + D;
  mov ESI,[EBP + 56]
  mov EDI,EBX
  not EDI
  or  EDI,EDX
  add ECX,ESI
  xor EDI,EAX
  lea ECX,[ECX + EDI + $AB9423A7]
  rol ECX,15
  add ECX,EDX
//  Inc(B, Buffer[ 5] + $FC93A039 + (D xor (C or not A))); B := B rol 21 + C;
  mov ESI,[EBP + 20]
  mov EDI,EAX
  not EDI
  or  EDI,ECX
  add EBX,ESI
  xor EDI,EDX
  lea EBX,[EBX + EDI + $FC93A039]
  rol EBX,21
  add EBX,ECX
//  Inc(A, Buffer[12] + $655B59C3 + (C xor (B or not D))); A := A rol  6 + B;
  mov ESI,[EBP + 48]
  mov EDI,EDX
  not EDI
  or  EDI,EBX
  add EAX,ESI
  xor EDI,ECX
  lea EAX,[EAX + EDI + $655B59C3]
  rol EAX,6
  add EAX,EBX
//  Inc(D, Buffer[ 3] + $8F0CCC92 + (B xor (A or not C))); D := D rol 10 + A;
  mov ESI,[EBP + 12]
  mov EDI,ECX
  not EDI
  or  EDI,EAX
  add EDX,ESI
  xor EDI,EBX
  lea EDX,[EDX + EDI + $8F0CCC92]
  rol EDX,10
  add EDX,EAX
//  Inc(C, Buffer[10] + $FFEFF47D + (A xor (D or not B))); C := C rol 15 + D;
  mov ESI,[EBP + 40]
  mov EDI,EBX
  not EDI
  or  EDI,EDX
  add ECX,ESI
  xor EDI,EAX
  lea ECX,[ECX + EDI + $FFEFF47D]
  rol ECX,15
  add ECX,EDX
//  Inc(B, Buffer[ 1] + $85845DD1 + (D xor (C or not A))); B := B rol 21 + C;
  mov ESI,[EBP + 4]
  mov EDI,EAX
  not EDI
  or  EDI,ECX
  add EBX,ESI
  xor EDI,EDX
  lea EBX,[EBX + EDI + $85845DD1]
  rol EBX,21
  add EBX,ECX
//  Inc(A, Buffer[ 8] + $6FA87E4F + (C xor (B or not D))); A := A rol  6 + B;
  mov ESI,[EBP + 32]
  mov EDI,EDX
  not EDI
  or  EDI,EBX
  add EAX,ESI
  xor EDI,ECX
  lea EAX,[EAX + EDI + $6FA87E4F]
  rol EAX,6
  add EAX,EBX
//  Inc(D, Buffer[15] + $FE2CE6E0 + (B xor (A or not C))); D := D rol 10 + A;
  mov ESI,[EBP + 60]
  mov EDI,ECX
  not EDI
  or  EDI,EAX
  add EDX,ESI
  xor EDI,EBX
  lea EDX,[EDX + EDI + $FE2CE6E0]
  rol EDX,10
  add EDX,EAX
//  Inc(C, Buffer[ 6] + $A3014314 + (A xor (D or not B))); C := C rol 15 + D;
  mov ESI,[EBP + 24]
  mov EDI,EBX
  not EDI
  or  EDI,EDX
  add ECX,ESI
  xor EDI,EAX
  lea ECX,[ECX + EDI + $A3014314]
  rol ECX,15
  add ECX,EDX
//  Inc(B, Buffer[13] + $4E0811A1 + (D xor (C or not A))); B := B rol 21 + C;
  mov ESI,[EBP + 52]
  mov EDI,EAX
  not EDI
  or  EDI,ECX
  add EBX,ESI
  xor EDI,EDX
  lea EBX,[EBX + EDI + $4E0811A1]
  rol EBX,21
  add EBX,ECX
//  Inc(A, Buffer[ 4] + $F7537E82 + (C xor (B or not D))); A := A rol  6 + B;
  mov ESI,[EBP + 16]
  mov EDI,EDX
  not EDI
  or  EDI,EBX
  add EAX,ESI
  xor EDI,ECX
  lea EAX,[EAX + EDI + $F7537E82]
  rol EAX,6
  add EAX,EBX
//  Inc(D, Buffer[11] + $BD3AF235 + (B xor (A or not C))); D := D rol 10 + A;
  mov ESI,[EBP + 44]
  mov EDI,ECX
  not EDI
  or  EDI,EAX
  add EDX,ESI
  xor EDI,EBX
  lea EDX,[EDX + EDI + $BD3AF235]
  rol EDX,10
  add EDX,EAX
//  Inc(C, Buffer[ 2] + $2AD7D2BB + (A xor (D or not B))); C := C rol 15 + D;
  mov ESI,[EBP + 8]
  mov EDI,EBX
  not EDI
  or  EDI,EDX
  add ECX,ESI
  xor EDI,EAX
  lea ECX,[ECX + EDI + $2AD7D2BB]
  rol ECX,15
  add ECX,EDX
//  Inc(B, Buffer[ 9] + $EB86D391 + (D xor (C or not A))); B := B rol 21 + C;
  mov ESI,[EBP + 36]
  mov EDI,EAX
  not EDI
  or  EDI,ECX
  add EBX,ESI
  xor EDI,EDX
  lea EBX,[EBX + EDI + $EB86D391]
  rol EBX,21
  add EBX,ECX


// Add state to Digest:
  mov EBP,EAX
  pop EAX
  lea ESI,dword ptr CTX.Digest;
  mov EAX,[ESI]
  add EAX,EBP
  mov [ESI],EAX
  mov EAX,[ESI + 4]
  add EAX,EBX
  mov [ESI + 4],EAX
  mov EAX,[ESI + 8]
  add EAX,ECX
  mov [ESI + 8],EAX
  mov EAX,[ESI + 12]
  add EAX,EDX
  mov [ESI + 12],EAX

  pop EBP
  pop EDI
  pop ESI
  pop EBX
end;

procedure MD5_Update(var CTX: MD5_CTX; const Data; Count: Cardinal);
var
  I: Integer;
  P: Pointer;
begin
  P := @Data;
  I := CTX.Count and $3F;
  if I > 0 then
  begin
    if Count >= $40 - I then
    begin
      Move(P^, CTX.DataBuffer[I], $40 - I);
      Calc(CTX);
      Inc(LongInt(P),$40 - I);
      Inc(CTX.Count,$40 - I);
      Dec(Count, $40 - I);
    end
    else
    begin
      Move(P^,CTX.DataBuffer[I],Count);
      Inc(CTX.Count,Count);
      Count := 0;
    end;
  end;
  while Count >= $40 do
  begin
    Move(P^,CTX.DataBuffer,$40);
    Calc(CTX);
    Inc(LongInt(P),$40);
    Inc(CTX.Count,$40);
    Dec(Count,$40);
  end;
  if Count > 0 then
  begin
    Move(P^,CTX.DataBuffer,Count);
    Inc(CTX.Count,Count);
  end;
end;

procedure MD5_Final(Digest: Pointer; var CTX: MD5_CTX);
var
  I: Integer;
  S: Int64;
begin
  I := (CTX.Count and $3F);
  CTX.DataBuffer[I] := $80;
  Inc(I);
  if I > $38 then
  begin
    FillChar(CTX.DataBuffer[I], $40 - I, #0);
    Calc(CTX);
    I := 0;
  end;
  FillChar(CTX.DataBuffer[I],$40 - I,0);
  S := CTX.Count * 8;
  Move(S, CTX.DataBuffer[$38], 8);
  Calc(CTX);
  if Assigned(Digest) then
    Move(CTX.Digest, Digest^, MD5_DIGEST_SIZE);
  CTX.Count := 0;
end;

function MD5_DigestToString(CTX: MD5_CTX): String;
begin
  SetLength(Result, MD5_DIGEST_SIZE);
  Move(CTX.Digest, Result[1], MD5_DIGEST_SIZE);
end;

function MD5Print(CTX: MD5_CTX): string;
const
	HEX_DIGITS: array[0..15] of Char =
		('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'A', 'C', 'D', 'E', 'F');
var
	I: byte;
begin
  {
	Result := '';
	for I := 0 to Pred(MD5_DIGEST_SIZE) do
    Result  := Result + Digits[(CTX.Digest[I] shr 4) and $0f] + Digits[CTX.Digest[I] and $0f];
  }
  SetLength(Result, MD5_DIGEST_SIZE * 2);
	for I := 0 to Pred(MD5_DIGEST_SIZE) do
  begin
    Result[(I * 2) + 1]  := HEX_DIGITS[(CTX.Digest[I] SHR $04) AND $0F];
    Result[(I * 2) + 2]  := HEX_DIGITS[CTX.Digest[I] AND $0F];
  end;
end;

function MD5_CalcDigest(const Data; Count: Cardinal): String;
var
  Ctx: MD5_CTX;
begin
  MD5_Init(Ctx);
  MD5_Update(Ctx, Data, Count);
  MD5_Final(nil, Ctx);

  Result := MD5Print(Ctx);
end;

function  MD5String(Str: string): String;
var
  Ctx: MD5_CTX;
begin
  MD5_Init(Ctx);
  MD5_Update(Ctx, Str[1], Length(Str));
  MD5_Final(nil, Ctx);

  Result := MD5Print(Ctx);
end;

end.
