unit ThreadAffinity;

interface

{$I NITROHTTPD.INC}

uses
  Windows, Messages;

function GetProcessorCount: Cardinal;
procedure BindThreadsToProcessors(Threads: array of THandle;
                                  ThreadsCount, ThreadsPerProcessor: Cardinal);

implementation

function GetProcessorCount: Cardinal;
var
  SysInfo: TSystemInfo;
begin
  GetSystemInfo(SysInfo);
  Result := SysInfo.dwNumberOfProcessors;
end;

function BindThreadToProcessor(hThread: THandle; Processor: Cardinal): Boolean;
begin
  Result := SetThreadAffinityMask(hThread, Processor) <> 0;
end;

procedure BindThreadsToProcessors(Threads: array of THandle;
                                  ThreadsCount, ThreadsPerProcessor: Cardinal);
var
  nProcessors, I, J: Integer;
  ProcMask: array of Cardinal;
  X: Integer;
begin
  nProcessors := GetProcessorCount;
  SetLength(ProcMask, nProcessors);
  for I := 0 to Pred(nProcessors) do
    ProcMask[I] := Succ(I);

  for I := 0 to Pred(ThreadsCount) do
    BindThreadToProcessor(Threads[I], ProcMask[I div ThreadsPerProcessor]);
end;

end.


