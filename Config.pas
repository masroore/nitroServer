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
// $Version:0.6.2$ $Revision:1.5.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:04$
//
////////////////////////////////////////////////////////////////////////////////

unit Config;

interface

uses
  Windows, WinSock, SysUtils;

function CfgGetMaxClients: Integer;
function CfgGetDataCacheMaxCapacity: Integer;

function CfgGetListenIP: string;
function CfgGetListenPort: Word;

function CfgGetServerName: string;

function CfgGetKeepAlive: Boolean;
function CfgGetKeepAliveMax: Integer;

function CfgGetBusinessThreadPoolSize: Integer;
function CfgGetScriptThreadPoolSize: Integer;

function CfgImpersonate: Boolean;
function CfgGetImpersonateUser: string;
function CfgGetImpersonatePass: string;

procedure LoadConfig(ConfigDir: string = '');
procedure SaveConfig(ConfigDir: string = '');

implementation

{$I NITROHTTPD.INC}

uses
  Common,
  AVLTree,
  XMLConfig,
  VirtualDir,
  CachedLogger,
  CGIEngine,
  IOCPServer, VHosts;

const
  CONFIG_FILENAME = 'CONFIG.XML';

const
  DEFAULT_KEEPALIVE_MAX = 10;
  DEFAULT_MAX_CLIENTS = 10;
  DEFAULT_DATACACHE_CAPACITY = 4 * 1024 * 1024;

var
  g_ThreadPoolSize,
  g_ScriptThreadPoolSize,
  g_MaxClients: Integer;
  g_ListenPort: Word;
  g_ListenIP: string;
  g_ServerName,
  g_ConfigFile: string;
  g_Impersonate: Boolean;
  g_ImpersonateUser,
  g_ImpersonatePass: string;
  g_KeepAliveEnabled: Boolean;
  g_KeepAliveMax: Integer;
  g_FileCachePurgeTime: Cardinal;
  g_DataCacheMaxCapacity: Cardinal;

function CfgGetMaxClients: Integer;
begin
  if g_MaxClients <= 0 then
    g_MaxClients := DEFAULT_MAX_CLIENTS;

  Result := g_MaxClients;
end;

function CfgGetDataCacheMaxCapacity: Integer;
begin
  if g_DataCacheMaxCapacity <= 0 then
    g_DataCacheMaxCapacity := DEFAULT_DATACACHE_CAPACITY;

  Result := g_DataCacheMaxCapacity;
end;

function CfgGetListenPort: Word;
var
  pse: PServEnt;
begin
  if g_ListenPort = 0 then
  begin
    pse := getservbyname('http', 'tcp');
    if Assigned(pse) then
      g_ListenPort := pse^.s_port
    else
      g_ListenPort := SERVER_PORT;
  end;

  Result := g_ListenPort;
end;

function CfgGetListenIP: string;
begin
  if g_ListenIP = '' then
    g_ListenIP := '0.0.0.0';

  Result  := g_ListenIP;
end;

function CfgGetServerName: string;
begin
//  if (g_ServerName = '') then
//    g_ServerName := GetServerAddr + ':' + GetServerPort;

  Result := g_ServerName;
end;

function CfgGetKeepAlive: Boolean;
begin
  Result := g_KeepAliveEnabled;
end;

function CfgGetKeepAliveMax: Integer;
begin
  if g_KeepAliveMax <= 0 then
    g_KeepAliveMax := DEFAULT_KEEPALIVE_MAX;

  Result  := g_KeepAliveMax;
end;

function CfgGetBusinessThreadPoolSize: Integer;
begin
  if g_ThreadPoolSize <= 0 then
    g_ThreadPoolSize := 4;

  Result := g_ThreadPoolSize;
end;

function CfgGetScriptThreadPoolSize: Integer;
begin
  if g_ScriptThreadPoolSize <= 0 then
    g_ScriptThreadPoolSize := 4;

  Result := g_ScriptThreadPoolSize;
end;

function CfgImpersonate: Boolean;
begin
  Result := g_Impersonate;
end;

function CfgGetImpersonateUser: string;
begin
  Result := g_ImpersonateUser;
end;

function CfgGetImpersonatePass: string;
begin
    Result := g_ImpersonatePass;
end;

procedure LoadConfig(ConfigDir: string);
var
  XML: TXMLConfig;
  I, J: Integer;
  Key, VDir, RDir: string;
  DirList, Script, NonParse, Auth: Boolean; 
