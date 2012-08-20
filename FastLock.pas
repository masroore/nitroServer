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
// $Version:0.6.1$ $Revision:1.4$ $Author:masroore$ $RevDate:9/18/2007 14:36:36$
//
////////////////////////////////////////////////////////////////////////////////

unit FastLock;

interface

{$I NITROHTTPD.INC}

uses
  Windows, Classes;

type
  TFastLock = class
  PRIVATE
{$IFDEF LOCK_OPTEX}
    FOwningThreadID: Cardinal;
    FSpinCount,
    FLockDepth,
    FLockRequests: Integer;
    FEvent: THandle;
{$ENDIF}
{$IFDEF LOCK_SPINLOCK}
    FSpinLock: Integer;
{$ENDIF}
{$IFDEF LOCK_CRITSEC}
    FSection: TRTLCriticalSection;
{$ENDIF}

  PUBLIC
    constructor Create(SpinCount: Integer; PreCreateEvent: Boolean);
    destructor Destroy; OVERRIDE;

    procedure Enter;
    procedure Leave;
  end;

// /////////////////////////////////////////////////////////////////////////////
//
// TSwimerge
//
// A TSwimerge is a SWMRG. He he, that is exactly what it is: a Single Write
// Multiple Reader Guard. Puns aside, it is a synchronization object which
// allows access to multiple readers or only one writer at a time. It provides
// faster, more efficient mechanism for synchronization than CriticalSection
// objects. This synchronization object is useful in situations where a large
// number of threads may need to read a shared resource, but that resource is
// written to relatively infrequently.
// To protect the shared resource, this synchronization object enforces the
// following criteria:
//   > Several threads may read at once.
//   > Only one thread can be writing at once.
//   > If a thread is writing, then no threads can be reading.
// The synchronizer enforces these criteria by providing four functions:
//   BeginRead
//   BeginWrite
//   EndRead and
//   EndWrite.
// When a thread wants to read the data structure, it must call BeginRead. When
// it has finished reading, EndRead must be called.
// When a thread wants to write to the data structure, it must call BeginWrite.
// It must then call EndWrite when it has finished writing.
// If a thread given write access needs to read the protected data structure
// then BeginRead automatically grants read access.
// Calls to BeginWrite are reference counted.  A thread granted write access
// may call BeginWrite multiple times but each call to BeginWrite must have a
// corresponding call to EndWrite.
// Caveat:
// This object does not protect against the following cases:
//   1. Thread calls EndRead before BeginRead.
//   2. A thread calls EndWrite before BeginWrite.
//   3. Active writer thread calls EndRead before BeginRead or after EndWrite.
//   4. A thread other than the active thread calls EndWrite.
//
// /////////////////////////////////////////////////////////////////////////////

type
  TSwimerge = class
  private
     FSemReaders       : THandle;
     FSemWriters       : THandle;
     FCriticalSection  : TRTLCriticalSection;
     FActiveReaders    : Integer;
     FWriterActive     : Boolean;
     FActiveWriterID   : DWORD;
     FWaitingReaders   : Integer;
     FWaitingWriters   : Integer;
     FWriterReadRefCnt : Integer;
     FWriterWriteRefCnt: Integer;
  public

     // ////////////////////////////////////////////////////////////////////////
     // @Name          : Create
     // @Description   : Creates an instance the synchronization object
     // @Comments      : This synchronizer allows MAX_BLOCKED_THREADS threads
     //                  to wait for access to the resource. See TSemaphorePool
     //                  for details.
     // ////////////////////
     constructor Create;

     destructor Destroy; override;

     // ////////////////////////////////////////////////////////////////////////
     // @Name          : BeginRead
     // @Description   : Call this method when a thread wants to start reading
     //                  the protected resource.
     // @Comments      : BeginRead will not return until the thread has been
     //                  granted read access. Each occurrence of BeginRead must
     //                  have a corresponding call to EndRead.
     // ////////////////////
     procedure BeginRead;

     // ////////////////////////////////////////////////////////////////////////
     // @Name          : BeginWrite
     // @Description   : Call this method when a thread wants to start writing
     //                  the protected resource.
     // @Comments      : BeginWrite will not return until the thread has been
     //                  granted write access. Each occurrence of BeginWrite
     //                  must have a corresponding call to EndWrite.
     // ////////////////////
     procedure BeginWrite;

     // ////////////////////////////////////////////////////////////////////////
     // @Name          : EndRead
     // @Description   : Call this method when a thread has finished reading the
     //                  protected resource.
     // ////////////////////
     procedure EndRead;
     // ////////////////////////////////////////////////////////////////////////
     // @Name          : EndWrite
     // @Description   : Call this method when a thread has finished writing to
     //                  the protected resource.
     // ////////////////////
     procedure EndWrite;

  end;

