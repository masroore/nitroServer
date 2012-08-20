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
// $Version:0.6.2$ $Revision:1.1$ $Author:masroore$ $RevDate:9/30/2007 21:38:14$
//
////////////////////////////////////////////////////////////////////////////////

unit VHosts;

interface

{$I NITROHTTPD.INC}

uses
  SysUtils, Classes, XMLConfig, FastLock, VirtualDir, WinSock;

type
  TVirtualHost = class
  private
    FVHostName,
    FHostName: string;
    FChkSum: Cardinal;
{
    FListenIP: string;
    FListenPort: Word;
    FListenSocket: TSocket;
    FMaxClients: Integer;
}
    FRealm: string;
    FDocRoot: string;
    FLoggingDir: string;
    FVirtualDirs: TVirtualDirs;
  public
    constructor Create;
    destructor Destroy; override;

    function  ResolveRealPath(const AURL : String;
                              var Cache, DirList, ExecScript, Auth: Boolean) : String;

    procedure LoadConfig(XML: TXMLConfig; ItemIndex: Integer);
    procedure SaveConfig(XML: TXMLConfig; ItemIndex: Integer);
{
    procedure AcceptConnections;
}
    property VHostName: string read FVHostName;
    property HostName: string read FHostName;
    property Realm: string read FRealm;
    property DocRoot: string read FDocRoot;
    property LoggingDir: string read FLoggingDir;
    property VirtualDirs: TVirtualDirs read FVirtualDirs;
{
    property MaxClients: Integer read FMaxClients;
    property ListenIP: string read FListenIP;
    property ListenPort: Word read FListenPort;
    property ListenSocket: TSocket read FListenSocket write FListenSocket;
}
  end;

  TVirtualHostsManager = class
  private
    FVirtualHosts: TList;
  protected
    function GetCount: Integer;
    function GetHostByIndex(Index: Integer): TVirtualHost;
  public
    constructor Create;
    destructor Destroy; override;

    function GetVirtualHost(AHostName: string): TVirtualHost;
    procedure ClearVirtualHosts;

    procedure SaveConfig(ConfigDir: string);
    procedure LoadConfig(ConfigDir: string);

    property Count: Integer read GetCount;
    property Items[Index: Integer]: TVirtualHost read GetHostByIndex; default;
  end;

var
  GVirtualHosts: TVirtualHostsManager;

implementation

uses
{$IFDEF XBUG}
  uDebug,
{$ENDIF}
  HashTable,
  Common,
  HTTPConn;

const
  VHOSTS_FILENAME = 'vhosts.xml';

{ TVirtualHostsManager }

procedure TVirtualHostsManager.ClearVirtualHosts;
var
  Host: TVirtualHost;
  I: Integer;
begin
  for I := Pred(FVirtualHosts.Count) downto 0 do
    TVirtualHost(FVirtualHosts[I]).Free;

  FVirtualHosts.Clear;
end;

constructor TVirtualHostsManager.Create;
begin
  inherited;

  FVirtualHosts := TList.Create;
end;

destructor TVirtualHostsManager.Destroy;
begin
  ClearVirtualHosts;
  FreeAndNil(FVirtualHosts);

  inherited;
end;

function TVirtualHostsManager.GetCount: Integer;
begin
  Result := FVirtualHosts.Count;
end;

function TVirtualHostsManager.GetHostByIndex(Index: Integer): TVirtualHost;
begin
  Assert((Index >= 0) and (Index < FVirtualHosts.Count));

  Result := TVirtualHost(FVirtualHosts[Index]);
end;

function TVirtualHostsManager.GetVirtualHost(AHostName: string): TVirtualHost;
var
  I: Integer;
  ChkSum: Cardinal;
begin
  // Default to the first host
  Result := TVirtualHost(FVirtualHosts[0]);

  AHostName := AnsiLowerCase(Trim(AHostName));
  if (AHostName = '') then
    Exit;
  ChkSum    := SuperFastHash(PAnsiChar(AHostName), Length(AHostName));

  for I := Pred(FVirtualHosts.Count) downto 0 do
  begin
    if (TVirtualHost(FVirtualHosts[I]).FChkSum = ChkSum) then
    begin
      if (AnsiCompareStr(TVirtualHost(FVirtualHosts[I]).FHostName, AHostName) = 0) then
      begin
        Result := TVirtualHost(FVirtualHosts[I]);
        Break;
      end;
    end;
  end;
