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
// $Version:0.6.1$ $Revision:1.4$ $Author:masroore$ $RevDate:9/18/2007 14:36:52$
//
////////////////////////////////////////////////////////////////////////////////

// /////////////////////////////////////////////////////////////////////////////
//
// Purpose      : Debug routines.
//                You must have either Raize CodeSite or GuRock SmartInspect
//                to compile this unit.
//                Jedi Code Library is also required
// Author       : Masroor Ehsan Choudhury
// Unit created : 28-06-2002
// Changelog    :
//   DDMMYYYY AUT   VER    DESCRIPTION
//   28062002 MEC   0.0.1  Unit created
//   03112002 MEC          Ported code to ModelMaker
//   28102003 MEC          Adopted for WordSmart project
//   01032007 MEC          SmartInspect support added.
//
// /////////////////////////////////////////////////////////////////////////////

unit uDebug;

interface

{$I NITROHTTPD.INC}

uses
  JclDebug,
{$IFDEF CODESITE}
  CSIntf,
{$ELSE}
  SiAuto, //SmartInspect,
{$ENDIF}
{$IFDEF TRACK_SOCKET_SESSION}
  Graphics,
  SmartInspect,
{$ENDIF}
  SysUtils,
  Windows;

{$IFNDEF XBUG}
  ERROR! You must define XBUG to compile this unit.
{$ENDIF}

// This unit facilitates sending debug information to Ray Konopka's
// CodeSite viewer.
// Please note that the original author of this unit (Masroor Ehsan) is in
// no way affiliated with Raize Software and neither is he trying to
// promote the product (by the way, if you don't use CodeSite, you may want
// to give this excellent product a try). CodeSite is merely used here
// because the author uses this product in his projects.
// TODO: Replace CodeSite with our own debug log viewer.
//
// Format of debug messages:
//   [<UNIT NAME>-<PROCEDURE NAME>:<LINE NUMBER>] <DEBUG MESSAGE>
// e.g.:
//   [Unit1.pas-Button1Click:400] Button was clicked!



// Use this function to send informational messages to the debug viewer.

procedure INFO(Sock: Integer; Msg: string; const Level: Integer = 1); overload;
procedure INFO(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer = 1); overload;

{$IFDEF TRACK_SOCKET_SESSION}
procedure XINFO(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
{$ENDIF}


// Sends a warning message to the debug viewer.

procedure WARNING(Sock: Integer; Msg: string; const Level: Integer = 1); overload;
procedure WARNING(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer =
        1); overload;
{$IFDEF TRACK_SOCKET_SESSION}
procedure XWARNING(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
{$ENDIF}

// Sends an error message to the debug viewer.

procedure ERROR(Sock: Integer; Msg: string; const Level: Integer = 1); overload;
procedure ERROR(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer = 1);
        overload;
{$IFDEF TRACK_SOCKET_SESSION}
procedure XERROR(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
{$ENDIF}

// Use these methods when entering/exiting any procedures/functions.
// METHODENTER instructs the CodeSite Viewer to indent all messages that
// follow until a corresponding METHODEXIT is called. By calling METHODENTER
// at the beginning of a method and METHODEXIT at the end, your message log
// will reflect the control flow of your application and will also enable
// Call Stack tracking in the CodeSite Viewer.

procedure METHODENTER;
procedure METHODEXIT;

// Use DUMP to send the contents of the Buffer parameter to the debug
// viewer. The bytes referenced by the Buffer pointer are formatted in a
// typical hex-view format.  You must specify the size of the buffer in the
// Size parameter.  This method is useful for inspecting the bytes of a memory
// block. For example, the following is a typical 8 byte-value column hex view:
//
// 00000000: 8B 14 1F F2 34 82 00 00  | ‹..ò4‚..
// 00000008: 6C 7D 3D 2A 00 00 00 00  | l}=*....
// 00000010: 00 96 00 3C 70 0C 54 65  | .-.<p.Te
// 00000018: 73 74 4D 61 69 6E 2E 70  | stMain.p
// 00000020: 61 73 DB 72 3D 2A 00 72  | asÛr=*.r
// 00000028: 0C 54 65 73 74 4D 61 69  | .TestMai
// 00000030: 6E 2E 44 46 4D AE 1B 3D  | n.DFM®.=
// 00000038: 2A 02 64 08 43 6F 6D 43  | *.d.ComC

procedure DUMP(Buffer: Pointer; Length: Integer; const Level: Integer = 1);
        overload;
procedure DUMP(Msg: string; Buffer: Pointer; Length: Integer; const Level:
        Integer = 1); overload;
procedure DUMP(Msg: string; Buffer: Pointer; Length, HexWidth: Integer; const
        Level: Integer = 1); overload;

procedure TRACKMETHOD;

{$IFDEF TRACK_SOCKET_SESSION}
function GetNextSessionColor: TColor;
{$ENDIF}


implementation

resourcestring
{$IFDEF CODESITE}
  SDebugFormat					= '[%s-%s:%4d (%4d:%4d)] %s';
{$ELSE}
  SDebugFormat					= '[%s-%s:%d (%d)] %s';
{$ENDIF}
  SDebugFormatMem				= '[%s-%s:%d]';

const
  HEX_VIEW_WIDTH = $08; //$10;

{$IFDEF CODESITE}
var
  CSObject : TCSObject;
{$ENDIF}

{$IFDEF TRACK_SOCKET_SESSION}
const
  SESSION_COLORS: array [1..15] of TColor =
  (
    $0080FFFF, $0080FF80, $00FFFFC1,
    $00C080FF, $00C1FFC1, $00FF8080,
    $0000DDDD, $00C3C3C3, $008585C2,
    $00FF0080, $007DA8FF, $00FFBE7D,
    clSilver,     clTeal,       clYellow
  );

var
  CurrColor: Integer = 0;

function GetNextSessionColor: TColor;
begin
  Inc(CurrColor);
  if CurrColor > 15 then
    CurrColor := 1;
  Result := SESSION_COLORS[CurrColor];
end;
{$ENDIF}


procedure INFO(Sock: Integer; Msg: string; const Level: Integer);
begin
{$IFDEF CODESITE}
  CSObject.SendMsg(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          Msg]));
{$ELSE}
  SiMain.LogMessage(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
{$ENDIF}
end;

{$IFDEF TRACK_SOCKET_SESSION}
procedure XINFO(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
begin
  TSiSession(Session).LogMessage(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
end;
{$ENDIF}


procedure INFO(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer);
var
  sMsg: string;
begin
  sMsg := Format(MsgFmt, Args);

{$IFDEF CODESITE}
  CSObject.SendMsg(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          sMsg]));
{$ELSE}
  SiMain.LogMessage(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          sMsg]));
{$ENDIF}
end;