implementation

{$IFDEF LOCK_OPTEX}
var
  g_bSingleProcessorMachine: Boolean = True;

procedure GetProcessorCount;
var
  si: TSystemInfo;
begin
  GetSystemInfo(si);
  g_bSingleProcessorMachine := si.dwNumberOfProcessors = 1;
end;
{$ENDIF}

{ TFastLock }

constructor TFastLock.Create(SpinCount: Integer; PreCreateEvent: Boolean);
begin
  inherited Create;

{$IFDEF LOCK_OPTEX}
  if g_bSingleProcessorMachine then
    FSpinCount := SpinCount
  else
    FSpinCount := 0;
  FLockDepth := 0;
  FLockRequests   := 0;
  FOwningThreadID := 0;
  if PreCreateEvent then
    FEvent := CreateEventW(nil, False, False, nil)
  else
    FEvent := INVALID_HANDLE_VALUE;
{$ENDIF}
{$IFDEF LOCK_SPINLOCK}
  FSpinLock := 0;
{$ENDIF}
{$IFDEF LOCK_CRITSEC}
  InitializeCriticalSection(FSection);
{$ENDIF}
end;

destructor TFastLock.Destroy;
begin
{$IFDEF LOCK_OPTEX}
  if (FEvent <> INVALID_HANDLE_VALUE) then
    CloseHandle(FEvent);
{$ENDIF}
{$IFDEF LOCK_CRITSEC}
  DeleteCriticalSection(FSection);
{$ENDIF}
  inherited;
end;

procedure TFastLock.Enter;
{$IFDEF LOCK_OPTEX}
var
  bTookOwnership: Boolean;
  dwThreadId: DWORD;
  iSpinCount: Integer;
  hNewEvent:      THandle;
{$ENDIF}
begin
{$IFDEF LOCK_CRITSEC}
  EnterCriticalSection(FSection);
{$ENDIF}
{$IFDEF LOCK_SPINLOCK}
  if IsMultiThread and (InterLockedCompareExchange(FSpinLock, 1, 0) <> 0) then
  begin
    Sleep(0);
    while InterLockedCompareExchange(FSpinLock, 1, 0) <> 0 do
      Sleep(1);
  end;
{$ENDIF}
{$IFDEF LOCK_OPTEX}
  iSpinCount := FSpinCount;
  dwThreadId  := GetCurrentThreadId;

  // Spin and try to acquire the lock
  repeat
    bTookOwnership := InterlockedCompareExchange(FLockRequests, 1, 0) = 0;
    if bTookOwnership then
    begin
      FOwningThreadID := dwThreadId;
      FLockDepth      := 1;
    end
    else if (FOwningThreadID = dwThreadId) then
    begin
      // The current thread owns the lock; increment the lock depth
      // and lock request count.
      Inc(FLockDepth);
      InterlockedIncrement(FLockRequests);
      bTookOwnership := True;
    end;
    Dec(iSpinCount);
  until bTookOwnership or (iSpinCount <= 0);

  if (not bTookOwnership) then
  begin
    // Failed to acquire the lock while spinning.
    // Issue a normal lock request.
    if InterlockedIncrement(FLockRequests) = 1 then
    begin
      FOwningThreadID := dwThreadId;
      FLockDepth      := 1;
    end
    else
    begin
      if FOwningThreadID = dwThreadId then
        Inc(FLockDepth) // The current thread owns the lock; increment the lock depth.
      else
      begin
        // Sorry, the lock is owned by another thread. Wait.
        if FEvent = INVALID_HANDLE_VALUE then
        begin
          // Just-in-time event creation.
          // Create the event kernel object as auto-reset.
          hNewEvent := CreateEventW(nil, False, False, nil);
          if InterlockedCompareExchange(Integer(FEvent), Integer(hNewEvent), 0) <> 0 then
            CloseHandle(hNewEvent);
          // Another thread has already created the event: delete it!
        end;
        WaitForSingleObject(FEvent, INFINITE);

        // OK, may own the lock now.
        FOwningThreadID := dwThreadId;
        FLockDepth      := 1;
      end;
    end;
  end;
{$ENDIF}
end;