end;

procedure TVirtualHostsManager.LoadConfig(ConfigDir: string);
var
  ConfigFile: string;
  I, J: Integer;
  XML: TXMLConfig;
  Host: TVirtualHost;
begin
  if ConfigDir = '' then
    ConfigDir := ExtractFilePath(ParamStr(0));
  ConfigFile := PathAddSlash(ConfigDir) + VHOSTS_FILENAME;

  XML := TXMLConfig.Create(ConfigFile);
  try
    ClearVirtualHosts;

    J := XML.GetValue('VirtualHosts/Count', 0);
    if J > 0 then
    begin
      for I := 0 to (J - 1) do
      begin
        Host := TVirtualHost.Create;
        Host.LoadConfig(XML, I);
        FVirtualHosts.Add(Host);
      end;
    end;
  finally
    FreeAndNil(XML);
  end;
end;

procedure TVirtualHostsManager.SaveConfig(ConfigDir: string);
var
  ConfigFile: string;
  I, J: Integer;
  XML: TXMLConfig;
begin
  J := FVirtualHosts.Count;
  if J > 0 then
  begin
    if ConfigDir = '' then
      ConfigDir := ExtractFilePath(ParamStr(0));
    ConfigFile := PathAddSlash(ConfigDir) + VHOSTS_FILENAME;

    XML := TXMLConfig.Create(ConfigFile);
    try
      for I := 0 to (J - 1) do
        TVirtualHost(FVirtualHosts[I]).SaveConfig(XML, I);
    finally
      FreeAndNil(XML);
    end;
  end;
end;

{ TVirtualHost }
{
procedure TVirtualHost.AcceptConnections;
var
  I: Integer;
begin
  for I := 1 to FMaxClients do
    AcceptNewConn(Self);
end;
}

constructor TVirtualHost.Create;
begin
  inherited;

  FVirtualDirs  := TVirtualDirs.Create;
  //FListenSocket := INVALID_SOCKET;
end;

destructor TVirtualHost.Destroy;
begin
  FreeAndNil(FVirtualDirs);
  inherited;
end;

procedure TVirtualHost.LoadConfig(XML: TXMLConfig; ItemIndex: Integer);
var
  Key: string;
begin
  Key         := 'VirtualHosts/Host_' + IntToStr(ItemIndex) + '/';

  FVHostName  :=  Trim(XML.GetValue(Key + 'Info/VHostName', ''));
  FHostName   :=  LowerCase(Trim(XML.GetValue(Key + 'Info/HostName', '')));
  FChkSum     := SuperFastHash(PAnsiChar(FHostName), Length(FHostName));

  FRealm      :=  XML.GetValue(Key + 'Info/Realm', '');
  FDocRoot    :=  XML.GetValue(Key + 'Info/DocRoot', '');
  FLoggingDir :=  XML.GetValue(Key + 'Info/LogDir', '');
{
  FListenIP   :=  XML.GetValue(Key + 'Info\ListenIP', '0.0.0.0');
  FListenPort :=  XML.GetValue(Key + 'Info\ListenPort', 8080);
  FMaxClients :=  XML.GetValue(Key + 'Info\MaxClients', 10);
}
  FVirtualDirs.DocRoot := FDocRoot;
  FVirtualDirs.LoadConfig(XML, Key);
end;

function TVirtualHost.ResolveRealPath(const AURL: String; var Cache, DirList,
  ExecScript, Auth: Boolean): String;
begin
  Result := FVirtualDirs.ResolveRealPath(AURL, Cache, DirList, ExecScript, Auth);
end;

procedure TVirtualHost.SaveConfig(XML: TXMLConfig; ItemIndex: Integer);
begin

end;

initialization
  GVirtualHosts := TVirtualHostsManager.Create;
finalization
  FreeAndNil(GVirtualHosts);
end.