procedure WARNING(Sock: Integer; Msg: string; const Level: Integer);
begin
{$IFDEF CODESITE}
  CSObject.SendWarning(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          Msg]));
{$ELSE}
  SiMain.LogWarning(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
{$ENDIF}
end;

procedure WARNING(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer);
var
  sMsg: string;
begin
  sMsg := Format(MsgFmt, Args);
{$IFDEF CODESITE}
  CSObject.SendWarning(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          sMsg]));
{$ELSE}
  SiMain.LogWarning(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          sMsg]));
{$ENDIF}
end;

{$IFDEF TRACK_SOCKET_SESSION}
procedure XWARNING(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
begin
  TSiSession(Session).LogWarning(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
end;
{$ENDIF}


procedure ERROR(Sock: Integer; Msg: string; const Level: Integer);
begin
{$IFDEF CODESITE}
  CSObject.SendError(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          Msg]));
{$ELSE}
  SiMain.LogError(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
{$ENDIF}
end;

procedure ERROR(Sock: Integer; MsgFmt: string; Args: array of const; const Level: Integer);
var
  sMsg: string;
begin
  sMsg := Format(MsgFmt, Args);
{$IFDEF CODESITE}
  CSObject.SendError(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Integer(GetCurrentThreadID),
                                          Sock,
                                          sMsg]));
{$ELSE}
  SiMain.LogError(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          sMsg]));
{$ENDIF}
end;

{$IFDEF TRACK_SOCKET_SESSION}
procedure XERROR(Session, Sock: Integer; Msg: string; const Level: Integer = 1);
begin
  TSiSession(Session).LogError(Format( SDebugFormat, [__MODULE__(Level),
                                          __PROC__(Level),
                                          __LINE__(Level),
                                          Sock,
                                          Msg]));
end;
{$ENDIF}


procedure METHODENTER;
begin
{$IFDEF CODESITE}
  CSObject.EnterMethod(__MODULE__(1) + ':' + __PROC__(1));
{$ELSE}
  SiMain.EnterMethod(__MODULE__(1) + ':' + __PROC__(1));
{$ENDIF}
end;

procedure METHODEXIT;
begin
{$IFDEF CODESITE}
  CSObject.ExitMethod(__MODULE__(1) + ':' + __PROC__(1));
{$ELSE}
  SiMain.LeaveMethod(__MODULE__(1) + ':' + __PROC__(1));
{$ENDIF}
end;

procedure DUMP(Buffer: Pointer; Length: Integer; const Level: Integer);
begin
{$IFDEF CODESITE}
  CSObject.SendMemoryAsHex(Format( SDebugFormatMem,
                                   [__MODULE__(Level),
                                    __PROC__(Level),
                                    __LINE__(Level)]),
                                    Buffer,
                                    Length);
{$ENDIF}
end;

procedure DUMP(Msg: string; Buffer: Pointer; Length: Integer; const Level:
        Integer);
begin
{$IFDEF CODESITE}
  CSObject.SendMemoryAsHex(Format( SDebugFormatMem, [__MODULE__(Level),
                                                 __PROC__(Level),
                                                 __LINE__(Level),
                                                 Msg]),
                                                 Buffer,
                                                 Length);
{$ENDIF}
end;

procedure DUMP(Msg: string; Buffer: Pointer; Length, HexWidth: Integer; const
        Level: Integer);
var
  OldWidth: Integer;
begin
{$IFDEF CODESITE}

  OldWidth := CSObject.HexViewWidth;
  CSObject.HexViewWidth := HexWidth;
  CSObject.SendMemoryAsHex(Format( SDebugFormatMem, [__MODULE__(Level),
                                                 __PROC__(Level),
                                                 __LINE__(Level),
                                                 Msg]),
                                                 Buffer,
                                                 Length);
  CSObject.HexViewWidth := OldWidth;
{$ENDIF}
end;

procedure TRACKMETHOD;
begin
{$IFNDEF CODESITE}
  SiMain.TrackMethod(__MODULE__(1) + ':' + __PROC__(1));
{$ENDIF}
end;  

initialization
{$IFDEF CODESITE}
  CSObject := TCSObject.Create(nil);
  CSObject.HexViewWidth := HEX_VIEW_WIDTH;
{$ELSE}
  Si.Enabled := True;
  Si.Connections := 'tcp(backlog=256KB, keepopen=true, flushon=warning)';
  SiMain.EnterProcess;
{$ENDIF}
finalization
{$IFDEF CODESITE}
  if Assigned(CSObject) then
     CSObject.Free;
  CSObject := nil;
{$ELSE}
  SiMain.LeaveProcess;
  Si.Enabled := False;
{$ENDIF}
end.