procedure TFastLock.Leave;
{$IFDEF LOCK_OPTEX}
var
  hNewEvent: THandle;
{$ENDIF}
begin
{$IFDEF LOCK_CRITSEC}
  LeaveCriticalSection(FSection);
{$ENDIF}
{$IFDEF LOCK_SPINLOCK}
  FSpinLock := 0;
{$ENDIF}
{$IFDEF LOCK_OPTEX}
  // Decrement the lock depth
  Dec(FLockDepth);

  if (FLockDepth > 0) then
    InterlockedDecrement(FLockRequests)
  else
  begin
    // The current thread loses ownership of the lock.
    FOwningThreadID := 0;

    if InterlockedDecrement(FLockRequests) > 0 then
    begin
      // Some threads are waiting for the lock.
      // Set the event, which releases one of the waiting threads.
      // The event is then automatically reset.
      if (FEvent = INVALID_HANDLE_VALUE) then
      begin
        // Just-in-time event creation.
        // Create the event kernel object as auto-reset.
        hNewEvent := CreateEventW(nil, False, False, nil);
        if InterlockedCompareExchange(Integer(FEvent), Integer(hNewEvent), 0) <> 0 then
          CloseHandle(hNewEvent);
        // Another thread has already created the event: delete it!
      end;
      SetEvent(FEvent);
    end;
  end;
{$ENDIF}
end;

// /////////////////////////////////////////////////////////////////////////////
// TSwimerge
// /////////////////////////////////////////////////////////////////////////////

constructor TSwimerge.Create;
begin
  inherited;
  InitializeCriticalSection(FCriticalSection);
////////////////////////////////////////////////////////////////////////////////
// TODO:
//  FSemReaders       := GSemaphorePool.Get;
//  FSemWriters       := GSemaphorePool.Get;
////////////////////////////////////////////////////////////////////////////////
  FActiveReaders    := 0;
  FWriterActive     := False;
  FActiveWriterID   := 0;
  FWaitingReaders   := 0;
  FWaitingWriters   := 0;
  FWriterReadRefCnt := 0;
  FWriterWriteRefCnt := 0;
end;

// /////////////////////////////////////////////////////////////////////////////

destructor TSwimerge.Destroy;
begin
  DeleteCriticalSection(FCriticalSection);
////////////////////////////////////////////////////////////////////////////////
// TODO:
//  GSemaphorePool.Put(FSemReaders);
//  GSemaphorePool.Put(FSemWriters);
////////////////////////////////////////////////////////////////////////////////
  inherited;
end;

// /////////////////////////////////////////////////////////////////////////////

procedure TSwimerge.BeginRead;
var
  MustWait : boolean;
begin
  EnterCriticalSection(FCriticalSection);

  try
    // If the active writer is trying to read then automatically grant access.
    if FWriterActive and (FActiveWriterID = GetCurrentThreadID) then
    begin
      Inc(FWriterReadRefCnt);
      LeaveCriticalSection(FCriticalSection);
      Exit;
    end;

    // If a writer has been granted access or there is at least one writer
    // waiting for access, increment waiting readers counter. Also make sure it
    // waits wait it's turn.
    if FWriterActive or (FWaitingWriters <> 0) then
    begin
      Inc(FWaitingReaders);
      MustWait := True;
    end
    else
    begin
      // Otherwise, increment the active readers counter. We need not wait for
      // read access.
      Inc(FActiveReaders);
      MustWait := False;
    end;

  finally
     LeaveCriticalSection(FCriticalSection);
  end;

  if MustWait then
    WaitForSingleObject(FSemReaders, INFINITE);
