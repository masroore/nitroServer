unit WinSock2; // TODO: use platform directive

interface

uses
  Windows,
  WinSock;

{$DEFINE XP_OR_HIGHER}

{$IFDEF FPC}
function GetOverlappedResult(hFile: THandle; const lpOverlapped: TOverlapped;
  var lpNumberOfBytesTransferred: DWORD; bWait: BOOL): BOOL; stdcall;
{$EXTERNALSYM GetOverlappedResult}
function CreateIoCompletionPort(FileHandle, ExistingCompletionPort: THandle;
  CompletionKey, NumberOfConcurrentThreads: DWORD): THandle; stdcall;
{$EXTERNALSYM CreateIoCompletionPort}
function GetQueuedCompletionStatus(CompletionPort: THandle;
  var lpNumberOfBytesTransferred, lpCompletionKey: DWORD;
  var lpOverlapped: POverlapped; dwMilliseconds: DWORD): BOOL; stdcall;
{$EXTERNALSYM GetQueuedCompletionStatus}
function PostQueuedCompletionStatus(CompletionPort: THandle; dwNumberOfBytesTransferred: DWORD;
  dwCompletionKey: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
{$EXTERNALSYM PostQueuedCompletionStatus}
{$ENDIF}

const
  WSA_IO_PENDING      = ERROR_IO_PENDING;
  WSA_OPERATION_ABORTED = ERROR_OPERATION_ABORTED;
  WSA_FLAG_OVERLAPPED = $01;


type (*** AS defined in Winsock2.h ***)

  ArrayOfChar = array of Char;

  TWSABuf = record
    len: Cardinal;
    buf: PAnsiChar;
  end;
  PWSABuf  = ^TWSABuf;
  AWSABuf  = array of TWSAbuf;
  PAWSABuf = ^AWSABuf;

{ There are two different types of WSAPROTOCOL_INFOs, one is
  defined for the WSASocketA call and one for the WSASocketW.
  since I have no need for either, it should not matter which I call.
} TWSAPROTOCOL_INFO = record
    // TODO: fill in, but I-I-I don't need this!
  end;

  procCompletionRoutine = procedure; // We are not using these, hence
  procCondition = procedure;         // they will remain undefined...
  GROUP = Cardinal;

{$EXTERNALSYM WSASocket}
function WSASocket(i_af: Integer; i_type: Integer;
  i_protocol: Integer; lpProtocolInfo: { TODO: ! LPWSAPROTOCOL_INFO } pointer;
  g: GROUP; lwFlags: Longword): TSocket; STDCALL;

{$EXTERNALSYM WSAAccept}
function WSAAccept(s: TSocket; addr: PSockAddrIn;
  addrlen: PInteger; lpprocCondition: procCondition;
  lwCallbackData: Longword): TSocket; STDCALL;

{$EXTERNALSYM WSARecv}
function WSARecv(s: TSocket; lpBuffers: PWSABuf;
  lwBufferCount: Longword; var lplwNrOfBytesRecvd: Longword;
  var lplwFlags: Longword; lpOverlapped: POverlapped;
  lpprocCompletionRoutine: procCompletionRoutine): Integer; STDCALL;

{$EXTERNALSYM WSASend}
function WSASend(s: TSocket; lpBuffers: PWSABuf;
  lwBufferCount: Longword; var lplwNrOfBytesSent: Longword;
  lwFlags: Longword; lpOverlapped: POverlapped;
  lpprocCompletionRoutine: procCompletionRoutine): Integer; STDCALL;

function WSASendDisconnect(s: TSocket;
  lpOutboundDisconnectData: PWSABuf): Integer; STDCALL;

type
  {$EXTERNALSYM LPWSAOVERLAPPED_COMPLETION_ROUTINE}
  LPWSAOVERLAPPED_COMPLETION_ROUTINE = procedure(const dwError, cbTransferred: DWORD;
    const lpOverlapped : POverlapped; const dwFlags: DWORD); stdcall;
function WSAIoctl(s: TSocket; dwIoControlCode: DWORD; lpvInBuffer: Pointer; cbInBuffer: DWORD;
  lpvOutBuffer: Pointer; cbOutBuffer: DWORD; var lpcbBytesReturned: DWORD;
  lpOverlapped: POverlapped; lpCompletionRoutine: LPWSAOVERLAPPED_COMPLETION_ROUTINE): Integer; stdcall;
{$EXTERNALSYM WSAIoctl}

const
  SO_UPDATE_ACCEPT_CONTEXT   = $700B;
  {$EXTERNALSYM SO_UPDATE_ACCEPT_CONTEXT}
  SO_CONNECT_TIME            = $700C;
  {$EXTERNALSYM SO_CONNECT_TIME}
  SO_UPDATE_CONNECT_CONTEXT  = $7010;
  {$EXTERNALSYM SO_UPDATE_CONNECT_CONTEXT}

const
  TP_ELEMENT_MEMORY  = 1;
  {$EXTERNALSYM TP_ELEMENT_MEMORY}
  TP_ELEMENT_FILE    = 2;
  {$EXTERNALSYM TP_ELEMENT_FILE}
  TP_ELEMENT_EOP     = 4;
  {$EXTERNALSYM TP_ELEMENT_EOP}

{$IFDEF XP_OR_HIGHER}
const
  TF_USE_DEFAULT_WORKER = $00;
  {$EXTERNALSYM TF_USE_DEFAULT_WORKER}
  TF_USE_SYSTEM_THREAD  = $10;
  {$EXTERNALSYM TF_USE_SYSTEM_THREAD}
  TF_USE_KERNEL_APC     = $20;
  {$EXTERNALSYM TF_USE_KERNEL_APC}

const
  {$EXTERNALSYM TP_DISCONNECT}
  TP_DISCONNECT       = TF_DISCONNECT;
  {$EXTERNALSYM TP_REUSE_SOCKET}
  TP_REUSE_SOCKET     = TF_REUSE_SOCKET;
  {$EXTERNALSYM TP_USE_DEFAULT_WORKER}
  TP_USE_DEFAULT_WORKER = TF_USE_DEFAULT_WORKER;
  {$EXTERNALSYM TP_USE_SYSTEM_THREAD}
   TP_USE_SYSTEM_THREAD = TF_USE_SYSTEM_THREAD;
  {$EXTERNALSYM TP_USE_KERNEL_APC}
  TP_USE_KERNEL_APC     = TF_USE_KERNEL_APC;

const
  { Extension function pointers' GUIDs }
  WSAID_DISCONNECTEX:    TGUID = '{7FDA2E11-8630-436F-A031-F536A6EEC157}';
  WSAID_TRANSMITPACKETS: TGUID = '{D9689DA0-1F90-11D3-9971-00C04F68C876}';

type
  LPFN_DISCONNECTEX = function(const hSocket : TSocket; AOverlapped: POverlapped;
                               const dwFlags : DWORD; const dwReserved : DWORD) : BOOL;
  TDisconnectEx = LPFN_DISCONNECTEX;

  LPTRANSMIT_PACKETS_ELEMENT = ^TRANSMIT_PACKETS_ELEMENT;
  TRANSMIT_PACKETS_ELEMENT = record
    dwElFlags: DWORD;
    cLength: DWORD;
    case Boolean of
      False: (
        nFileOffset: LARGE_INTEGER;
        hFile: THandle;
      );
      True: (
        pBuffer: Pointer;
      );
  end;
  TTransmitPacketsElement = TRANSMIT_PACKETS_ELEMENT;
  PTransmitPacketsElement = LPTRANSMIT_PACKETS_ELEMENT;

  LPFN_TRANSMITPACKETS = function(s: TSocket; lpPacketArray: PTransmitPacketsElement;
                                  nElementCount: DWORD; nSendSize: DWORD;
                                  lpOverlapped: POverlapped; dwFlags: DWORD): BOOL;

const
  {$EXTERNALSYM IOC_UNIX}
  IOC_UNIX      = $00000000;
  {$EXTERNALSYM IOC_WS2}
  IOC_WS2       = $08000000;
  {$EXTERNALSYM IOC_PROTOCOL}
  IOC_PROTOCOL  = $10000000;
  {$EXTERNALSYM IOC_VENDOR}
  IOC_VENDOR    = $18000000;

  {$EXTERNALSYM SIO_ASSOCIATE_HANDLE}
  SIO_ASSOCIATE_HANDLE                =  IOC_IN or IOC_WS2 or 1;
  {$EXTERNALSYM SIO_ENABLE_CIRCULAR_QUEUEING}
  SIO_ENABLE_CIRCULAR_QUEUEING        =  IOC_VOID or IOC_WS2 or 2;
  {$EXTERNALSYM SIO_FIND_ROUTE}
  SIO_FIND_ROUTE                      =  IOC_OUT or IOC_WS2 or 3;
  {$EXTERNALSYM SIO_FLUSH}
  SIO_FLUSH                           =  IOC_VOID or IOC_WS2 or 4;
  {$EXTERNALSYM SIO_GET_BROADCAST_ADDRESS}
  SIO_GET_BROADCAST_ADDRESS           =  IOC_OUT or IOC_WS2 or 5;
  {$EXTERNALSYM SIO_GET_EXTENSION_FUNCTION_POINTER}
  SIO_GET_EXTENSION_FUNCTION_POINTER  =  IOC_INOUT or IOC_WS2 or 6;
  {$EXTERNALSYM SIO_GET_QOS}
  SIO_GET_QOS                         =  IOC_INOUT or IOC_WS2 or 7;
  {$EXTERNALSYM SIO_GET_GROUP_QOS}
  SIO_GET_GROUP_QOS                   =  IOC_INOUT or IOC_WS2 or 8;
  {$EXTERNALSYM SIO_MULTIPOINT_LOOPBACK}
  SIO_MULTIPOINT_LOOPBACK             =  IOC_IN or IOC_WS2 or 9;
  {$EXTERNALSYM SIO_MULTICAST_SCOPE}
  SIO_MULTICAST_SCOPE                 = IOC_IN or IOC_WS2 or 10;
  {$EXTERNALSYM SIO_SET_QOS}
  SIO_SET_QOS                         = IOC_IN or IOC_WS2 or 11;
  {$EXTERNALSYM SIO_SET_GROUP_QOS}
  SIO_SET_GROUP_QOS                   = IOC_IN or IOC_WS2 or 12;
  {$EXTERNALSYM SIO_TRANSLATE_HANDLE}
  SIO_TRANSLATE_HANDLE                = IOC_INOUT or IOC_WS2 or 13;
  {$EXTERNALSYM SIO_ROUTING_INTERFACE_QUERY}
  SIO_ROUTING_INTERFACE_QUERY         = IOC_INOUT or IOC_WS2 or 20;
  {$EXTERNALSYM SIO_ROUTING_INTERFACE_CHANGE}
  SIO_ROUTING_INTERFACE_CHANGE        = IOC_IN or IOC_WS2 or 21;
  {$EXTERNALSYM SIO_ADDRESS_LIST_QUERY}
  SIO_ADDRESS_LIST_QUERY              = IOC_OUT or IOC_WS2 or 22; // see below SOCKET_ADDRESS_LIST
  {$EXTERNALSYM SIO_ADDRESS_LIST_CHANGE}
  SIO_ADDRESS_LIST_CHANGE             = IOC_VOID or IOC_WS2 or 23;
  {$EXTERNALSYM SIO_QUERY_TARGET_PNP_HANDLE}
  SIO_QUERY_TARGET_PNP_HANDLE         = IOC_OUT or IOC_WS2 or 24;
  {$EXTERNALSYM SIO_ADDRESS_LIST_SORT}
  SIO_ADDRESS_LIST_SORT               = IOC_INOUT or IOC_WS2 or 25;

var
  {$EXTERNALSYM DisconnectEx}
  DisconnectEx : LPFN_DISCONNECTEX = nil;
  {$EXTERNALSYM TransmitPackets}
  TransmitPackets : LPFN_TRANSMITPACKETS = nil;

{$ENDIF}

implementation

const
  winsocket2 = 'Ws2_32.dll';
  kernel32   = 'kernel32.dll';

{$IFDEF FPC}
function PostQueuedCompletionStatus; external kernel32 name 'PostQueuedCompletionStatus';
function CreateIoCompletionPort; external kernel32 name 'CreateIoCompletionPort';
function GetQueuedCompletionStatus; external kernel32 name 'GetQueuedCompletionStatus';
function GetOverlappedResult; external kernel32 name 'GetOverlappedResult';
{$ENDIF}

function WSASocket; EXTERNAL winsocket2 Name 'WSASocketA';
function WSAAccept; EXTERNAL winsocket2 Name 'WSAAccept';
function WSARecv; EXTERNAL winsocket2 Name 'WSARecv';
function WSASend; EXTERNAL winsocket2 Name 'WSASend';
function WSASendDisconnect; EXTERNAL winsocket2 Name 'WSASendDisconnect';
function WSAIoctl; external winsocket2 name 'WSAIoctl';

function WSAGetExtensionFunctionPointer(s: TSocket; const gdExFuncGuid: TGUID): Pointer;
var
  lwOut: Longword;
begin
  //Result := nil;
  WSAIoctl(s, SIO_GET_EXTENSION_FUNCTION_POINTER, @gdExFuncGuid, SizeOf(gdExFuncGuid),
    @Result, SizeOf(Result), lwOut, nil, nil);
end;

const
  MSWSOCK_DLL = 'MSWSOCK.DLL';   {Do not Localize}
var
  hMSWSockDll : THandle = 0; // MSWSOCK.DLL handle

function Stub_TransmitPackets3(hSocket: TSocket; lpPacketArray: PTransmitPacketsElement;
    nElementCount: DWORD; nSendSize: DWORD; lpOverlapped: POverlapped; dwFlags: DWORD): BOOL;
begin
  TransmitPackets := WSAGetExtensionFunctionPointer(hSocket, WSAID_TRANSMITPACKETS);

  Result := TransmitPackets(hSocket, lpPacketArray, nElementCount, nSendSize, lpOverlapped, dwFlags);
end;


//if(::WSAIoctl(Listen,SIO_GET_EXTENSION_FUNCTION_POINTER,(void*)&GuidTranmitP

{$IFDEF XP_OR_HIGHER}
initialization

  //if hMSWSockDll = 0 then
  hMSWSockDll := Windows.LoadLibrary(MSWSOCK_DLL);

  if (hMSWSockDll = 0) then
    Halt(0);

  //WSAIoctl                         := Stub_WSAIoctl;
  //DisconnectEx                     := Stub_DisconnectEx;
  //TransmitPackets                  := Stub_TransmitPackets3;

  TransmitPackets := LPFN_TRANSMITPACKETS(WSAGetExtensionFunctionPointer(0, WSAID_TRANSMITPACKETS));
  DisconnectEx    := LPFN_DISCONNECTEX(WSAGetExtensionFunctionPointer(0, WSAID_DISCONNECTEX));
  
finalization

	FreeLibrary(hMSWSockDll);
{$ENDIF}
end.
