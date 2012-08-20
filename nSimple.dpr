program nSimple;

{$APPTYPE CONSOLE}
{$I NITROHTTPD.INC}

uses
  Windows,
  SysUtils,
  Buffer in 'Buffer.pas',
  BusinessThreadPool in 'BusinessThreadPool.pas',
  CachedLogger in 'CachedLogger.pas',
  CGIEngine in 'CGIEngine.pas',
  Common in 'Common.pas',
  Config in 'Config.pas',
  FastDateCache in 'FastDateCache.pas',
  FastDirLister in 'FastDirLister.pas',
  FastLock in 'FastLock.pas',
  FileInfoCache in 'FileInfoCache.pas',
  GarbageCollector in 'GarbageCollector.pas',
  HashTable in 'HashTable.pas',
  HTTPConn in 'HTTPConn.pas',
  HTTPProcessor in 'HTTPProcessor.pas',
  HTTPRequests in 'HTTPRequests.pas',
  HTTPResponse in 'HTTPResponse.pas',
  IOCPServer in 'IOCPServer.pas',
  IOCPWorker in 'IOCPWorker.pas',
  HTTPExt in 'HTTPExt.pas',
  ISAPIEngine in 'ISAPIEngine.pas',
  LockPool in 'LockPool.pas',
  MimeType in 'MimeType.pas',
  ServerStats in 'ServerStats.pas',
  VirtualDir in 'VirtualDir.pas',
  VirtualFileIO in 'VirtualFileIO.pas',
  AVLTree in 'AVLTree.pas',
  XMLConfig in 'XMLConfig.pas',
  FileDataCache in 'FileDataCache.pas',
  HTTPHeaderCache in 'HTTPHeaderCache.pas',
  ScriptThreadPool in 'ScriptThreadPool.pas',
  FastList in 'FastList.pas',
  GZipEncoder in 'GZipEncoder.pas',
  GZipDataCache in 'GZipDataCache.pas',
  HTTPAuth in 'HTTPAuth.pas',
  ThreadAffinity in 'ThreadAffinity.pas',
  CreateProcess in 'CreateProcess.pas',
  Win32API in 'Win32API.pas',
  PoolAlloc in 'PoolAlloc.pas';

var
  C: Char;

begin
  LoadConfig;
{$IFDEF ENABLE_LOGGING}
  LogInit;
{$ENDIF}
  VFileStart(128, 1, 13);

  DataCacheInit;
{$IFDEF GZIP_COMPRESS}
  GZCacheInit;
{$ENDIF}
{$IFDEF CACHE_HTTP_HEADERS}
  HeaderCacheInit;
{$ENDIF}
  ScriptPoolCreate(CfgGetScriptThreadPoolSize);
  StatsStartCounter;
  ServerInit;
  ServerStart;

  Sleep(100);
  WriteLn(SERVER_SOFTWARE + ' ' + SERVER_VERSION +  ' started.');
  WriteLn('IP: ' + CfgGetListenIP);
  WriteLn('Port:' + IntToStr(CfgGetListenPort));
  WriteLn('IOCP Threads:' + IntToStr(SvrGetIOCPThreadPoolSize));
  WriteLn('Business Logic Threads:' + IntToStr(CfgGetBusinessThreadPoolSize));
  WriteLn('Script Threads:' + IntToStr(CfgGetScriptThreadPoolSize));
  WriteLn('Max Clients:' + IntToStr(CfgGetMaxClients));
  WriteLn('Data Cache Capacity:' + StorageSize(CfgGetDataCacheMaxCapacity));
  WriteLn('Press RETURN to shutdown...');

  ReadLn(C); 

  ServerStop;
  //StatsReset;
  DataCacheShutdown;
{$IFDEF GZIP_COMPRESS}
  GZCacheShutdown;
{$ENDIF}
{$IFDEF CACHE_HTTP_HEADERS}
  HeaderCacheShutdown;
{$ENDIF}
  ScriptPoolShutDown;
  VFileStop;
{$IFDEF ENABLE_LOGGING}
  LogShutdown;
{$ENDIF}
end.
