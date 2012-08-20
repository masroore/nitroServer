unit CreateProcess;

interface

uses
  Windows;

function CreateRestrictedProcess(const Username, Domain, Password: WideString;
                                 const FileName: WideString;
                                 const Params: WideString;
                                 const DefaultDir: WideString;
                                 const StdIn_Read, StdOut_Write, StdErr_Write: THandle;
                                 EnvBlock: PChar;
                                 var ProcessInformation: TProcessInformation): BOOL;

implementation

uses
  Win32API;

function CreateRestrictedProcess(const Username, Domain, Password: WideString;
                                 const FileName: WideString;
                                 const Params: WideString;
                                 const DefaultDir: WideString;
                                 const StdIn_Read, StdOut_Write, StdErr_Write: THandle;
                                 EnvBlock: PChar;
                                 var ProcessInformation: TProcessInformation): BOOL;
var
  LocallyModifiableParams: WideString;
  StartupInfo: TStartupInfoW;
begin
  {
  Sample Usage:
  ExecuteFileAsUser(
  'forest', //user name
  'goldshire', //domain name
  'gump', //password
  'c:\windows\system32\notepad.exe', //filename
  'c:\20070608.log', //params
  'c:\develop' //default dir
  );
  }

  LocallyModifiableParams := Filename + ' ' + Params;
  {A command line contains the executable name, e.g.
  notepad.exe c:\somefile.txt
  }

  {From the Platform SDK:
  The function can modify the contents of this string.
  Therefore, this parameter cannot be a pointer to read-only memory
  (such as a const variable or a literal string).
  If this parameter is a constant string, the function may cause an
  access violation.

  ed: A function that tries to cause access violations. Nice.}

  //An empty structure that the function wants
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  with StartupInfo do
  begin
    CB          := SizeOf(TStartupInfo);
    dwFlags     := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    hStdInput   := StdIn_Read;
    hStdOutput  := StdOut_Write;
    hStdError   := StdErr_Write;
    wShowWindow := SW_HIDE;
  end;

  //An empty structure that the function wants
  ZeroMemory(@ProcessInformation, SizeOf(ProcessInformation));

  Result := CreateProcessWithLogonW(
                                    PWideChar(Username),
                                    PWideChar(Domain),
                                    PWideChar(Password),
                                    LOGON_WITH_PROFILE,
                                    PWideChar(Filename),
                                    PWideChar(LocallyModifiableParams),
                                    CREATE_NEW_CONSOLE, //dwCreationFlags: DWORD
                                    PChar(EnvBlock), //lpEnvironment: Pointer
                                    PWideChar(DefaultDir), //lpCurrentDirectory: PWideChar;
                                    StartupInfo,
                                    ProcessInformation);
end;

end.