end;

// /////////////////////////////////////////////////////////////////////////////

procedure TSwimerge.BeginWrite;
var
  MustWait : boolean;
begin
  EnterCriticalSection(FCriticalSection);
  try

    // If the active writer is calling BeginWrite once more, increment the
    // reference count for write access and grant access.
    if FWriterActive and (FActiveWriterID = GetCurrentThreadID) then begin
      Inc(FWriterWriteRefCnt);
      LeaveCriticalSection(FCriticalSection);
      Exit;
    end;

    // If there are active readers or an active writer, increment the waiting
    // writer count. Also make sure it waits wait it's turn.
    if FWriterActive or (FActiveReaders <> 0) then
    begin
      inc(FWaitingWriters);
      MustWait := True;
    end
    else
    begin
      // Otherwise, mark it as the active writer and grant access.
      FWriterActive := True;
      MustWait := False;
    end;
  finally
  LeaveCriticalSection(FCriticalSection);
  end;

  if MustWait then
    WaitForSingleObject(FSemWriters, INFINITE);

  // If we reach this point then the calling thread has write access. Store its
  // ThreadID so that BeginRead knows who we are. Set its reference counts.
  FActiveWriterID := GetCurrentThreadID;
  FWriterReadRefCnt := 0;
  FWriterWriteRefCnt := 1;
end;

// /////////////////////////////////////////////////////////////////////////////

procedure TSwimerge.EndRead;
begin
  EnterCriticalSection(FCriticalSection);
  try

    // If a writer is active and it is calling EndRead then decrement the read
    // count.
    if FWriterActive and (FActiveWriterID = GetCurrentThreadID) then begin
        Dec(FWriterReadRefCnt);
        LeaveCriticalSection(FCriticalSection);
        Exit;
    end;

    if FActiveReaders > 0 then
      Dec(FActiveReaders);

    // If the calling thread is the last reader and there is at least one
    // waiting writer, activate the waiting writer.
    if (FActiveReaders = 0) and (FWaitingWriters <> 0) then
    begin
      Dec(FWaitingWriters);
      FWriterActive := True;
      ReleaseSemaphore(FSemWriters, 1, nil);
    end;
  finally
     LeaveCriticalSection(FCriticalSection);
  end;

end;

// /////////////////////////////////////////////////////////////////////////////

procedure TSwimerge.EndWrite;
var
  tmpWaiting : integer;
begin
  EnterCriticalSection(FCriticalSection);
  try

    // If this is the writer thread, see if this is the final call to
    // EndWrite. If not then just exist the method.
    if FActiveWriterID = GetCurrentThreadID then
    begin
      Dec(FWriterWriteRefCnt);
      if FWriterWriteRefCnt > 0 then
      begin
        LeaveCriticalSection(FCriticalSection);
        Exit;
      end;
    end;

    FWriterActive := false;
    FActiveWriterID := 0;

    { If there are any waiting readers then release them. }
    if (FWaitingReaders <> 0) then begin
      tmpWaiting := FWaitingReaders;
      dec(FWaitingReaders, FWaitingReaders);
      inc(FActiveReaders, tmpWaiting);
      ReleaseSemaphore(FSemReaders, tmpWaiting, nil);
    end else if (FWaitingWriters <> 0) then begin
      { Otherwise if there is at least one waiting writer then release one. }
      dec(FWaitingWriters);
      FWriterActive := true;
      ReleaseSemaphore(FSemWriters, 1, nil);
    end;
  finally
  LeaveCriticalSection(FCriticalSection);
  end;
end;


{$IFDEF LOCK_OPTEX}
initialization
  GetProcessorCount;
{$ENDIF}
end.