begin
  if ConfigDir = '' then
    ConfigDir := ExtractFilePath(ParamStr(0));
  g_ConfigFile := PathAddSlash(ConfigDir) + CONFIG_FILENAME;

  XML := TXMLConfig.Create(g_ConfigFile);
  try
    g_ServerName            := XML.GetValue('Server/ServerName', SERVER_SOFTWARE);
    g_MaxClients            := XML.GetValue('Server/MaxClients', 10);
    g_ThreadPoolSize        := XML.GetValue('Server/ThreadPoolSize', 4);
    g_ScriptThreadPoolSize  := XML.GetValue('Server/ScriptThreadPoolSize', 4);
    g_DataCacheMaxCapacity  := XML.GetValue('Server/DataCacheMaxCapacity', DEFAULT_DATACACHE_CAPACITY);
    g_KeepAliveEnabled      := XML.GetValue('Server/EnableKeepAlive', True);
    g_KeepAliveMax          := XML.GetValue('Server/MaxKeepAlive', DEFAULT_KEEPALIVE_MAX);


    g_ListenIP              := XML.GetValue('Server/Bindings/IP', '0.0.0.0');
    g_ListenPort            := XML.GetValue('Server/Bindings/Port', SERVER_PORT);

    g_Impersonate           := XML.GetValue('Server/Impersonation/Enabled', False);
    g_ImpersonateUser       := XML.GetValue('Server/Impersonation/Username', '');
    g_ImpersonatePass       := XML.GetValue('Server/Impersonation/Password', '');

    { TODO : Relocate settings to their proper locations }
    //SetDocRoot(XML.GetValue('Server/DocRoot', ExtractFilePath(ParamStr(0)) + 'htdocs'));

{$IFDEF ENABLE_LOGGING}
    LogSetDir(XML.GetValue('Logging/Directory', ExtractFilePath(ParamStr(0)) + 'logs'));
    LogSetLevel(TLogLevel(XML.GetValue('Logging/Level', Ord(llDebug))));
    LogSetCacheMaxSize(XML.GetValue('Logging/CacheSize', 512));
    LogSetCacheFlushInterval(XML.GetValue('Logging/FlushInterval', 30));
{$ENDIF}

    g_FileCachePurgeTime := XML.GetValue('FileCache/PurgeInterval', 90);

    {
    J := XML.GetValue('VirtualDirs/Count', 0);
    if (J > 0) then
    begin
      for I := 0 to (J - 1) do
      begin
        Key   :=  'VirtualDirs/Entry_' + IntToStr(I) + '/';
        VDir  :=  XML.GetValue(Key + 'VirtualPath', '');
        RDir  :=  XML.GetValue(Key + 'RealPath', '');
        Script:=  XML.GetValue(Key + 'ExecuteScript', False);
        DirList:= XML.GetValue(Key + 'DirListing', False);
        Auth  := XML.GetValue(Key + 'Authenticate', False);
        if (VDir <> '') and (RDir <> '') then
          RegisterVirtualDir(VDir, RDir, DirList, Script, Auth);
      end;
    end;
    }

    J := XML.GetValue('CGIRunner/Count', 0);
    if (J > 0) then
    begin
      for I := 0 to (J - 1) do
      begin
        Key   := 'CGIRunner/Entry_' + IntToStr(I) + '/';

        VDir  := XML.GetValue(Key + 'Extension', '');
        Script:= XML.GetValue(Key + 'IsInterpreted', False);
        NonParse := XML.GetValue(Key + 'IsNonParsed', False);
        RDir  := XML.GetValue(Key + 'Interpreter', '');

        CGIRegisterScript(VDir, RDir, Script, NonParse);
      end;
    end;
  finally
    FreeAndNil(XML);
  end;

  GVirtualHosts.LoadConfig(ConfigDir);
end;

procedure SaveConfig(ConfigDir: string);
var
  XML: TXMLConfig;
  I, J: Integer;
begin
  if ConfigDir = '' then
    ConfigDir := ExtractFilePath(ParamStr(0));
  g_ConfigFile := PathAddSlash(ConfigDir) + CONFIG_FILENAME;

  XML := TXMLConfig.Create(g_ConfigFile);
  try
    XML.SetValue('Server/ServerName',     g_ServerName);
    XML.SetValue('Server/Port',           g_ListenPort);
    XML.SetValue('Server/MaxClients',     g_MaxClients);
    XML.SetValue('Server/ThreadPoolSize', g_ThreadPoolSize);
    XML.SetValue('Server/ScriptThreadPoolSize', g_ScriptThreadPoolSize);
    { TODO : Relocate settings to their proper locations }
    // XML.SetValue('Server/Docroot',        GetDocRoot);
{$IFDEF ENABLE_LOGGING}
    XML.SetValue('Logging/Directory',     LogGetDir);
    XML.SetValue('Logging/Level',         Integer(LogGetLevel));
    XML.SetValue('Logging/CacheSize',     LogGetCacheMaxSize);
    XML.SetValue('Logging/FlushInterval', LogGetCacheFlushInterval);
{$ENDIF}
    XML.SetValue('FileCache/PurgeInterval', g_FileCachePurgeTime);

    GVirtualHosts.SaveConfig(ConfigDir);

    CGISaveConfig(XML);

  finally
    FreeAndNil(XML);
  end;
end;

end.
