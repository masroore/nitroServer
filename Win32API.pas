unit Win32API;

interface

uses
  Windows;

//
// LogonFlags
//
type
  _TOKEN_TYPE = (TokenTypePad0, TokenPrimary, TokenImpersonation);
  {$EXTERNALSYM _TOKEN_TYPE}
  TOKEN_TYPE = _TOKEN_TYPE;
  {$EXTERNALSYM TOKEN_TYPE}
  PTOKEN_TYPE = ^TOKEN_TYPE;
  {$EXTERNALSYM PTOKEN_TYPE}

  TTokenType = TOKEN_TYPE;
  PTokenType = PTOKEN_TYPE;

const
  LOGON_WITH_PROFILE         = $00000001;
  {$EXTERNALSYM LOGON_WITH_PROFILE}
  LOGON_NETCREDENTIALS_ONLY  = $00000002;
  {$EXTERNALSYM LOGON_NETCREDENTIALS_ONLY}
  LOGON_ZERO_PASSWORD_BUFFER = DWORD($80000000);
  {$EXTERNALSYM LOGON_ZERO_PASSWORD_BUFFER}

function CreateProcessWithLogonW(lpUsername, lpDomain, lpPassword: LPCWSTR;
  dwLogonFlags: DWORD; lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR;
  dwCreationFlags: DWORD; lpEnvironment: Pointer; lpCurrentDirectory: LPCWSTR;
  const lpStartupInfo: TStartupInfoW; var lpProcessInformation: TProcessInformation): BOOL; stdcall;
{$EXTERNALSYM CreateProcessWithLogonW}

function DuplicateTokenEx(hExistingToken: THandle; dwDesiredAccess: DWORD;
  lpTokenAttributes: PSecurityAttributes; ImpersonationLevel: TSecurityImpersonationLevel;
  TokenType: TTokenType; var phNewToken: THandle): BOOL; stdcall;
{$EXTERNALSYM DuplicateTokenEx}

implementation

const
  advapi32 = 'advapi32.dll';

function CreateProcessWithLogonW(lpUsername, lpDomain, lpPassword: LPCWSTR;
  dwLogonFlags: DWORD; lpApplicationName: LPCWSTR; lpCommandLine: LPWSTR;
  dwCreationFlags: DWORD; lpEnvironment: Pointer; lpCurrentDirectory: LPCWSTR;
  const lpStartupInfo: TStartupInfoW; var lpProcessInformation: TProcessInformation): BOOL; stdcall;
  external advapi32 name 'CreateProcessWithLogonW';

function DuplicateTokenEx(hExistingToken: THandle; dwDesiredAccess: DWORD;
  lpTokenAttributes: PSecurityAttributes; ImpersonationLevel: TSecurityImpersonationLevel;
  TokenType: TTokenType; var phNewToken: THandle): BOOL; stdcall;
  external advapi32 name 'DuplicateTokenEx';

end.
