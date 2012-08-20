{ *********************************************************************** }
{                                                                         }
{  Borland Delphi Memory Manager                                          }
{                                                                         }
{  Copyright (c) 1996-2006 Borland Software Corporation                   }
{                                                                         }
{  Portions created by Pierre le Riche are                                }
{   Copyright (c) Pierre le Riche / Professional Software Development     }
{                                                                         }
{  Acknowledgement: With special thanks to the Fastcode community and     }
{   supporters for their valuable input and feedback.                     }
{                                                                         }
{                                                                         }
{ *********************************************************************** }

(* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1
 *
 * This memory manager implementation is subject to the
 * Mozilla Public License Version 1.1 (the "License"); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * ***** END LICENSE BLOCK ***** *)

{-----------------------------Options Block-------------------------------}
{Enable to use the pascal code path}
{.$define UsePascalCode}
{Include the memory leak tracking and reporting code. Without this define set
 the memory leak registration functions will do nothing and the memory leak
 report will not be shown on shutdown.}
{$define IncludeMemoryLeakTrackingCode}
{Use custom fixed size move routines for some small blocks}
{$define UseCustomFixedSizeMoveRoutines}
{Use custom variable size move routines for larger blocks}
{$define UseCustomVariableSizeMoveRoutines}

{--------------------------------Windows API------------------------------}
const
  {Memory constants}
  MEM_COMMIT = $1000;
  MEM_RESERVE  = $2000;
  MEM_RELEASE = $8000;
  MEM_FREE = $10000;
  MEM_TOP_DOWN = $100000;
  PAGE_READONLY = 2;
  PAGE_READWRITE = 4;
  PAGE_EXECUTE = $10;
  PAGE_EXECUTE_READ = $20;
  PAGE_EXECUTE_READWRITE = $40;
  PAGE_EXECUTE_WRITECOPY = $80;
  PAGE_GUARD = $100;
  {Window constants}
  GWL_USERDATA = -21;
  WS_POPUP = Integer($80000000);
  {Messagebox Constants}
  MB_OK = $00000000;
  MB_ICONERROR = $00000010;
  MB_TASKMODAL = $00002000;

type
  DWORD = Integer;
  BOOL = LongBool;
  HWND = LongWord;
  HMENU = LongWord;

function VirtualAlloc(lpAddress: Pointer;
  dwSize, flAllocationType, flProtect: DWORD): Pointer; stdcall;
  external kernel name 'VirtualAlloc';
function VirtualFree(lpAddress: Pointer; dwSize, dwFreeType: DWORD): BOOL; stdcall;
  external kernel name 'VirtualFree';
procedure Sleep(dwMilliseconds: DWORD); stdcall;
  external kernel name 'Sleep';
function GetCurrentProcessId: DWORD; stdcall;
  external kernel name 'GetCurrentProcessId';
function CreateWindowEx(dwExStyle: DWORD; lpClassName: PChar;
  lpWindowName: PChar; dwStyle: DWORD; X, Y, nWidth, nHeight: Integer;
  hWndParent: HWND; hMenu: HMENU; hInstance: HINST; lpParam: Pointer): HWND; stdcall;
  external user name 'CreateWindowExA';
function DestroyWindow(hWnd: HWND): BOOL; stdcall;
  external user name 'DestroyWindow';
function FindWindow(lpClassName, lpWindowName: PChar): HWND; stdcall;
  external user name 'FindWindowA';
function GetWindowLong(hWnd: HWND; nIndex: Integer): Longint; stdcall;
  external user name 'GetWindowLongA';
function SetWindowLong(hWnd: HWND; nIndex: Integer; dwNewLong: Longint): Longint; stdcall;
  external user name 'SetWindowLongA';

{-------------------------Fixed size move procedures----------------------}
{$ifdef UseCustomFixedSizeMoveRoutines}
procedure Move12(const ASource; var ADest; ACount: Integer); forward;
procedure Move20(const ASource; var ADest; ACount: Integer); forward;
procedure Move28(const ASource; var ADest; ACount: Integer); forward;
procedure Move36(const ASource; var ADest; ACount: Integer); forward;
procedure Move44(const ASource; var ADest; ACount: Integer); forward;
procedure Move52(const ASource; var ADest; ACount: Integer); forward;
procedure Move60(const ASource; var ADest; ACount: Integer); forward;
procedure Move68(const ASource; var ADest; ACount: Integer); forward;
{$endif}

{---------------------------Private constants-----------------------------}
const
  {The size of a medium block pool. This is allocated through VirtualAlloc and
   is used to serve medium blocks. The size must be a multiple of 16 and at
   least 4 bytes less than a multiple of 4K (the page size) to prevent a
   possible read access violation when reading past the end of a memory block
   in the optimized move routine (MoveX16L4).}
  MediumBlockPoolSize = 20 * 64 * 1024 - 16;
  {The granularity of small blocks}
  SmallBlockGranularity = 8;
  {The granularity of medium blocks. Newly allocated medium blocks are
   a multiple of this size plus MediumBlockSizeOffset, to avoid cache line
   conflicts}
  MediumBlockGranularity = 256;
  MediumBlockSizeOffset = 48;
  {The granularity of large blocks}
  LargeBlockGranularity = 65536;
  {The maximum size of a small block. Blocks Larger than this are either
   medium or large blocks.}
  MaximumSmallBlockSize = 2608;
  {The smallest medium block size. (Medium blocks are rounded up to the nearest
   multiple of MediumBlockGranularity plus MediumBlockSizeOffset)}
  MinimumMediumBlockSize = 11 * 256 + MediumBlockSizeOffset;
  {The number of bins reserved for medium blocks}
  MediumBlockBinsPerGroup = 32;
  MediumBlockBinGroupCount = 32;
  MediumBlockBinCount = MediumBlockBinGroupCount * MediumBlockBinsPerGroup;
  {The maximum size allocatable through medium blocks. Blocks larger than this
   fall through to VirtualAlloc ( = large blocks).}
  MaximumMediumBlockSize = MinimumMediumBlockSize + (MediumBlockBinCount - 1) * MediumBlockGranularity;
  {The target number of small blocks per pool. The actual number of blocks per
   pool may be much greater for very small sizes and less for larger sizes. The
   cost of allocating the small block pool is amortized across all the small
   blocks in the pool, however the blocks may not all end up being used so they
   may be lying idle.}
  TargetSmallBlocksPerPool = 48;
  {The minimum number of small blocks per pool. Any available medium block must
   have space for roughly this many small blocks (or more) to be useable as a
   small block pool.}
  MinimumSmallBlocksPerPool = 12;
  {The lower and upper limits for the optimal small block pool size}
  OptimalSmallBlockPoolSizeLowerLimit = 29 * 1024 - MediumBlockGranularity + MediumBlockSizeOffset;
  OptimalSmallBlockPoolSizeUpperLimit = 64 * 1024 - MediumBlockGranularity + MediumBlockSizeOffset;
  {The maximum small block pool size. If a free block is this size or larger
   then it will be split.}
  MaximumSmallBlockPoolSize = OptimalSmallBlockPoolSizeUpperLimit + MinimumMediumBlockSize;
  {----------------------------Block type flags---------------------------}
  {The lower 3 bits in the dword header of small blocks (4 bits in medium and
   large blocks) are used as flags to indicate the state of the block}
  {Set if the block is not in use}
  IsFreeBlockFlag = 1;
  {Set if this is a medium block}
  IsMediumBlockFlag = 2;
  {Set if it is a medium block being used as a small block pool. Only valid if
   IsMediumBlockFlag is set.}
  IsSmallBlockPoolInUseFlag = 4;
  {Set if it is a large block. Only valid if IsMediumBlockFlag is not set.}
  IsLargeBlockFlag = 4;
  {Is the medium block preceding this block available?}
  PreviousMediumBlockIsFreeFlag = 8;
  {Is this large block segmented? I.e. is it actually built up from more than
   one chunk allocated through VirtualAlloc? (Only used by large blocks.)}
  LargeBlockIsSegmented = 8;
  {The flags masks for small blocks}
  DropSmallFlagsMask = -8;
  ExtractSmallFlagsMask = 7;
  {The flags masks for medium and large blocks}
  DropMediumAndLargeFlagsMask = -16;
  ExtractMediumAndLargeFlagsMask = 15;
  {-------------------------Block resizing constants----------------------}
  SmallBlockDownsizeCheckAdder = 64;
  SmallBlockUpsizeAdder = 32;
  {When a medium block is reallocated to a size smaller than this, then it must
   be reallocated to a small block and the data moved. If not, then it is
   shrunk in place down to MinimumMediumBlockSize. Currently the limit is set
   at a quarter of the minimum medium block size.}
  MediumInPlaceDownsizeLimit = MinimumMediumBlockSize div 4;
  {-----------------------------Other constants---------------------------}
  {Sleep time when a resource (small/medium/large block manager) is in use}
  InitialSleepTime = 0;
  {Used when the resource is still in use after the first sleep}
  AdditionalSleepTime = 10;
  {Hexadecimal characters}
  HexTable: array[0..15] of char = '0123456789ABCDEF';
  {Copyright message - not used anywhere in the code}
  Copyright: string = 'FastMM Borland Edition © 2004, 2005 Pierre le Riche / Professional Software Development';
{$ifdef IncludeMemoryLeakTrackingCode}
  {-----------------------Memory leak reporting constants-----------------}
  ExpectedMemoryLeaksListSize = 64 * 1024;
  {-------------------Memory leak messages (may be localized)-------------}
  {Leak checking messages}
  LeakMessageHeader = 'An unexpected memory leak has occurred. ';
  SmallLeakDetail = 'The unexpected small block leaks are:'#13#10;
  LargeLeakDetail = 'The sizes of unexpected leaked medium and large blocks are: ';
  BytesMessage = ' bytes: ';
  UnknownClassNameMsg = 'Unknown';
  StringBlockMessage = 'String';
  LeakMessageFooter = #13#10#0;
  LeakMessageTitle = 'Unexpected Memory Leak';
{$endif}
  {Sharing errors}
  ShareMMErrorTitle = 'Cannot Switch Memory Manager';
  LivePointersErrorMsg = 'The memory manager cannot be changed after it has been used.';
  BeingSharedErrorMsg = 'The memory manager cannot be changed if it is being shared.';

{------------------------------Private types------------------------------}
type

  {Move procedure type}
  TMoveProc = procedure(const ASource; var ADest; ACount: Integer);

  {-----------------------Small block structures--------------------------}

  {Pointer to the header of a small block pool}
  PSmallBlockPoolHeader = ^TSmallBlockPoolHeader;

  {Small block type (Size = 32)}
  PSmallBlockType = ^TSmallBlockType;
  TSmallBlockType = packed record
    {True = Block type is locked}
    BlockTypeLocked: boolean;
    {Bitmap indicating which of the first 8 medium block groups contain blocks
     of a suitable size for a block pool.}
    AllowedGroupsForBlockPoolBitmap: byte;
    {The block size for this block type}
    BlockSize: Word;
    {The first partially free pool for the given small block type (offset = +4
     for typecast compatibility with TSmallBlockPoolHeader). This is a circular
     buffer.}
    NextPartiallyFreePool: PSmallBlockPoolHeader;
    {The offset of the last block that was served sequentially (0ffset = +8 to
     to be at the same offset as the "FirstFreeBlock" of TSmallBlockPoolHeader}
    NextSequentialFeedBlockAddress: Pointer;
    {The last block that can be served sequentially. Offset is at +12 to be
     at the same address as the "BlocksInUse" field of TSmallBlockPoolHeader}
    MaxSequentialFeedBlockAddress: Pointer;
    {The pool that is current being used to serve blocks in sequential order}
    CurrentSequentialFeedPool: PSmallBlockPoolHeader;
    {The previous partially free pool for the small block type (offset = +20
     for typecast compatibility with TSmallBlockPoolHeader)}
    PreviousPartiallyFreePool: PSmallBlockPoolHeader;
    {The minimum and optimal size of a small block pool for this block type}
    MinimumBlockPoolSize: Word;
    OptimalBlockPoolSize: Word;
{$ifdef UseCustomFixedSizeMoveRoutines}
    {The fixed size move procedure used to move data for this block size when
     it is upsized. When a block is downsized (which usually does not occur
     that often) the variable size move routine is used.}
    UpsizeMoveProcedure: TMoveProc;
{$else}
    Reserved: Cardinal;
{$endif}
  end;

  {Small block pool (Size = 32 bytes)}
  TSmallBlockPoolHeader = packed record
    {BlockType}
    BlockType: PSmallBlockType;
    {The next pool that has free blocks of this size. Must be at offset +4
     to be typecast compatible with TSmallBlockType}
    NextPartiallyFreePool: PSmallBlockPoolHeader;
    {Pointer to the first free block inside this pool. Must be at offset + 8
     to be at the same offset as "NextSequentialFeedBlockAddress" of
     TSmallBlockType}
    FirstFreeBlock: Pointer;
    {The number of blocks allocated in this pool. Must be at offset + 12
     to be at the same offset as "MaxSequentialFeedBlockAddress" of
     TSmallBlockType}
    BlocksInUse: Cardinal;
    {Small block pool signature. Used by the leak checking mechanism to
     determine whether a medium block is a small block pool or a regular medium
     block.}
    SmallBlockPoolSignature: Cardinal;
    {The previous pool that has free blocks of this size. Must be at offset +20
     to be compatible with TSmallBlockType}
    PreviousPartiallyFreePool: PSmallBlockPoolHeader;
    {Reserved}
    Reserved1: Cardinal;
    {The pool pointer and flags of the first block}
    FirstBlockPoolPointerAndFlags: Cardinal;
  end;

  {Small block layout:
   Offset: -4 = Flags + address of the small block pool
   Offset: BlockSize - 4 = Flags + address of the small block pool for the next small block
  }

  {------------------------Medium block structures------------------------}

  {The medium block pool from which medium blocks are drawn}
  PMediumBlockPoolHeader = ^TMediumBlockPoolHeader;
  TMediumBlockPoolHeader = packed record
    {Points to the previous and next medium block pools. This circular linked
     list is used to track memory leaks on program shutdown.}
    PreviousMediumBlockPoolHeader: PMediumBlockPoolHeader;
    NextMediumBlockPoolHeader: PMediumBlockPoolHeader;
    {Unused dword}
    Reserved: Cardinal;
    {The block size and flags of the first medium block in the block pool}
    FirstMediumBlockSizeAndFlags: Cardinal;
  end;

  {Medium block layout:
   Offset: -8 = Previous Block Size (only if the previous block is free)
   Offset: -4 = This block size and flags
   Offset: 0 = User data / Previous Free Block (if this block is free)
   Offset: 4 = Next Free Block (if this block is free)
   Offset: BlockSize - 8 = Size of this block (if this block is free)
   Offset: BlockSize - 4 = Size of the next block and flags

  {A medium block that is unused}
  PMediumFreeBlock = ^TMediumFreeBlock;
  TMediumFreeBlock = packed record
    PreviousFreeBlock: PMediumFreeBlock;
    NextFreeBlock: PMediumFreeBlock;
  end;

  {-------------------------Large block structures------------------------}

  {Large block header record (size = 16)}
  PLargeBlockHeader = ^TLargeBlockHeader;
  TLargeBlockHeader = packed record
    {Points to the previous and next large blocks. This circular linked
     list is used to track memory leaks on program shutdown.}
    PreviousLargeBlockHeader: PLargeBlockHeader;
    NextLargeBlockHeader: PLargeBlockHeader;
    {The user allocated size of the Large block}
    UserAllocatedSize: Cardinal;
    {The size of this block plus the flags}
    BlockSizeAndFlags: Cardinal;
  end;

  {--------------------Expected Memory Leak Structures--------------------}

{$ifdef IncludeMemoryLeakTrackingCode}
  TExpectedMemoryLeaks = packed record
    {The number of entries used in the expected leaks buffer}
    NumExpectedLeaks: Integer;
    {The expected leaks buffer}
    ExpectedLeaks: array[0..(ExpectedMemoryLeaksListSize - 4) div 4 - 1] of Pointer;
  end;
  PExpectedMemoryLeaks = ^TExpectedMemoryLeaks;
{$endif}

{---------------------------Private constants-----------------------------}
const
  {The size of the block header in front of small and medium blocks}
  BlockHeaderSize = 4;
  {The size of a small block pool header}
  SmallBlockPoolHeaderSize = SizeOf(TSmallBlockPoolHeader);
  {The size of a medium block pool header}
  MediumBlockPoolHeaderSize = SizeOf(TMediumBlockPoolHeader);
  {The size of the header in front of Large blocks}
  LargeBlockHeaderSize = SizeOf(TLargeBlockHeader);
  {This memory manager}
  ThisMemoryManager: TMemoryManagerEx = (
    GetMem: SysGetMem;
    FreeMem: SysFreeMem;
    ReallocMem: SysReallocMem;
    AllocMem: SysAllocMem;
    RegisterExpectedMemoryLeak: SysRegisterExpectedMemoryLeak;
    UnregisterExpectedMemoryLeak: SysUnregisterExpectedMemoryLeak);

{---------------------------Private variables-----------------------------}
var
  {-----------------------Small block management--------------------------}
  {The small block types. Sizes include the leading 4-byte overhead. Sizes are
   picked to limit maximum wastage to about 10% or 256 bytes (whichever is
   less) where possible.}
  SmallBlockTypes: packed array[0..NumSmallBlockTypes - 1] of TSmallBlockType =(
    {8/16 byte jumps}
    (BlockSize: 16{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move12{$endif}),
    (BlockSize: 24{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move20{$endif}),
    (BlockSize: 32{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move28{$endif}),
    (BlockSize: 40{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move36{$endif}),
    (BlockSize: 48{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move44{$endif}),
    (BlockSize: 56{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move52{$endif}),
    (BlockSize: 64{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move60{$endif}),
    (BlockSize: 72{$ifdef UseCustomFixedSizeMoveRoutines}; UpsizeMoveProcedure: Move68{$endif}),
    (BlockSize: 80),
    (BlockSize: 88),
    (BlockSize: 96),
    (BlockSize: 104),
    (BlockSize: 112),
    (BlockSize: 120),
    (BlockSize: 128),
    (BlockSize: 136),
    (BlockSize: 144),
    (BlockSize: 152),
    (BlockSize: 160),
    {16 byte jumps}
    (BlockSize: 176),
    (BlockSize: 192),
    (BlockSize: 208),
    (BlockSize: 224),
    (BlockSize: 240),
    (BlockSize: 256),
    (BlockSize: 272),
    (BlockSize: 288),
    (BlockSize: 304),
    (BlockSize: 320),
    {32 byte jumps}
    (BlockSize: 352),
    (BlockSize: 384),
    (BlockSize: 416),
    (BlockSize: 448),
    (BlockSize: 480),
    {48 byte jumps}
    (BlockSize: 528),
    (BlockSize: 576),
    (BlockSize: 624),
    (BlockSize: 672),
    {64 byte jumps}
    (BlockSize: 736),
    (BlockSize: 800),
    {80 byte jumps}
    (BlockSize: 880),
    (BlockSize: 960),
    {96 byte jumps}
    (BlockSize: 1056),
    (BlockSize: 1152),
    {112 byte jumps}
    (BlockSize: 1264),
    (BlockSize: 1376),
    {128 byte jumps}
    (BlockSize: 1504),
    {144 byte jumps}
    (BlockSize: 1648),
    {160 byte jumps}
    (BlockSize: 1808),
    {176 byte jumps}
    (BlockSize: 1984),
    {192 byte jumps}
    (BlockSize: 2176),
    {208 byte jumps}
    (BlockSize: 2384),
    {224 byte jumps}
    (BlockSize: MaximumSmallBlockSize),
    {The last block size occurs three times. If, during a GetMem call, the
     requested block size is already locked by another thread then up to two
     larger block sizes may be used instead. Having the last block size occur
     three times avoids the need to have a size overflow check.}
    (BlockSize: MaximumSmallBlockSize),
    (BlockSize: MaximumSmallBlockSize));
  {Size to small block type translation table}
  AllocSize2SmallBlockTypeIndX4: packed array[0..(MaximumSmallBlockSize - 1) div SmallBlockGranularity] of byte;
  {The minimum block alignment}
  MinimumBlockAlignment: TMinimumBlockAlignment;
  {-----------------------Medium block management-------------------------}
  {A dummy medium block pool header: Maintains a circular list of all medium
   block pools to enable memory leak detection on program shutdown.}
  MediumBlockPoolsCircularList: TMediumBlockPoolHeader;
  {Are medium blocks locked?}
  MediumBlocksLocked: boolean;
  {The sequential feed medium block pool.}
  LastSequentiallyFedMediumBlock: Pointer;
  MediumSequentialFeedBytesLeft: Cardinal;
  {The medium block bins are divided into groups of 32 bins. If a bit
   is set in this group bitmap, then at least one bin in the group has free
   blocks.}
  MediumBlockBinGroupBitmap: Cardinal;
  {The medium block bins: total of 32 * 32 = 1024 bins of a certain
   minimum size.}
  MediumBlockBinBitmaps: packed array[0..MediumBlockBinGroupCount - 1] of Cardinal;
  {The medium block bins. There are 1024 LIFO circular linked lists each
   holding blocks of a specified minimum size. The sizes vary in size from
   MinimumMediumBlockSize to MaximumMediumBlockSize. The bins are treated as
   type TMediumFreeBlock to avoid pointer checks.}
  MediumBlockBins: packed array[0..MediumBlockBinCount - 1] of TMediumFreeBlock;
  {-------------------------Large block management------------------------}
  {Are large blocks locked?}
  LargeBlocksLocked: boolean;
  {A dummy large block header: Maintains a list of all allocated large blocks
   to enable memory leak detection on program shutdown.}
  LargeBlocksCircularList: TLargeBlockHeader;
  {---------------------Expected Memory Leak Structures-------------------}
{$ifdef IncludeMemoryLeakTrackingCode}
  {The expected memory leaks}
  ExpectedMemoryLeaks: PExpectedMemoryLeaks;
  ExpectedMemoryLeaksListLocked: Boolean;
{$endif}
  {------------------------------Other info-------------------------------}
  {A string uniquely identifying the current process (for sharing the memory
   manager between DLLs and the main application)}
  UniqueProcessIDString: String[23] = '????????_PID_FastMM_BE'#0;
  {The handle of the MM window}
  MMSharingWindow: HWND;

{----------------------------Utility Functions----------------------------}

{Compare [AAddress], CompareVal:
 If Equal: [AAddress] := NewVal and result = CompareVal
 If Unequal: Result := [AAddress]}
function LockCmpxchg(CompareVal, NewVal: byte; AAddress: PByte): Byte;
asm
  {On entry:
    al = CompareVal,
    dl = NewVal,
    ecx = AAddress}
  lock cmpxchg [ecx], dl
end;

{$ifdef UsePascalCode}
{Gets the first set bit and resets it, returning the bit index}
function FindFirstSetBit(ACardinal: Cardinal): Cardinal;
asm
  {On entry:
    eax = ACardinal}
  bsf eax, eax
end;
{$endif}

{----------------------Specialised Move Procedures------------------------}

{$ifdef UseCustomFixedSizeMoveRoutines}
{Fixed size move operations ignore the size parameter. All moves are assumed to
 be non-overlapping.}

procedure Move12(const ASource; var ADest; ACount: Integer);
asm
  mov ecx, [eax]
  mov [edx], ecx
  mov ecx, [eax + 4]
  mov eax, [eax + 8]
  mov [edx + 4], ecx
  mov [edx + 8], eax
end;

procedure Move20(const ASource; var ADest; ACount: Integer);
asm
  mov ecx, [eax]
  mov [edx], ecx
  mov ecx, [eax + 4]
  mov [edx + 4], ecx
  mov ecx, [eax + 8]
  mov [edx + 8], ecx
  mov ecx, [eax + 12]
  mov eax, [eax + 16]
  mov [edx + 12], ecx
  mov [edx + 16], eax
end;

procedure Move28(const ASource; var ADest; ACount: Integer);
asm
  mov ecx, [eax]
  mov [edx], ecx
  mov ecx, [eax + 4]
  mov [edx + 4], ecx
  mov ecx, [eax + 8]
  mov [edx + 8], ecx
  mov ecx, [eax + 12]
  mov [edx + 12], ecx
  mov ecx, [eax + 16]
  mov [edx + 16], ecx
  mov ecx, [eax + 20]
  mov eax, [eax + 24]
  mov [edx + 20], ecx
  mov [edx + 24], eax
end;

procedure Move36(const ASource; var ADest; ACount: Integer);
asm
  fild qword ptr [eax]
  fild qword ptr [eax + 8]
  fild qword ptr [eax + 16]
  fild qword ptr [eax + 24]
  mov ecx, [eax + 32]
  mov [edx + 32], ecx
  fistp qword ptr [edx + 24]
  fistp qword ptr [edx + 16]
  fistp qword ptr [edx + 8]
  fistp qword ptr [edx]
end;

procedure Move44(const ASource; var ADest; ACount: Integer);
asm
  fild qword ptr [eax]
  fild qword ptr [eax + 8]
  fild qword ptr [eax + 16]
  fild qword ptr [eax + 24]
  fild qword ptr [eax + 32]
  mov ecx, [eax + 40]
  mov [edx + 40], ecx
  fistp qword ptr [edx + 32]
  fistp qword ptr [edx + 24]
  fistp qword ptr [edx + 16]
  fistp qword ptr [edx + 8]
  fistp qword ptr [edx]
end;

procedure Move52(const ASource; var ADest; ACount: Integer);
asm
  fild qword ptr [eax]
  fild qword ptr [eax + 8]
  fild qword ptr [eax + 16]
  fild qword ptr [eax + 24]
  fild qword ptr [eax + 32]
  fild qword ptr [eax + 40]
  mov ecx, [eax + 48]
  mov [edx + 48], ecx
  fistp qword ptr [edx + 40]
  fistp qword ptr [edx + 32]
  fistp qword ptr [edx + 24]
  fistp qword ptr [edx + 16]
  fistp qword ptr [edx + 8]
  fistp qword ptr [edx]
end;

procedure Move60(const ASource; var ADest; ACount: Integer);
asm
  fild qword ptr [eax]
  fild qword ptr [eax + 8]
  fild qword ptr [eax + 16]
  fild qword ptr [eax + 24]
  fild qword ptr [eax + 32]
  fild qword ptr [eax + 40]
  fild qword ptr [eax + 48]
  mov ecx, [eax + 56]
  mov [edx + 56], ecx
  fistp qword ptr [edx + 48]
  fistp qword ptr [edx + 40]
  fistp qword ptr [edx + 32]
  fistp qword ptr [edx + 24]
  fistp qword ptr [edx + 16]
  fistp qword ptr [edx + 8]
  fistp qword ptr [edx]
end;

procedure Move68(const ASource; var ADest; ACount: Integer);
asm
  fild qword ptr [eax]
  fild qword ptr [eax + 8]
  fild qword ptr [eax + 16]
  fild qword ptr [eax + 24]
  fild qword ptr [eax + 32]
  fild qword ptr [eax + 40]
  fild qword ptr [eax + 48]
  fild qword ptr [eax + 56]
  mov ecx, [eax + 64]
  mov [edx + 64], ecx
  fistp qword ptr [edx + 56]
  fistp qword ptr [edx + 48]
  fistp qword ptr [edx + 40]
  fistp qword ptr [edx + 32]
  fistp qword ptr [edx + 24]
  fistp qword ptr [edx + 16]
  fistp qword ptr [edx + 8]
  fistp qword ptr [edx]
end;
{$endif}

{$ifdef UseCustomVariableSizeMoveRoutines}
{Variable size move procedure: Assumes ACount is 4 less than a multiple of 16.
 Always moves at least 12 bytes, irrespective of ACount.}
procedure MoveX16L4(const ASource; var ADest; ACount: Integer);
asm
  {Make the counter negative based: The last 12 bytes are moved separately}
  sub ecx, 12
  add eax, ecx
  add edx, ecx
  neg ecx
  jns @MoveLast12
@MoveLoop:
  {Move a 16 byte block}
  fild qword ptr [eax + ecx]
  fild qword ptr [eax + ecx + 8]
  fistp qword ptr [edx + ecx + 8]
  fistp qword ptr [edx + ecx]
  {Are there another 16 bytes to move?}
  add ecx, 16
  js @MoveLoop
@MoveLast12:
  {Do the last 12 bytes}
  fild qword ptr [eax + ecx]
  fistp qword ptr [edx + ecx]
  mov eax, [eax + ecx + 8]
  mov [edx + ecx + 8], eax
end;

{Variable size move procedure: Assumes ACount is 4 less than a multiple of 8.
 Always moves at least 12 bytes, irrespective of ACount.}
procedure MoveX8L4(const ASource; var ADest; ACount: Integer);
asm
  {Make the counter negative based: The last 4 bytes are moved separately}
  sub ecx, 4
  add eax, ecx
  add edx, ecx
  neg ecx
@MoveLoop:
  {Move an 8 byte block}
  fild qword ptr [eax + ecx]
  fistp qword ptr [edx + ecx]
  {Are there another 8 bytes to move?}
  add ecx, 8
  js @MoveLoop
  {Do the last 4 bytes}
  mov eax, [eax + ecx]
  mov [edx + ecx], eax
end;
{$endif}

{-------------------------Small Block Management-------------------------}

{Locks all small block types}
procedure LockAllSmallBlockTypes;
var
  LInd: Cardinal;
begin
  if IsMultiThread then
  begin
    for LInd := 0 to NumSmallBlockTypes - 1 do
    begin
      while LockCmpxchg(0, 1, @SmallBlockTypes[LInd].BlockTypeLocked) <> 0 do
      begin
        if not NeverSleepOnMMThreadContention then
        begin
          Sleep(InitialSleepTime);
          if LockCmpxchg(0, 1, @SmallBlockTypes[LInd].BlockTypeLocked) = 0 then
            break;
          Sleep(AdditionalSleepTime);
        end;
      end;
    end;
  end;
end;

{-------------------------Medium Block Management-------------------------}

{Locks the medium blocks}
procedure LockMediumBlocks;
begin
  {Lock the medium blocks}
  if IsMultiThread then
  begin
    while LockCmpxchg(0, 1, @MediumBlocksLocked) <> 0 do
    begin
      if not NeverSleepOnMMThreadContention then
      begin
        Sleep(InitialSleepTime);
        if LockCmpxchg(0, 1, @MediumBlocksLocked) = 0 then
          break;
        Sleep(AdditionalSleepTime);
      end;
    end;
  end;
end;

{Removes a medium block from the circular linked list of free blocks.
 Does not change any header flags. Medium blocks should be locked
 before calling this procedure.}
{$ifdef UsePascalCode}
procedure RemoveMediumFreeBlock(APMediumFreeBlock: PMediumFreeBlock);
var
  LPreviousFreeBlock, LNextFreeBlock: PMediumFreeBlock;
  LBinNumber, LBinGroupNumber: Cardinal;
begin
  {Get the current previous and next blocks}
  LNextFreeBlock := APMediumFreeBlock.NextFreeBlock;
  LPreviousFreeBlock := APMediumFreeBlock.PreviousFreeBlock;
  {Remove this block from the linked list}
  LPreviousFreeBlock.NextFreeBlock := LNextFreeBlock;
  LNextFreeBlock.PreviousFreeBlock := LPreviousFreeBlock;
  {Is this bin now empty? If the previous and next free block pointers are
   equal, they must point to the bin.}
  if LPreviousFreeBlock = LNextFreeBlock then
  begin
    {Get the bin number for this block size}
    LBinNumber := (Cardinal(LNextFreeBlock) - Cardinal(@MediumBlockBins)) div SizeOf(TMediumFreeBlock);
    LBinGroupNumber := LBinNumber div 32;
    {Flag this bin as empty}
    MediumBlockBinBitmaps[LBinGroupNumber] := MediumBlockBinBitmaps[LBinGroupNumber]
      and (not (1 shl (LBinNumber and 31)));
    {Is the group now entirely empty?}
    if MediumBlockBinBitmaps[LBinGroupNumber] = 0 then
    begin
      {Flag this group as empty}
      MediumBlockBinGroupBitmap := MediumBlockBinGroupBitmap
        and (not (1 shl LBinGroupNumber));
    end;
  end;
end;
{$else}
procedure RemoveMediumFreeBlock(APMediumFreeBlock: PMediumFreeBlock);
asm
  {On entry: eax = APMediumFreeBlock}
  {Get the current previous and next blocks}
  mov ecx, TMediumFreeBlock[eax].NextFreeBlock
  mov edx, TMediumFreeBlock[eax].PreviousFreeBlock
  {Is this bin now empty? If the previous and next free block pointers are
   equal, they must point to the bin.}
  cmp ecx, edx
  {Remove this block from the linked list}
  mov TMediumFreeBlock[ecx].PreviousFreeBlock, edx
  mov TMediumFreeBlock[edx].NextFreeBlock, ecx
  {Is this bin now empty? If the previous and next free block pointers are
   equal, they must point to the bin.}
  je @BinIsNowEmpty
@Done:
  ret
  {Align branch target}
  nop
@BinIsNowEmpty:
  {Get the bin number for this block size in ecx}
  sub ecx, offset MediumBlockBins
  mov edx, ecx
  shr ecx, 3
  {Get the group number in edx}
  movzx edx, dh
  {Flag this bin as empty}
  mov eax, -2
  rol eax, cl
  and dword ptr [MediumBlockBinBitmaps + edx * 4], eax
  jnz @Done
  {Flag this group as empty}
  mov eax, -2
  mov ecx, edx
  rol eax, cl
  and MediumBlockBinGroupBitmap, eax
end;
{$endif}

{Inserts a medium block into the appropriate medium block bin.}
{$ifdef UsePascalCode}
procedure InsertMediumBlockIntoBin(APMediumFreeBlock: PMediumFreeBlock; AMediumBlockSize: Cardinal);
var
  LBinNumber, LBinGroupNumber: Cardinal;
  LPBin, LPFirstFreeBlock: PMediumFreeBlock;
begin
  {Get the bin number for this block size. Get the bin that holds blocks of at
   least this size.}
  LBinNumber := (AMediumBlockSize - MinimumMediumBlockSize) div MediumBlockGranularity;
  if LBinNumber >= MediumBlockBinCount then
    LBinNumber := MediumBlockBinCount - 1;
  {Get the bin}
  LPBin := @MediumBlockBins[LBinNumber];
  {Bins are LIFO, se we insert this block as the first free block in the bin}
  LPFirstFreeBlock := LPBin.NextFreeBlock;
  APMediumFreeBlock.PreviousFreeBlock := LPBin;
  APMediumFreeBlock.NextFreeBlock := LPFirstFreeBlock;
  LPFirstFreeBlock.PreviousFreeBlock := APMediumFreeBlock;
  LPBin.NextFreeBlock := APMediumFreeBlock;
  {Was this bin empty?}
  if LPFirstFreeBlock = LPBin then
  begin
    {Get the group number}
    LBinGroupNumber := LBinNumber div 32;
    {Flag this bin as used}
    MediumBlockBinBitmaps[LBinGroupNumber] := MediumBlockBinBitmaps[LBinGroupNumber]
      or (1 shl (LBinNumber and 31));
    {Flag the group as used}
    MediumBlockBinGroupBitmap := MediumBlockBinGroupBitmap
      or (1 shl LBinGroupNumber);
  end;
end;
{$else}
procedure InsertMediumBlockIntoBin(APMediumFreeBlock: PMediumFreeBlock; AMediumBlockSize: Cardinal);
asm
  {On entry: eax = APMediumFreeBlock, edx = AMediumBlockSize}
  {Get the bin number for this block size. Get the bin that holds blocks of at
   least this size.}
  sub edx, MinimumMediumBlockSize
  shr edx, 8
  {Validate the bin number}
  sub edx, MediumBlockBinCount - 1
  sbb ecx, ecx
  and edx, ecx
  add edx, MediumBlockBinCount - 1
  {Get the bin in ecx}
  lea ecx, [MediumBlockBins + edx * 8]
  {Bins are LIFO, se we insert this block as the first free block in the bin}
  mov edx, TMediumFreeBlock[ecx].NextFreeBlock
  {Was this bin empty?}
  cmp edx, ecx
  mov TMediumFreeBlock[eax].PreviousFreeBlock, ecx
  mov TMediumFreeBlock[eax].NextFreeBlock, edx
  mov TMediumFreeBlock[edx].PreviousFreeBlock, eax
  mov TMediumFreeBlock[ecx].NextFreeBlock, eax
  {Was this bin empty?}
  je @BinWasEmpty
  ret
  {Align branch target}
  nop
  nop
@BinWasEmpty:
  {Get the bin number in ecx}
  sub ecx, offset MediumBlockBins
  mov edx, ecx
  shr ecx, 3
  {Get the group number in edx}
  movzx edx, dh
  {Flag this bin as not empty}
  mov eax, 1
  shl eax, cl
  or dword ptr [MediumBlockBinBitmaps + edx * 4], eax
  {Flag the group as not empty}
  mov eax, 1
  mov ecx, edx
  shl eax, cl
  or MediumBlockBinGroupBitmap, eax
end;
{$endif}

{Bins what remains in the current sequential feed medium block pool. Medium
 blocks must be locked.}
{$ifdef UsePascalCode}
procedure BinMediumSequentialFeedRemainder;
var
  LSequentialFeedFreeSize, LNextBlockSizeAndFlags: Cardinal;
  LPRemainderBlock, LNextMediumBlock: Pointer;
begin
  LSequentialFeedFreeSize := MediumSequentialFeedBytesLeft;
  if LSequentialFeedFreeSize > 0 then
  begin
    {Get the block after the open space}
    LNextMediumBlock := LastSequentiallyFedMediumBlock;
    LNextBlockSizeAndFlags := PCardinal(Cardinal(LNextMediumBlock) - BlockHeaderSize)^;
    {Point to the remainder}
    LPRemainderBlock := Pointer(Cardinal(LNextMediumBlock) - LSequentialFeedFreeSize);
    {Can the next block be combined with the remainder?}
    if (LNextBlockSizeAndFlags and IsFreeBlockFlag) <> 0 then
    begin
      {Increase the size of this block}
      Inc(LSequentialFeedFreeSize, LNextBlockSizeAndFlags and DropMediumAndLargeFlagsMask);
      {Remove the next block as well}
      if (LNextBlockSizeAndFlags and DropMediumAndLargeFlagsMask) >= MinimumMediumBlockSize then
        RemoveMediumFreeBlock(LNextMediumBlock);
    end
    else
    begin
      {Set the "previous block is free" flag of the next block}
      PCardinal(Cardinal(LNextMediumBlock) - BlockHeaderSize)^ := LNextBlockSizeAndFlags or PreviousMediumBlockIsFreeFlag;
    end;
    {Store the size of the block as well as the flags}
    PCardinal(Cardinal(LPRemainderBlock) - BlockHeaderSize)^ := LSequentialFeedFreeSize or IsMediumBlockFlag or IsFreeBlockFlag;
    {Store the trailing size marker}
    PCardinal(Cardinal(LPRemainderBlock) + LSequentialFeedFreeSize - 8)^ := LSequentialFeedFreeSize;
    {Bin this medium block}
    if LSequentialFeedFreeSize >= MinimumMediumBlockSize then
    begin
      InsertMediumBlockIntoBin(LPRemainderBlock, LSequentialFeedFreeSize);
    end;
  end;
end;
{$else}
procedure BinMediumSequentialFeedRemainder;
asm
  cmp MediumSequentialFeedBytesLeft, 0
  jne @MustBinMedium
  {Nothing to bin}
  ret
  {Align branch target}
  nop
  nop
@MustBinMedium:
  {Get a pointer to the last sequentially allocated medium block}
  mov eax, LastSequentiallyFedMediumBlock
  {Is the block that was last fed sequentially free?}
  test byte ptr [eax - 4], IsFreeBlockFlag
  jnz @LastBlockFedIsFree
  {Set the "previous block is free" flag in the last block fed}
  or dword ptr [eax - 4], PreviousMediumBlockIsFreeFlag
  {Get the remainder in edx}
  mov edx, MediumSequentialFeedBytesLeft
  {Point eax to the start of the remainder}
  sub eax, edx
@BinTheRemainder:
  {Status: eax = start of remainder, edx = size of remainder}
  {Store the size of the block as well as the flags}
  lea ecx, [edx + IsMediumBlockFlag + IsFreeBlockFlag]
  mov [eax - 4], ecx
  {Store the trailing size marker}
  mov [eax + edx - 8], edx
  {Bin this medium block}
  cmp edx, MinimumMediumBlockSize
  jnb InsertMediumBlockIntoBin
  ret
  {Align branch target}
  nop
  nop
@LastBlockFedIsFree:
  {Drop the flags}
  mov edx, DropMediumAndLargeFlagsMask
  and edx, [eax - 4]
  {Free the last block fed}
  cmp edx, MinimumMediumBlockSize
  jb @DontRemoveLastFed
  {Last fed block is free - remove it from its size bin}
  call RemoveMediumFreeBlock
  {Re-read eax and edx}
  mov eax, LastSequentiallyFedMediumBlock
  mov edx, DropMediumAndLargeFlagsMask
  and edx, [eax - 4]
@DontRemoveLastFed:
  {Get the number of bytes left in ecx}
  mov ecx, MediumSequentialFeedBytesLeft
  {Point eax to the start of the remainder}
  sub eax, ecx
  {edx = total size of the remainder}
  add edx, ecx
  jmp @BinTheRemainder
end;
{$endif}

{Allocates a new sequential feed medium block pool and immediately splits off a
 block of the requested size. The block size must be a multiple of 16 and
 medium blocks must be locked.}
function AllocNewSequentialFeedMediumPool(AFirstBlockSize: Cardinal): Pointer;
var
  LOldFirstMediumBlockPool: PMediumBlockPoolHeader;
  LNewPool: Pointer;
begin
  {Bin the current sequential feed remainder}
  BinMediumSequentialFeedRemainder;
  {Allocate a new sequential feed block pool}
  LNewPool := VirtualAlloc(nil, MediumBlockPoolSize, MEM_COMMIT, PAGE_READWRITE);
  if LNewPool <> nil then
  begin
    {Insert this block pool into the list of block pools}
    LOldFirstMediumBlockPool := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
    PMediumBlockPoolHeader(LNewPool).PreviousMediumBlockPoolHeader := @MediumBlockPoolsCircularList;
    MediumBlockPoolsCircularList.NextMediumBlockPoolHeader := LNewPool;
    PMediumBlockPoolHeader(LNewPool).NextMediumBlockPoolHeader := LOldFirstMediumBlockPool;
    LOldFirstMediumBlockPool.PreviousMediumBlockPoolHeader := LNewPool;
    {Store the sequential feed pool trailer}
    PCardinal(Cardinal(LNewPool) + MediumBlockPoolSize - BlockHeaderSize)^ := IsMediumBlockFlag;
    {Get the number of bytes still available}
    MediumSequentialFeedBytesLeft := (MediumBlockPoolSize - MediumBlockPoolHeaderSize) - AFirstBlockSize;
    {Get the result}
    Result := Pointer(Cardinal(LNewPool) + MediumBlockPoolSize - AFirstBlockSize);
    LastSequentiallyFedMediumBlock := Result;
    {Store the block header}
    PCardinal(Cardinal(Result) - BlockHeaderSize)^ := AFirstBlockSize or IsMediumBlockFlag;
  end
  else
  begin
    {Out of memory}
    MediumSequentialFeedBytesLeft := 0;
    Result := nil;
  end;
end;

{Frees a medium block pool. Medium blocks must be locked on entry.}
procedure FreeMediumBlockPool(AMediumBlockPool: PMediumBlockPoolHeader);
var
  LPPreviousMediumBlockPoolHeader, LPNextMediumBlockPoolHeader: PMediumBlockPoolHeader;
begin
  {Remove this medium block pool from the linked list}
  LPPreviousMediumBlockPoolHeader := AMediumBlockPool.PreviousMediumBlockPoolHeader;
  LPNextMediumBlockPoolHeader := AMediumBlockPool.NextMediumBlockPoolHeader;
  LPPreviousMediumBlockPoolHeader.NextMediumBlockPoolHeader := LPNextMediumBlockPoolHeader;
  LPNextMediumBlockPoolHeader.PreviousMediumBlockPoolHeader := LPPreviousMediumBlockPoolHeader;
  {Free the medium block pool}
  VirtualFree(AMediumBlockPool, 0, MEM_RELEASE);
end;

{--------------------------Large Block Management-------------------------}

{Locks the large blocks}
procedure LockLargeBlocks;
begin
  {Lock the large blocks}
  if IsMultiThread then
  begin
    while LockCmpxchg(0, 1, @LargeBlocksLocked) <> 0 do
    begin
      if not NeverSleepOnMMThreadContention then
      begin
        Sleep(InitialSleepTime);
        if LockCmpxchg(0, 1, @LargeBlocksLocked) = 0 then
          break;
        Sleep(AdditionalSleepTime);
      end;
    end;
  end;
end;

{Allocates a Large block of at least ASize (actual size may be Larger to
 allow for alignment etc.). ASize must be the actual user requested size. This
 procedure will pad it to the appropriate page boundary and also add the space
 required by the header.}
function AllocateLargeBlock(ASize: Cardinal): Pointer;
var
  LLargeUsedBlockSize: Cardinal;
  LOldFirstLargeBlock: PLargeBlockHeader;
begin
  {Pad the block size to include the header and granularity. We also add a
   4-byte overhead so a huge block size is a multiple of 16 bytes less 4 (so we
   can use a single move function for reallocating all block types)}
  LLargeUsedBlockSize := (ASize + LargeBlockHeaderSize + LargeBlockGranularity - 1 + BlockHeaderSize)
    and -LargeBlockGranularity;
  {Get the Large block}
  Result := VirtualAlloc(nil, LLargeUsedBlockSize, MEM_COMMIT or MEM_TOP_DOWN,
    PAGE_READWRITE);
  {Set the Large block fields}
  if Result <> nil then
  begin
    {Set the large block size and flags}
    PLargeBlockHeader(Result).UserAllocatedSize := ASize;
    PLargeBlockHeader(Result).BlockSizeAndFlags := LLargeUsedBlockSize or IsLargeBlockFlag;
    {Insert the large block into the linked list of large blocks}
    LockLargeBlocks;
    LOldFirstLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
    PLargeBlockHeader(Result).PreviousLargeBlockHeader := @LargeBlocksCircularList;
    LargeBlocksCircularList.NextLargeBlockHeader := Result;
    PLargeBlockHeader(Result).NextLargeBlockHeader := LOldFirstLargeBlock;
    LOldFirstLargeBlock.PreviousLargeBlockHeader := Result;
    LargeBlocksLocked := False;
    {Add the size of the header}
    Inc(Cardinal(Result), LargeBlockHeaderSize);
  end;
end;

{Frees a large block, returning 0 on success, -1 otherwise}
function FreeLargeBlock(APointer: Pointer): Integer;
var
  LPreviousLargeBlockHeader, LNextLargeBlockHeader: PLargeBlockHeader;
  LRemainingSize: Cardinal;
  LCurrentSegment: Pointer;
  LMemInfo: TMemInfo;
begin
  {Point to the start of the large block}
  APointer := Pointer(Cardinal(APointer) - LargeBlockHeaderSize);
  {Get the previous and next large blocks}
  LockLargeBlocks;
  LPreviousLargeBlockHeader := PLargeBlockHeader(APointer).PreviousLargeBlockHeader;
  LNextLargeBlockHeader := PLargeBlockHeader(APointer).NextLargeBlockHeader;
  {Is the large block segmented?}
  if PLargeBlockHeader(APointer).BlockSizeAndFlags and LargeBlockIsSegmented = 0 then
  begin
    {Single segment large block: Try to free it}
    if VirtualFree(APointer, 0, MEM_RELEASE) then
      Result := 0
    else
      Result := -1;
  end
  else
  begin
    {The large block is segmented - free all segments}
    LCurrentSegment := APointer;
    LRemainingSize := PLargeBlockHeader(APointer).BlockSizeAndFlags and DropMediumAndLargeFlagsMask;
    Result := 0;
    while True do
    begin
      {Get the size of the current segment}
      VirtualQuery(LCurrentSegment, LMemInfo, SizeOf(LMemInfo));
      {Free the segment}
      if not VirtualFree(LCurrentSegment, 0, MEM_RELEASE) then
      begin
        Result := -1;
        break;
      end;
      {Done?}
      if Cardinal(LMemInfo.RegionSize) >= LRemainingSize then
        Break;
      {Decrement the remaining size}
      Dec(LRemainingSize, Cardinal(LMemInfo.RegionSize));
      Inc(Cardinal(LCurrentSegment), Cardinal(LMemInfo.RegionSize));
    end;
  end;
  {Success?}
  if Result = 0 then
  begin
    {Remove the large block from the linked list}
    LNextLargeBlockHeader.PreviousLargeBlockHeader := LPreviousLargeBlockHeader;
    LPreviousLargeBlockHeader.NextLargeBlockHeader := LNextLargeBlockHeader;
  end;
  {Unlock the large blocks}
  LargeBlocksLocked := False;
end;

{Reallocates a large block to at least the requested size. Returns the new
 pointer, or nil on error}
function ReallocateLargeBlock(APointer: Pointer; ANewSize: Cardinal): Pointer;
var
  LOldAvailableSize, LBlockHeader, LOldUserSize, LMinimumUpsize,
    LNewAllocSize: Cardinal;
  LNewSegmentSize: Cardinal;
  LNextSegmentPointer: Pointer;
  LMemInfo: TMemInfo;
begin
  {Get the block header}
  LBlockHeader := PCardinal(Cardinal(APointer) - BlockHeaderSize)^;
  {Large block - size is (16 + 4) less than the allocated size}
  LOldAvailableSize := (LBlockHeader and DropMediumAndLargeFlagsMask) - (LargeBlockHeaderSize + BlockHeaderSize);
  {Is it an upsize or a downsize?}
  if Cardinal(ANewSize) > LOldAvailableSize then
  begin
    {This pointer is being reallocated to a larger block and therefore it is
     logical to assume that it may be enlarged again. Since reallocations are
     expensive, there is a minimum upsize percentage to avoid unnecessary
     future move operations.}
    {Add 25% for large block upsizes}
    LMinimumUpsize := Cardinal(LOldAvailableSize)
      + (Cardinal(LOldAvailableSize) shr 2);
    if Cardinal(ANewSize) < LMinimumUpsize then
      LNewAllocSize := LMinimumUpsize
    else
      LNewAllocSize := ANewSize;
    {Can another large block segment be allocated directly after this segment,
     thus negating the need to move the data?}
    LNextSegmentPointer := Pointer(Cardinal(APointer) - LargeBlockHeaderSize + (LBlockHeader and DropMediumAndLargeFlagsMask));
    VirtualQuery(LNextSegmentPointer, LMemInfo, SizeOf(LMemInfo));
    if (LMemInfo.State = MEM_FREE) then
    begin
      {Round the region size to the previous 64K}
      LMemInfo.RegionSize := LMemInfo.RegionSize and -LargeBlockGranularity;
      {Enough space to grow in place?}
      if (Cardinal(LMemInfo.RegionSize) > (ANewSize - LOldAvailableSize)) then
      begin
        {There is enough space after the block to extend it - determine by how
         much}
        LNewSegmentSize := (LNewAllocSize - LOldAvailableSize + LargeBlockGranularity - 1) and -LargeBlockGranularity;
        if LNewSegmentSize > Cardinal(LMemInfo.RegionSize) then
          LNewSegmentSize := Cardinal(LMemInfo.RegionSize);
        if (VirtualAlloc(LNextSegmentPointer, LNewSegmentSize, MEM_RESERVE, PAGE_READWRITE) <> nil)
          and (VirtualAlloc(LNextSegmentPointer, LNewSegmentSize, MEM_COMMIT, PAGE_READWRITE) <> nil) then
        begin
          {Update the requested size}
          PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).UserAllocatedSize := ANewSize;
          PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).BlockSizeAndFlags :=
            (PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).BlockSizeAndFlags + LNewSegmentSize)
            or LargeBlockIsSegmented;
          {Success}
          Result := APointer;
          exit;
        end;
      end;
    end;
    {Could not resize in place: Allocate the new block}
    Result := SysGetMem(LNewAllocSize);
    if Result <> nil then
    begin
      {If it's a large block - store the actual user requested size (it may
       not be if the block that is being reallocated from was previously
       downsized)}
      if LNewAllocSize > (MaximumMediumBlockSize - BlockHeaderSize) then
        PLargeBlockHeader(Cardinal(Result) - LargeBlockHeaderSize).UserAllocatedSize := ANewSize;
      {The user allocated size is stored for large blocks}
      LOldUserSize := PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).UserAllocatedSize;
      {The number of bytes to move is the old user size.}
{$ifdef UseCustomVariableSizeMoveRoutines}
      MoveX16L4(APointer^, Result^, LOldUserSize);
{$else}
      Move(APointer^, Result^, LOldUserSize);
{$endif}
      {Free the old block}
      SysFreeMem(APointer);
    end;
  end
  else
  begin
    {It's a downsize: do we need to reallocate? Only if the new size is less
     than half the old size}
    if Cardinal(ANewSize) >= (LOldAvailableSize shr 1) then
    begin
      {No need to reallocate}
      Result := APointer;
      {Update the requested size}
      PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).UserAllocatedSize := ANewSize;
    end
    else
    begin
      {The block is less than half the old size: reallocate}
      Result := SysGetMem(ANewSize);
      if Result <> nil then
      begin
        {Still a large block? -> Set the user size}
        if ANewSize > (MaximumMediumBlockSize - BlockHeaderSize) then
          PLargeBlockHeader(Cardinal(APointer) - LargeBlockHeaderSize).UserAllocatedSize := ANewSize;
        {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
        MoveX8L4(APointer^, Result^, ANewSize);
{$else}
        Move(APointer^, Result^, ANewSize);
{$endif}
        {Free the old block}
        SysFreeMem(APointer);
      end;
    end;
  end;
end;

{----------------------Main Memory Manager Functions----------------------}

{$ifdef UsePascalCode}
function SysGetMem(Size: Integer): Pointer;
var
  LMediumBlock, LNextFreeBlock, LSecondSplit: PMediumFreeBlock;
  LNextMediumBlockHeader: PCardinal;
  LBlockSize, LAvailableBlockSize, LSecondSplitSize: Cardinal;
  LPSmallBlockType: PSmallBlockType;
  LPSmallBlockPool, LPNewFirstPool: PSmallBlockPoolHeader;
  LBinNumber: Cardinal;
  LNewFirstFreeBlock: Pointer;
  LPMediumBin: PMediumFreeBlock;
  LSequentialFeedFreeSize: Cardinal;
  LBinGroupsMasked, LBinGroupMasked, LBinGroupNumber: Cardinal;
begin
  {Is it a small block? -> Take the header size into account when
   determining the required block size}
  if Cardinal(Size) <= (MaximumSmallBlockSize - BlockHeaderSize) then
  begin
    {-----------------------Allocate a small block------------------------}
    {Get the block type from the size}
    LPSmallBlockType := PSmallBlockType(AllocSize2SmallBlockTypeIndX4[
      (Cardinal(Size) + (BlockHeaderSize - 1)) div SmallBlockGranularity] * 8
      + Cardinal(@SmallBlockTypes));
    {Lock the block type}
    if IsMultiThread then
    begin
      while True do
      begin
        {Try to lock the small block type}
        if LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) = 0 then
          break;
        {Try the next block type}
        Inc(Cardinal(LPSmallBlockType), SizeOf(TSmallBlockType));
        if LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) = 0 then
          break;
        {Try up to two sizes past the requested size}
        Inc(Cardinal(LPSmallBlockType), SizeOf(TSmallBlockType));
        if LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) = 0 then
          break;
        {All three sizes locked - given up and sleep}
        Dec(Cardinal(LPSmallBlockType), 2 * SizeOf(TSmallBlockType));
        if not NeverSleepOnMMThreadContention then
        begin
          {Both this block type and the next is in use: sleep}
          Sleep(InitialSleepTime);
          {Try the lock again}
          if LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) = 0 then
            break;
          {Sleep longer}
          Sleep(AdditionalSleepTime);
        end;
      end;
    end;
    {Get the first pool with free blocks}
    LPSmallBlockPool := LPSmallBlockType.NextPartiallyFreePool;
    {Is the pool valid?}
    if Cardinal(LPSmallBlockPool) <> Cardinal(LPSmallBlockType) then
    begin
      {Get the first free offset}
      Result := LPSmallBlockPool.FirstFreeBlock;
      {Get the new first free block}
      LNewFirstFreeBlock := PPointer(Cardinal(Result) - 4)^;
      LNewFirstFreeBlock := Pointer(Cardinal(LNewFirstFreeBlock) and DropSmallFlagsMask);
      {Increment the number of used blocks}
      Inc(LPSmallBlockPool.BlocksInUse);
      {Set the new first free block}
      LPSmallBlockPool.FirstFreeBlock := LNewFirstFreeBlock;
      {Is the pool now full?}
      if LNewFirstFreeBlock = nil then
      begin
        {Pool is full - remove it from the partially free list}
        LPNewFirstPool := LPSmallBlockPool.NextPartiallyFreePool;
        LPSmallBlockType.NextPartiallyFreePool := LPNewFirstPool;
        LPNewFirstPool.PreviousPartiallyFreePool := PSmallBlockPoolHeader(LPSmallBlockType);
      end;
    end
    else
    begin
      {Try to feed a small block sequentially}
      Result := LPSmallBlockType.NextSequentialFeedBlockAddress;
      {Can another block fit?}
      if Cardinal(Result) <= Cardinal(LPSmallBlockType.MaxSequentialFeedBlockAddress) then
      begin
        {Get the sequential feed block pool}
        LPSmallBlockPool := LPSmallBlockType.CurrentSequentialFeedPool;
        {Increment the number of used blocks in the sequential feed pool}
        Inc(LPSmallBlockPool.BlocksInUse);
        {Store the next sequential feed block address}
        LPSmallBlockType.NextSequentialFeedBlockAddress := Pointer(Cardinal(Result) + LPSmallBlockType.BlockSize);
      end
      else
      begin
        {Need to allocate a pool: Lock the medium blocks}
        LockMediumBlocks;
        {Are there any available blocks of a suitable size?}
        LBinGroupsMasked := MediumBlockBinGroupBitmap and ($ffffff00 or LPSmallBlockType.AllowedGroupsForBlockPoolBitmap);
        if LBinGroupsMasked <> 0 then
        begin
          {Get the bin group with free blocks}
          LBinGroupNumber := FindFirstSetBit(LBinGroupsMasked);
          {Get the bin in the group with free blocks}
          LBinNumber := FindFirstSetBit(MediumBlockBinBitmaps[LBinGroupNumber])
            + LBinGroupNumber * 32;
          LPMediumBin := @MediumBlockBins[LBinNumber];
          {Get the first block in the bin}
          LMediumBlock := LPMediumBin.NextFreeBlock;
          {Remove the first block from the linked list (LIFO)}
          LNextFreeBlock := LMediumBlock.NextFreeBlock;
          LPMediumBin.NextFreeBlock := LNextFreeBlock;
          LNextFreeBlock.PreviousFreeBlock := LPMediumBin;
          {Is this bin now empty?}
          if LNextFreeBlock = LPMediumBin then
          begin
            {Flag this bin as empty}
            MediumBlockBinBitmaps[LBinGroupNumber] := MediumBlockBinBitmaps[LBinGroupNumber]
              and (not (1 shl (LBinNumber and 31)));
            {Is the group now entirely empty?}
            if MediumBlockBinBitmaps[LBinGroupNumber] = 0 then
            begin
              {Flag this group as empty}
              MediumBlockBinGroupBitmap := MediumBlockBinGroupBitmap
                and (not (1 shl LBinGroupNumber));
            end;
          end;
          {Get the size of the available medium block}
          LBlockSize := PCardinal(Cardinal(LMediumBlock) - BlockHeaderSize)^ and DropMediumAndLargeFlagsMask;
          {Medium blocks are never split or coalesced in full debug mode}
          {Should the block be split?}
          if LBlockSize >= MaximumSmallBlockPoolSize then
          begin
            {Get the size of the second split}
            LSecondSplitSize := LBlockSize - LPSmallBlockType.OptimalBlockPoolSize;
            {Adjust the block size}
            LBlockSize := LPSmallBlockType.OptimalBlockPoolSize;
            {Split the block in two}
            LSecondSplit := PMediumFreeBlock(Cardinal(LMediumBlock) + LBlockSize);
            PCardinal(Cardinal(LSecondSplit) - BlockHeaderSize)^ := LSecondSplitSize or (IsMediumBlockFlag or IsFreeBlockFlag);
            {Store the size of the second split as the second last dword}
            PCardinal(Cardinal(LSecondSplit) + LSecondSplitSize - 8)^ := LSecondSplitSize;
            {Put the remainder in a bin (it will be big enough)}
            InsertMediumBlockIntoBin(LSecondSplit, LSecondSplitSize);
          end
          else
          begin
            {Mark this block as used in the block following it}
            LNextMediumBlockHeader := PCardinal(Cardinal(LMediumBlock) + LBlockSize - BlockHeaderSize);
            LNextMediumBlockHeader^ := LNextMediumBlockHeader^ and (not PreviousMediumBlockIsFreeFlag);
          end;
        end
        else
        begin
          {Check the sequential feed medium block pool for space}
          LSequentialFeedFreeSize := MediumSequentialFeedBytesLeft;
          if LSequentialFeedFreeSize >= LPSmallBlockType.MinimumBlockPoolSize then
          begin
            {Enough sequential feed space: Will the remainder be usable?}
            if LSequentialFeedFreeSize >= (LPSmallBlockType.OptimalBlockPoolSize + MinimumMediumBlockSize) then
            begin
              LBlockSize := LPSmallBlockType.OptimalBlockPoolSize;
            end
            else
              LBlockSize := LSequentialFeedFreeSize;
            {Get the block}
            LMediumBlock := Pointer(Cardinal(LastSequentiallyFedMediumBlock) - LBlockSize);
            {Update the sequential feed parameters}
            LastSequentiallyFedMediumBlock := LMediumBlock;
            MediumSequentialFeedBytesLeft := LSequentialFeedFreeSize - LBlockSize;
          end
          else
          begin
            {Need to allocate a new sequential feed medium block pool: use the
             optimal size for this small block pool}
            LBlockSize := LPSmallBlockType.OptimalBlockPoolSize;
            {Allocate the medium block pool}
            LMediumBlock := AllocNewSequentialFeedMediumPool(LBlockSize);
            if LMediumBlock = nil then
            begin
              {Out of memory}
              {Unlock the medium blocks}
              MediumBlocksLocked := False;
              {Unlock the block type}
              LPSmallBlockType.BlockTypeLocked := False;
              {Failed}
              Result := nil;
              {done}
              exit;
            end;
          end;
        end;
        {Mark this block as in use}
        {Set the size and flags for this block}
        PCardinal(Cardinal(LMediumBlock) - BlockHeaderSize)^ :=
          LBlockSize or IsMediumBlockFlag or IsSmallBlockPoolInUseFlag;
        {Unlock medium blocks}
        MediumBlocksLocked := False;
        {Set up the block pool}
        LPSmallBlockPool := PSmallBlockPoolHeader(LMediumBlock);
        LPSmallBlockPool.BlockType := LPSmallBlockType;
        LPSmallBlockPool.FirstFreeBlock := nil;
        LPSmallBlockPool.BlocksInUse := 1;
        {Set it up for sequential block serving}
        LPSmallBlockType.CurrentSequentialFeedPool := LPSmallBlockPool;
        Result := Pointer(Cardinal(LPSmallBlockPool) + SmallBlockPoolHeaderSize);
        LPSmallBlockType.NextSequentialFeedBlockAddress :=
          Pointer(Cardinal(Result) + LPSmallBlockType.BlockSize);
        LPSmallBlockType.MaxSequentialFeedBlockAddress :=
          Pointer(Cardinal(LPSmallBlockPool) + LBlockSize - LPSmallBlockType.BlockSize);
      end;
    end;
    {Unlock the block type}
    LPSmallBlockType.BlockTypeLocked := False;
    {Set the block header}
    PCardinal(Cardinal(Result) - BlockHeaderSize)^ := Cardinal(LPSmallBlockPool);
  end
  else
  begin
    {Medium block or Large block?}
    if Cardinal(Size) <= (MaximumMediumBlockSize - BlockHeaderSize) then
    begin
      {---------------------Allocate a medium block-----------------------}
      {Get the block size and bin number for this block size. Block sizes are
       rounded up to the next bin size.}
      LBlockSize := ((Cardinal(Size) + (MediumBlockGranularity - 1 + BlockHeaderSize - MediumBlockSizeOffset))
        and -MediumBlockGranularity) + MediumBlockSizeOffset;
      {Get the bin number}
      LBinNumber := (LBlockSize - MinimumMediumBlockSize) div MediumBlockGranularity;
      {Lock the medium blocks}
      LockMediumBlocks;
      {Calculate the bin group}
      LBinGroupNumber := LBinNumber div 32;
      {Is there a suitable block inside this group?}
      LBinGroupMasked := MediumBlockBinBitmaps[LBinGroupNumber] and -(1 shl (LBinNumber and 31));
      if LBinGroupMasked <> 0 then
      begin
        {Get the actual bin number}
        LBinNumber := FindFirstSetBit(LBinGroupMasked) + LBinGroupNumber * 32;
      end
      else
      begin
        {Try all groups greater than this group}
        LBinGroupsMasked := MediumBlockBinGroupBitmap and -(2 shl LBinGroupNumber);
        if LBinGroupsMasked <> 0 then
        begin
          {There is a suitable group with space: get the bin number}
          LBinGroupNumber := FindFirstSetBit(LBinGroupsMasked);
          {Get the bin in the group with free blocks}
          LBinNumber := FindFirstSetBit(MediumBlockBinBitmaps[LBinGroupNumber])
            + LBinGroupNumber * 32;
        end
        else
        begin
          {There are no bins with a suitable block: Sequentially feed the required block}
          LSequentialFeedFreeSize := MediumSequentialFeedBytesLeft;
          if LSequentialFeedFreeSize >= LBlockSize then
          begin
            {Block can be fed sequentially}
            Result := Pointer(Cardinal(LastSequentiallyFedMediumBlock) - LBlockSize);
            {Store the last sequentially fed block}
            LastSequentiallyFedMediumBlock := Result;
            {Store the remaining bytes}
            MediumSequentialFeedBytesLeft := LSequentialFeedFreeSize - LBlockSize;
            {Set the flags for the block}
            PCardinal(Cardinal(Result) - BlockHeaderSize)^ := LBlockSize or IsMediumBlockFlag;
          end
          else
          begin
            {Need to allocate a new sequential feed block}
            Result := AllocNewSequentialFeedMediumPool(LBlockSize);
          end;
          {Done}
          MediumBlocksLocked := False;
          exit;
        end;
      end;
      {If we get here we have a valid LBinGroupNumber and LBinNumber:
       Use the first block in the bin, splitting it if necessary}
      {Get a pointer to the bin}
      LPMediumBin := @MediumBlockBins[LBinNumber];
      {Get the result}
      Result := LPMediumBin.NextFreeBlock;
      {Remove the block from the bin containing it}
      RemoveMediumFreeBlock(Result);
      {Get the block size}
      LAvailableBlockSize := PCardinal(Cardinal(Result) - BlockHeaderSize)^
        and DropMediumAndLargeFlagsMask;
      {Is it an exact fit or not?}
      LSecondSplitSize := LAvailableBlockSize - LBlockSize;
      if LSecondSplitSize <> 0 then
      begin
        {Split the block in two}
        LSecondSplit := PMediumFreeBlock(Cardinal(Result) + LBlockSize);
        {Set the size of the second split}
        PCardinal(Cardinal(LSecondSplit) - BlockHeaderSize)^ :=
          LSecondSplitSize or (IsMediumBlockFlag or IsFreeBlockFlag);
        {Store the size of the second split as the second last dword}
        PCardinal(Cardinal(LSecondSplit) + LSecondSplitSize - 8)^ := LSecondSplitSize;
        {Put the remainder in a bin if it is big enough}
        if LSecondSplitSize >= MinimumMediumBlockSize then
          InsertMediumBlockIntoBin(LSecondSplit, LSecondSplitSize);
      end
      else
      begin
        {Mark this block as used in the block following it}
        LNextMediumBlockHeader := Pointer(Cardinal(Result) + LBlockSize - BlockHeaderSize);
        LNextMediumBlockHeader^ :=
          LNextMediumBlockHeader^ and (not PreviousMediumBlockIsFreeFlag);
      end;
      {Set the size and flags for this block}
      PCardinal(Cardinal(Result) - BlockHeaderSize)^ := LBlockSize or IsMediumBlockFlag;
      {Unlock the medium blocks}
      MediumBlocksLocked := False;
    end
    else
    begin
      {Allocate a Large block}
      if Size > 0 then
        Result := AllocateLargeBlock(Size)
      else
        Result := nil;
    end;
  end;
end;
{$else}
function SysGetMem(Size: Integer): Pointer;
asm
  {On entry:
    eax = ASize}
  {Since most allocations are for small blocks, determine the small block type
   index so long}
  lea edx, [eax + BlockHeaderSize - 1]
  shr edx, 3
  {Is it a small block?}
  cmp eax, (MaximumSmallBlockSize - BlockHeaderSize)
  {Save ebx}
  push ebx
  {Get the IsMultiThread variable so long}
  mov cl, IsMultiThread
  {Is it a small block?}
  ja @NotASmallBlock
  {Do we need to lock the block type?}
  test cl, cl
  {Get the small block type in ebx}
  movzx eax, byte ptr [AllocSize2SmallBlockTypeIndX4 + edx]
  lea ebx, [SmallBlockTypes + eax * 8]
  {Do we need to lock the block type?}
  jnz @LockBlockTypeLoop
@GotLockOnSmallBlockType:
  {Find the next free block: Get the first pool with free blocks in edx}
  mov edx, TSmallBlockType[ebx].NextPartiallyFreePool
  {Get the first free block (or the next sequential feed address if edx = ebx)}
  mov eax, TSmallBlockPoolHeader[edx].FirstFreeBlock
  {Get the drop flags mask in ecx so long}
  mov ecx, DropSmallFlagsMask
  {Is there a pool with free blocks?}
  cmp edx, ebx
  je @TrySmallSequentialFeed
  {Increment the number of used blocks}
  add TSmallBlockPoolHeader[edx].BlocksInUse, 1
  {Get the new first free block}
  and ecx, [eax - 4]
  {Set the new first free block}
  mov TSmallBlockPoolHeader[edx].FirstFreeBlock, ecx
  {Set the block header}
  mov [eax - 4], edx
  {Is the chunk now full?}
  jz @RemoveSmallPool
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, False
  {Restore ebx}
  pop ebx
  {All done}
  ret
  {Align branch target}
  nop
  nop
  nop
@TrySmallSequentialFeed:
  {Try to feed a small block sequentially: Get the sequential feed block pool}
  mov edx, TSmallBlockType[ebx].CurrentSequentialFeedPool
  {Get the next sequential feed address so long}
  movzx ecx, TSmallBlockType[ebx].BlockSize
  add ecx, eax
  {Can another block fit?}
  cmp eax, TSmallBlockType[ebx].MaxSequentialFeedBlockAddress
  {Can another block fit?}
  ja @AllocateSmallBlockPool
  {Increment the number of used blocks in the sequential feed pool}
  add TSmallBlockPoolHeader[edx].BlocksInUse, 1
  {Store the next sequential feed block address}
  mov TSmallBlockType[ebx].NextSequentialFeedBlockAddress, ecx
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, False
  {Set the block header}
  mov [eax - 4], edx
  {Restore ebx}
  pop ebx
  {All done}
  ret
  {Align branch target}
  nop
  nop
  nop
@RemoveSmallPool:
  {Pool is full - remove it from the partially free list}
  mov ecx, TSmallBlockPoolHeader[edx].NextPartiallyFreePool
  mov TSmallBlockPoolHeader[ecx].PreviousPartiallyFreePool, ebx
  mov TSmallBlockType[ebx].NextPartiallyFreePool, ecx
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, False
  {Restore ebx}
  pop ebx
  {All done}
  ret
  {Align branch target}
  nop
  nop
@LockBlockTypeLoop:
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {Try the next size}
  add ebx, Type(TSmallBlockType)
  mov eax, $100
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {Try the next size (up to two sizes larger)}
  add ebx, Type(TSmallBlockType)
  mov eax, $100
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {Block type and two sizes larger are all locked - sleep and/or retry}
  sub ebx, 2 * Type(TSmallBlockType)
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @LockBlockTypeLoop
  {Couldn't grab the block type - sleep and try again}
  push InitialSleepTime
  call Sleep
  {Try again}
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {Couldn't grab the block type - sleep and try again}
  push AdditionalSleepTime
  call Sleep
  {Try again}
  jmp @LockBlockTypeLoop
  {Align branch target}
@AllocateSmallBlockPool:
  {save additional registers}
  push esi
  push edi
  {Do we need to lock the medium blocks?}
  cmp IsMultiThread, False
  je @MediumBlocksLockedForPool
@LockMediumBlocksForPool:
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLockedForPool
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @LockMediumBlocksForPool
  {Couldn't lock the medium blocks - sleep and retry}
  push InitialSleepTime
  call Sleep
  {Try again}
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLockedForPool
  {Couldn't lock the medium blocks - sleep and try again}
  push AdditionalSleepTime
  call Sleep
  {Try again}
  jmp @LockMediumBlocksForPool
  {Align branch target}
@MediumBlocksLockedForPool:
  {Are there any available blocks of a suitable size?}
  movsx esi, TSmallBlockType[ebx].AllowedGroupsForBlockPoolBitmap
  and esi, MediumBlockBinGroupBitmap
  jz @NoSuitableMediumBlocks
  {Get the bin group number with free blocks in eax}
  bsf eax, esi
  {Get the bin number in ecx}
  lea esi, [eax * 8]
  mov ecx, dword ptr [MediumBlockBinBitmaps + eax * 4]
  bsf ecx, ecx
  lea ecx, [ecx + esi * 4]
  {Get a pointer to the bin in edi}
  lea edi, [MediumBlockBins + ecx * 8]
  {Get the free block in esi}
  mov esi, TMediumFreeBlock[edi].NextFreeBlock
  {Remove the first block from the linked list (LIFO)}
  mov edx, TMediumFreeBlock[esi].NextFreeBlock
  mov TMediumFreeBlock[edi].NextFreeBlock, edx
  mov TMediumFreeBlock[edx].PreviousFreeBlock, edi
  {Is this bin now empty?}
  cmp edi, edx
  jne @MediumBinNotEmpty
  {eax = bin group number, ecx = bin number, edi = @bin, esi = free block, ebx = block type}
  {Flag this bin as empty}
  mov edx, -2
  rol edx, cl
  and dword ptr [MediumBlockBinBitmaps + eax * 4], edx
  jnz @MediumBinNotEmpty
  {Flag the group as empty}
  btr MediumBlockBinGroupBitmap, eax
@MediumBinNotEmpty:
  {esi = free block, ebx = block type}
  {Get the size of the available medium block in edi}
  mov edi, DropMediumAndLargeFlagsMask
  and edi, [esi - 4]
  cmp edi, MaximumSmallBlockPoolSize
  jb @UseWholeBlock
  {Split the block: get the size of the second part, new block size is the
   optimal size}
  mov edx, edi
  movzx edi, TSmallBlockType[ebx].OptimalBlockPoolSize
  sub edx, edi
  {Split the block in two}
  lea eax, [esi + edi]
  lea ecx, [edx + IsMediumBlockFlag + IsFreeBlockFlag]
  mov [eax - 4], ecx
  {Store the size of the second split as the second last dword}
  mov [eax + edx - 8], edx
  {Put the remainder in a bin (it will be big enough)}
  call InsertMediumBlockIntoBin
  jmp @GotMediumBlock
  {Align branch target}
@NoSuitableMediumBlocks:
  {Check the sequential feed medium block pool for space}
  movzx ecx, TSmallBlockType[ebx].MinimumBlockPoolSize
  mov edi, MediumSequentialFeedBytesLeft
  cmp edi, ecx
  jb @AllocateNewSequentialFeed
  {Get the address of the last block that was fed}
  mov esi, LastSequentiallyFedMediumBlock
  {Enough sequential feed space: Will the remainder be usable?}
  movzx ecx, TSmallBlockType[ebx].OptimalBlockPoolSize
  lea edx, [ecx + MinimumMediumBlockSize]
  cmp edi, edx
  jb @NotMuchSpace
  mov edi, ecx
@NotMuchSpace:
  sub esi, edi
  {Update the sequential feed parameters}
  sub MediumSequentialFeedBytesLeft, edi
  mov LastSequentiallyFedMediumBlock, esi
  {Get the block pointer}
  jmp @GotMediumBlock
  {Align branch target}
@AllocateNewSequentialFeed:
  {Need to allocate a new sequential feed medium block pool: use the
   optimal size for this small block pool}
  movzx eax, TSmallBlockType[ebx].OptimalBlockPoolSize
  mov edi, eax
  {Allocate the medium block pool}
  call AllocNewSequentialFeedMediumPool
  mov esi, eax
  test eax, eax
  jnz @GotMediumBlock
  mov MediumBlocksLocked, al
  mov TSmallBlockType[ebx].BlockTypeLocked, al
  pop edi
  pop esi
  pop ebx
  ret
  {Align branch target}
@UseWholeBlock:
  {esi = free block, ebx = block type, edi = block size}
  {Mark this block as used in the block following it}
  and byte ptr [esi + edi - 4], not PreviousMediumBlockIsFreeFlag
@GotMediumBlock:
  {esi = free block, ebx = block type, edi = block size}
  {Set the size and flags for this block}
  lea ecx, [edi + IsMediumBlockFlag + IsSmallBlockPoolInUseFlag]
  mov [esi - 4], ecx
  {Unlock medium blocks}
  xor eax, eax
  mov MediumBlocksLocked, al
  {Set up the block pool}
  mov TSmallBlockPoolHeader[esi].BlockType, ebx
  mov TSmallBlockPoolHeader[esi].FirstFreeBlock, eax
  mov TSmallBlockPoolHeader[esi].BlocksInUse, 1
  {Set it up for sequential block serving}
  mov TSmallBlockType[ebx].CurrentSequentialFeedPool, esi
  {Return the pointer to the first block}
  lea eax, [esi + SmallBlockPoolHeaderSize]
  movzx ecx, TSmallBlockType[ebx].BlockSize
  lea edx, [eax + ecx]
  mov TSmallBlockType[ebx].NextSequentialFeedBlockAddress, edx
  add edi, esi
  sub edi, ecx
  mov TSmallBlockType[ebx].MaxSequentialFeedBlockAddress, edi
  {Unlock the small block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, False
  {Set the small block header}
  mov [eax - 4], esi
  {Restore registers}
  pop edi
  pop esi
  pop ebx
  {Done}
  ret
{--------------------------Medium block allocation------------------------}
  {Align branch target}
  nop
@LockMediumBlocks:
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLocked
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @LockMediumBlocks
  {Couldn't lock the medium blocks - sleep and try again}
  push InitialSleepTime
  call Sleep
  {Try again}
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLocked
  {Couldn't lock the medium blocks - sleep and try again}
  push AdditionalSleepTime
  call Sleep
  {Try again}
  jmp @LockMediumBlocks
  {Align branch target}
  nop
  nop
  nop
@NotASmallBlock:
  cmp eax, (MaximumMediumBlockSize - BlockHeaderSize)
  ja @IsALargeBlockRequest
  {Get the bin size for this block size. Block sizes are
   rounded up to the next bin size.}
  lea ebx, [eax + MediumBlockGranularity - 1 + BlockHeaderSize - MediumBlockSizeOffset]
  and ebx, -MediumBlockGranularity
  add ebx, MediumBlockSizeOffset
  {Do we need to lock the medium blocks?}
  test cl, cl
  jnz @LockMediumBlocks
@MediumBlocksLocked:
  {Get the bin number in ecx and the group number in edx}
  lea edx, [ebx - MinimumMediumBlockSize]
  mov ecx, edx
  shr edx, 8 + 5
  shr ecx, 8
  {Is there a suitable block inside this group?}
  mov eax, -1
  shl eax, cl
  and eax, dword ptr [MediumBlockBinBitmaps + edx * 4]
  jz @GroupIsEmpty
  {Get the actual bin number}
  and ecx, -32
  bsf eax, eax
  or ecx, eax
  jmp @GotBinAndGroup
  {Align branch target}
  nop
  nop
@GroupIsEmpty:
  {Try all groups greater than this group}
  mov eax, -2
  mov ecx, edx
  shl eax, cl
  and eax, MediumBlockBinGroupBitmap
  jz @TrySequentialFeedMedium
  {There is a suitable group with space: get the bin number}
  bsf edx, eax
  {Get the bin in the group with free blocks}
  mov eax, dword ptr [MediumBlockBinBitmaps + edx * 4]
  bsf ecx, eax
  mov eax, edx
  shl eax, 5
  or ecx, eax
  jmp @GotBinAndGroup
  {Align branch target}
  nop
@TrySequentialFeedMedium:
  mov ecx, MediumSequentialFeedBytesLeft
  {Block can be fed sequentially?}
  sub ecx, ebx
  jc @AllocateNewSequentialFeedForMedium
  {Get the block address}
  mov eax, LastSequentiallyFedMediumBlock
  sub eax, ebx
  mov LastSequentiallyFedMediumBlock, eax
  {Store the remaining bytes}
  mov MediumSequentialFeedBytesLeft, ecx
  {Set the flags for the block}
  or ebx, IsMediumBlockFlag
  mov [eax - 4], ebx
  jmp @MediumBlockGetDone
  {Align branch target}
@AllocateNewSequentialFeedForMedium:
  mov eax, ebx
  call AllocNewSequentialFeedMediumPool
@MediumBlockGetDone:
  mov MediumBlocksLocked, False
  pop ebx
  ret
  {Align branch target}
@GotBinAndGroup:
  {ebx = block size, ecx = bin number, edx = group number}
  push esi
  push edi
  {Get a pointer to the bin in edi}
  lea edi, [MediumBlockBins + ecx * 8]
  {Get the free block in esi}
  mov esi, TMediumFreeBlock[edi].NextFreeBlock
  {Remove the first block from the linked list (LIFO)}
  mov eax, TMediumFreeBlock[esi].NextFreeBlock
  mov TMediumFreeBlock[edi].NextFreeBlock, eax
  mov TMediumFreeBlock[eax].PreviousFreeBlock, edi
  {Is this bin now empty?}
  cmp edi, eax
  jne @MediumBinNotEmptyForMedium
  {eax = bin group number, ecx = bin number, edi = @bin, esi = free block, ebx = block size}
  {Flag this bin as empty}
  mov eax, -2
  rol eax, cl
  and dword ptr [MediumBlockBinBitmaps + edx * 4], eax
  jnz @MediumBinNotEmptyForMedium
  {Flag the group as empty}
  btr MediumBlockBinGroupBitmap, edx
@MediumBinNotEmptyForMedium:
  {esi = free block, ebx = block size}
  {Get the size of the available medium block in edi}
  mov edi, DropMediumAndLargeFlagsMask
  and edi, [esi - 4]
  {Get the size of the second split in edx}
  mov edx, edi
  sub edx, ebx
  jz @UseWholeBlockForMedium
  {Split the block in two}
  lea eax, [esi + ebx]
  lea ecx, [edx + IsMediumBlockFlag + IsFreeBlockFlag]
  mov [eax - 4], ecx
  {Store the size of the second split as the second last dword}
  mov [eax + edx - 8], edx
  {Put the remainder in a bin}
  cmp edx, MinimumMediumBlockSize
  jb @GotMediumBlockForMedium
  call InsertMediumBlockIntoBin
  jmp @GotMediumBlockForMedium
  {Align branch target}
  nop
  nop
  nop
@UseWholeBlockForMedium:
  {Mark this block as used in the block following it}
  and byte ptr [esi + edi - 4], not PreviousMediumBlockIsFreeFlag
@GotMediumBlockForMedium:
  {Set the size and flags for this block}
  lea ecx, [ebx + IsMediumBlockFlag]
  mov [esi - 4], ecx
  {Unlock medium blocks}
  mov MediumBlocksLocked, False
  mov eax, esi
  pop edi
  pop esi
  pop ebx
  ret
{---------------------------Large block allocation------------------------}
  {Align branch target}
@IsALargeBlockRequest:
  pop ebx
  test eax, eax
  jns AllocateLargeBlock
  xor eax, eax
end;
{$endif}

{$ifdef UsePascalCode}
function SysFreeMem(P: Pointer): Integer;
var
  LNextMediumBlock, LPreviousMediumBlock: PMediumFreeBlock;
  LNextMediumBlockSizeAndFlags: Cardinal;
  LBlockSize, LPreviousMediumBlockSize: Cardinal;
  LPSmallBlockPool, LPPreviousPool, LPNextPool,
    LPOldFirstPool: PSmallBlockPoolHeader;
  LPSmallBlockType: PSmallBlockType;
  LOldFirstFreeBlock: Pointer;
  LBlockHeader: Cardinal;
  LPPreviousMediumBlockPoolHeader, LPNextMediumBlockPoolHeader: PMediumBlockPoolHeader;
begin
  {Get the small block header: Is it actually a small block?}
  LBlockHeader := PCardinal(Cardinal(P) - BlockHeaderSize)^;
  {Is it a small block that is in use?}
  if LBlockHeader and (IsFreeBlockFlag or IsMediumBlockFlag or IsLargeBlockFlag) = 0 then
  begin
    {Get a pointer to the block pool}
    LPSmallBlockPool := PSmallBlockPoolHeader(LBlockHeader);
    {Get the block type}
    LPSmallBlockType := LPSmallBlockPool.BlockType;
    {Lock the block type}
    if IsMultiThread then
    begin
      while (LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) <> 0) do
      begin
        if not NeverSleepOnMMThreadContention then
        begin
          Sleep(InitialSleepTime);
          if LockCmpxchg(0, 1, @LPSmallBlockType.BlockTypeLocked) = 0 then
            break;
          Sleep(AdditionalSleepTime);
        end;
      end;
    end;
    {Get the old first free block}
    LOldFirstFreeBlock := LPSmallBlockPool.FirstFreeBlock;
    {Was the pool manager previously full?}
    if LOldFirstFreeBlock = nil then
    begin
      {Insert this as the first partially free pool for the block size}
      LPOldFirstPool := LPSmallBlockType.NextPartiallyFreePool;
      LPSmallBlockPool.NextPartiallyFreePool := LPOldFirstPool;
      LPOldFirstPool.PreviousPartiallyFreePool := LPSmallBlockPool;
      LPSmallBlockPool.PreviousPartiallyFreePool := PSmallBlockPoolHeader(LPSmallBlockType);
      LPSmallBlockType.NextPartiallyFreePool := LPSmallBlockPool;
    end;
    {Store the old first free block}
    PCardinal(Cardinal(P) - BlockHeaderSize)^ := Cardinal(LOldFirstFreeBlock) or IsFreeBlockFlag;
    {Store this as the new first free block}
    LPSmallBlockPool.FirstFreeBlock := P;
    {Decrement the number of allocated blocks}
    Dec(LPSmallBlockPool.BlocksInUse);
    {Small block pools are never freed in full debug mode. This increases the
     likehood of success in catching objects still being used after being
     destroyed.}
    {Is the entire pool now free? -> Free it.}
    if LPSmallBlockPool.BlocksInUse = 0 then
    begin
      {Get the previous and next chunk managers}
      LPPreviousPool := LPSmallBlockPool.PreviousPartiallyFreePool;
      LPNextPool := LPSmallBlockPool.NextPartiallyFreePool;
      {Remove this manager}
      LPPreviousPool.NextPartiallyFreePool := LPNextPool;
      LPNextPool.PreviousPartiallyFreePool := LPPreviousPool;
      {Is this the sequential feed pool? If so, stop sequential feeding}
      if (LPSmallBlockType.CurrentSequentialFeedPool = LPSmallBlockPool) then
        LPSmallBlockType.MaxSequentialFeedBlockAddress := nil;
      {Unlock this block type}
      LPSmallBlockType.BlockTypeLocked := False;
      {No longer a small block pool in use (the flag must be reset in the
       pascal version, since IsSmallBlockPoolInUseFlag = IsLargeBlockFlag)}
      PCardinal(Cardinal(LPSmallBlockPool) - 4)^ :=
        PCardinal(Cardinal(LPSmallBlockPool) - 4)^ and (not IsSmallBlockPoolInUseFlag);
      {Release this pool}
      SysFreeMem(LPSmallBlockPool);
    end
    else
    begin
      {Unlock this block type}
      LPSmallBlockType.BlockTypeLocked := False;
    end;
    {No error}
    Result := 0;
  end
  else
  begin
    {Is this a medium block or a large block?}
    if LBlockHeader and (IsFreeBlockFlag or IsLargeBlockFlag) = 0 then
    begin
      {Get the medium block size}
      LBlockSize := LBlockHeader and DropMediumAndLargeFlagsMask;
      {Lock the medium blocks}
      LockMediumBlocks;
      {Can we combine this block with the next free block?}
      LNextMediumBlock := PMediumFreeBlock(Cardinal(P) + LBlockSize);
      LNextMediumBlockSizeAndFlags := PCardinal(Cardinal(LNextMediumBlock) - BlockHeaderSize)^;
      if (LNextMediumBlockSizeAndFlags and IsFreeBlockFlag) <> 0 then
      begin
        {Increase the size of this block}
        Inc(LBlockSize, LNextMediumBlockSizeAndFlags and DropMediumAndLargeFlagsMask);
        {Remove the next block as well}
        if LNextMediumBlockSizeAndFlags >= MinimumMediumBlockSize then
          RemoveMediumFreeBlock(LNextMediumBlock);
      end
      else
      begin
        {Reset the "previous in use" flag of the next block}
        PCardinal(Cardinal(LNextMediumBlock) - BlockHeaderSize)^ :=
          LNextMediumBlockSizeAndFlags or PreviousMediumBlockIsFreeFlag;
      end;
      {Can we combine this block with the previous free block? We need to
       re-read the flags since it could have changed before we could lock the
       medium blocks.}
      if (PCardinal(Cardinal(P) - BlockHeaderSize)^ and PreviousMediumBlockIsFreeFlag) <> 0 then
      begin
        {Get the size of the free block just before this one}
        LPreviousMediumBlockSize := PCardinal(Cardinal(P) - 8)^;
        {Get the start of the previous block}
        LPreviousMediumBlock := PMediumFreeBlock(Cardinal(P) - LPreviousMediumBlockSize);
        {Set the new block size}
        Inc(LBlockSize, LPreviousMediumBlockSize);
        {This is the new current block}
        P := LPreviousMediumBlock;
        {Remove the previous block from the linked list}
        if LPreviousMediumBlockSize >= MinimumMediumBlockSize then
          RemoveMediumFreeBlock(LPreviousMediumBlock);
      end;
      {Is the entire medium block pool free, and there are other free blocks
       that can fit the largest possible medium block? -> free it. (Except in
       full debug mode where medium pools are never freed.)}
      if (LBlockSize <> (MediumBlockPoolSize - MediumBlockPoolHeaderSize)) then
      begin
        {Store the size of the block as well as the flags}
        PCardinal(Cardinal(P) - BlockHeaderSize)^ := LBlockSize or (IsMediumBlockFlag or IsFreeBlockFlag);
        {Store the trailing size marker}
        PCardinal(Cardinal(P) + LBlockSize - 8)^ := LBlockSize;
        {Insert this block back into the bins: Size check not required here,
         since medium blocks that are in use are not allowed to be
         shrunk smaller than MinimumMediumBlockSize}
        InsertMediumBlockIntoBin(P, LBlockSize);
        {Unlock medium blocks}
        MediumBlocksLocked := False;
        {All OK}
        Result := 0;
      end
      else
      begin
        {Should this become the new sequential feed?}
        if MediumSequentialFeedBytesLeft <> MediumBlockPoolSize - MediumBlockPoolHeaderSize then
        begin
          {Bin the current sequential feed}
          BinMediumSequentialFeedRemainder;
          {Set this medium pool up as the new sequential feed pool:
           Store the sequential feed pool trailer}
          PCardinal(Cardinal(P) + LBlockSize - BlockHeaderSize)^ := IsMediumBlockFlag;
          {Store the number of bytes available in the sequential feed chunk}
          MediumSequentialFeedBytesLeft := MediumBlockPoolSize - MediumBlockPoolHeaderSize;
          {Set the last sequentially fed block}
          LastSequentiallyFedMediumBlock := Pointer(Cardinal(P) + LBlockSize);
          {Unlock medium blocks}
          MediumBlocksLocked := False;
          {Success}
          Result := 0;
        end
        else
        begin
          {Remove this medium block pool from the linked list}
          Dec(Cardinal(P), MediumBlockPoolHeaderSize);
          LPPreviousMediumBlockPoolHeader := PMediumBlockPoolHeader(P).PreviousMediumBlockPoolHeader;
          LPNextMediumBlockPoolHeader := PMediumBlockPoolHeader(P).NextMediumBlockPoolHeader;
          LPPreviousMediumBlockPoolHeader.NextMediumBlockPoolHeader := LPNextMediumBlockPoolHeader;
          LPNextMediumBlockPoolHeader.PreviousMediumBlockPoolHeader := LPPreviousMediumBlockPoolHeader;
          {Unlock medium blocks}
          MediumBlocksLocked := False;
          {Free the medium block pool}
          if VirtualFree(P, 0, MEM_RELEASE) then
            Result := 0
          else
            Result := -1;
        end;
      end;
    end
    else
    begin
      {Validate: Is this actually a Large block, or is it an attempt to free an
       already freed small block?}
      if LBlockHeader and (IsFreeBlockFlag or IsMediumBlockFlag) = 0 then
        Result := FreeLargeBlock(P)
      else
        Result := -1;
    end;
  end;
end;
{$else}
function SysFreeMem(P: Pointer): Integer;
asm
  {On entry:
    eax = P}
  {Get the block header in edx}
  mov edx, [eax - 4]
  {Is it a small block in use?}
  test dl, IsFreeBlockFlag + IsMediumBlockFlag + IsLargeBlockFlag
  {Save the pointer in ecx}
  mov ecx, eax
  {Save ebx}
  push ebx
  {Get the IsMultiThread variable in bl}
  mov bl, IsMultiThread
  {Is it a small block that is in use?}
  jnz @NotSmallBlockInUse
  {Do we need to lock the block type?}
  test bl, bl
  {Get the small block type in ebx}
  mov ebx, TSmallBlockPoolHeader[edx].BlockType
  {Do we need to lock the block type?}
  jnz @LockBlockTypeLoop
@GotLockOnSmallBlockType:
  {Current state: edx = @SmallBlockPoolHeader, ecx = P, ebx = @SmallBlockType}
  {Decrement the number of blocks in use}
  sub TSmallBlockPoolHeader[edx].BlocksInUse, 1
  {Get the old first free block}
  mov eax, TSmallBlockPoolHeader[edx].FirstFreeBlock
  {Is the pool now empty?}
  jz @PoolIsNowEmpty
  {Was the pool full?}
  test eax, eax
  {Store this as the new first free block}
  mov TSmallBlockPoolHeader[edx].FirstFreeBlock, ecx
  {Store the previous first free block as the block header}
  lea eax, [eax + IsFreeBlockFlag]
  mov [ecx - 4], eax
  {Insert the pool back into the linked list if it was full}
  jz @SmallPoolWasFull
  {All ok}
  xor eax, eax
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, al
  {Restore registers}
  pop ebx
  {Done}
  ret
  {Align branch target}
  nop
@SmallPoolWasFull:
  {Insert this as the first partially free pool for the block size}
  mov ecx, TSmallBlockType[ebx].NextPartiallyFreePool
  mov TSmallBlockPoolHeader[edx].PreviousPartiallyFreePool, ebx
  mov TSmallBlockPoolHeader[edx].NextPartiallyFreePool, ecx
  mov TSmallBlockPoolHeader[ecx].PreviousPartiallyFreePool, edx
  mov TSmallBlockType[ebx].NextPartiallyFreePool, edx
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, False
  {All ok}
  xor eax, eax
  {Restore registers}
  pop ebx
  {Done}
  ret
  {Align branch target}
  nop
  nop
@PoolIsNowEmpty:
  {Was this pool actually in the linked list of pools with space? If not, it
   can only be the sequential feed pool (it is the only pool that may contain
   only one block, i.e. other blocks have not been split off yet)}
  test eax, eax
  jz @IsSequentialFeedPool
  {Pool is now empty: Remove it from the linked list and free it}
  mov eax, TSmallBlockPoolHeader[edx].PreviousPartiallyFreePool
  mov ecx, TSmallBlockPoolHeader[edx].NextPartiallyFreePool
  {Remove this manager}
  mov TSmallBlockPoolHeader[eax].NextPartiallyFreePool, ecx
  mov TSmallBlockPoolHeader[ecx].PreviousPartiallyFreePool, eax
  {Zero out eax}
  xor eax, eax
  {Is this the sequential feed pool? If so, stop sequential feeding}
  cmp TSmallBlockType[ebx].CurrentSequentialFeedPool, edx
  jne @NotSequentialFeedPool
@IsSequentialFeedPool:
  mov TSmallBlockType[ebx].MaxSequentialFeedBlockAddress, eax
@NotSequentialFeedPool:
  {Unlock the block type}
  mov TSmallBlockType[ebx].BlockTypeLocked, al
  {Release this pool}
  mov eax, edx
  mov edx, [edx - 4]
  mov bl, IsMultiThread
  jmp @FreeMediumBlock
  {Align branch target}
@LockBlockTypeLoop:
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @LockBlockTypeLoop
  {Couldn't grab the block type - sleep and try again}
  push ecx
  push edx
  push InitialSleepTime
  call Sleep
  pop edx
  pop ecx
  {Try again}
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg TSmallBlockType([ebx]).BlockTypeLocked, ah
  je @GotLockOnSmallBlockType
  {Couldn't grab the block type - sleep and try again}
  push ecx
  push edx
  push AdditionalSleepTime
  call Sleep
  pop edx
  pop ecx
  {Try again}
  jmp @LockBlockTypeLoop
  {Align branch target}
  nop
  nop
  nop
  {-----------------------------Medium blocks-----------------------------}
@LockMediumBlocks:
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLocked
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @LockMediumBlocks
  {Couldn't lock the medium blocks - sleep and try again}
  push InitialSleepTime
  call Sleep
  {Try again}
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumBlocksLocked
  {Couldn't lock the medium blocks - sleep and try again}
  push AdditionalSleepTime
  call Sleep
  {Try again}
  jmp @LockMediumBlocks
  {Align branch target}
  nop
  nop
  nop
@NotSmallBlockInUse:
  {Not a small block in use: is it a medium or large block?}
  test dl, IsFreeBlockFlag + IsLargeBlockFlag
  jnz @NotASmallOrMediumBlock
@FreeMediumBlock:
  {Drop the flags}
  and edx, DropMediumAndLargeFlagsMask
  {Free the large block pointed to by eax, header in edx, bl = IsMultiThread}
  {Do we need to lock the medium blocks?}
  test bl, bl
  {Block size in ebx}
  mov ebx, edx
  {Save registers}
  push esi
  {Pointer in esi}
  mov esi, eax
  {Do we need to lock the medium blocks?}
  jnz @LockMediumBlocks
@MediumBlocksLocked:
  {Can we combine this block with the next free block?}
  test dword ptr [esi + ebx - 4], IsFreeBlockFlag
  {Get the next block size and flags in ecx}
  mov ecx, [esi + ebx - 4]
  jnz @NextBlockIsFree
  {Set the "PreviousIsFree" flag in the next block}
  or ecx, PreviousMediumBlockIsFreeFlag
  mov [esi + ebx - 4], ecx
@NextBlockChecked:
  {Can we combine this block with the previous free block? We need to
   re-read the flags since it could have changed before we could lock the
   medium blocks.}
  test byte ptr [esi - 4], PreviousMediumBlockIsFreeFlag
  jnz @PreviousBlockIsFree
@PreviousBlockChecked:
  {Is the entire medium block pool free, and there are other free blocks
   that can fit the largest possible medium block -> free it.}
  cmp ebx, (MediumBlockPoolSize - MediumBlockPoolHeaderSize)
  je @EntireMediumPoolFree
@BinFreeMediumBlock:
  {Store the size of the block as well as the flags}
  lea eax, [ebx + IsMediumBlockFlag + IsFreeBlockFlag]
  mov [esi - 4], eax
  {Store the trailing size marker}
  mov [esi + ebx - 8], ebx
  {Insert this block back into the bins: Size check not required here,
   since medium blocks that are in use are not allowed to be
   shrunk smaller than MinimumMediumBlockSize}
  mov eax, esi
  mov edx, ebx
  {Insert into bin}
  call InsertMediumBlockIntoBin
  {Unlock medium blocks}
  mov MediumBlocksLocked, False;
  {All OK}
  xor eax, eax
  {Restore registers}
  pop esi
  pop ebx
  {Return}
  ret
  {Align branch target}
  nop
@NextBlockIsFree:
  {Get the next block address in eax}
  lea eax, [esi + ebx]
  {Increase the size of this block}
  and ecx, DropMediumAndLargeFlagsMask
  add ebx, ecx
  {Was the block binned?}
  cmp ecx, MinimumMediumBlockSize
  jb @NextBlockChecked
  call RemoveMediumFreeBlock
  jmp @NextBlockChecked
  {Align branch target}
  nop
@PreviousBlockIsFree:
  {Get the size of the free block just before this one}
  mov ecx, [esi - 8]
  {Include the previous block}
  sub esi, ecx
  {Set the new block size}
  add ebx, ecx
  {Remove the previous block from the linked list}
  cmp ecx, MinimumMediumBlockSize
  jb @PreviousBlockChecked
  mov eax, esi
  call RemoveMediumFreeBlock
  jmp @PreviousBlockChecked
  {Align branch target}
@EntireMediumPoolFree:
  {Should we make this the new sequential feed medium block pool? If the
   current sequential feed pool is not entirely free, we make this the new
   sequential feed pool.}
  cmp MediumSequentialFeedBytesLeft, MediumBlockPoolSize - MediumBlockPoolHeaderSize
  jne @MakeEmptyMediumPoolSequentialFeed
  {Point esi to the medium block pool header}
  sub esi, MediumBlockPoolHeaderSize
  {Remove this medium block pool from the linked list}
  mov eax, TMediumBlockPoolHeader[esi].PreviousMediumBlockPoolHeader
  mov edx, TMediumBlockPoolHeader[esi].NextMediumBlockPoolHeader
  mov TMediumBlockPoolHeader[eax].NextMediumBlockPoolHeader, edx
  mov TMediumBlockPoolHeader[edx].PreviousMediumBlockPoolHeader, eax
  {Unlock medium blocks}
  mov MediumBlocksLocked, False;
  {Free the medium block pool}
  push MEM_RELEASE
  push 0
  push esi
  call VirtualFree
  {VirtualFree returns >0 if all is ok}
  cmp eax, 1
  {Return 0 on all ok}
  sbb eax, eax
  {Restore registers}
  pop esi
  pop ebx
  ret
  {Align branch target}
  nop
  nop
  nop
@MakeEmptyMediumPoolSequentialFeed:
  {Get a pointer to the end-marker block}
  lea ebx, [esi + MediumBlockPoolSize - MediumBlockPoolHeaderSize]
  {Bin the current sequential feed pool}
  call BinMediumSequentialFeedRemainder
  {Set this medium pool up as the new sequential feed pool:
   Store the sequential feed pool trailer}
  mov dword ptr [ebx - BlockHeaderSize], IsMediumBlockFlag
  {Store the number of bytes available in the sequential feed chunk}
  mov MediumSequentialFeedBytesLeft, MediumBlockPoolSize - MediumBlockPoolHeaderSize
  {Set the last sequentially fed block}
  mov LastSequentiallyFedMediumBlock, ebx
  {Unlock medium blocks}
  mov MediumBlocksLocked, False;
  {Success}
  xor eax, eax
  {Restore registers}
  pop esi
  pop ebx
  ret
  {Align branch target}
  nop
  nop
@NotASmallOrMediumBlock:
  {Restore ebx}
  pop ebx
  {Is it in fact a large block?}
  test dl, IsFreeBlockFlag + IsMediumBlockFlag
  jz FreeLargeBlock
  {Attempt to free an already free block}
  mov eax, -1
end;
{$endif}

{$ifdef UsePascalCode}
function SysReallocMem(P: Pointer; Size: Integer): Pointer;
var
  LBlockHeader, LBlockFlags, LOldAvailableSize, LNewAllocSize,
    LNextBlockSizeAndFlags, LNextBlockSize, LNewAvailableSize, LMinimumUpsize,
    LSecondSPlitSize, LNewBlockSize: Cardinal;
  LPSmallBlockType: PSmallBlockType;
  LPNextBlock, LPNextBlockHeader: Pointer;

  {Upsizes a large block in-place. The following variables are assumed correct:
    LBlockFlags, LOldAvailableSize, LPNextBlock, LNextBlockSizeAndFlags,
    LNextBlockSize, LNewAvailableSize. Medium blocks must be locked on entry if
    required.}
  procedure MediumBlockInPlaceUpsize;
  begin
    {Remove the next block}
    if LNextBlockSizeAndFlags >= MinimumMediumBlockSize then
      RemoveMediumFreeBlock(LPNextBlock);
    {Add 25% for medium block in-place upsizes}
    LMinimumUpsize := LOldAvailableSize + (LOldAvailableSize shr 2);
    if Cardinal(Size) < LMinimumUpsize then
      LNewAllocSize := LMinimumUpsize
    else
      LNewAllocSize := Size;
    {Round up to the nearest block size granularity}
    LNewBlockSize := ((LNewAllocSize + (BlockHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset))
      and -MediumBlockGranularity) + MediumBlockSizeOffset;
    {Calculate the size of the second split}
    LSecondSplitSize := LNewAvailableSize + BlockHeaderSize - LNewBlockSize;
    {Does it fit?}
    if Integer(LSecondSplitSize) <= 0 then
    begin
      {The block size is the full available size plus header}
      LNewBlockSize := LNewAvailableSize + BlockHeaderSize;
      {Grab the whole block: Mark it as used in the block following it}
      LPNextBlockHeader := Pointer(Cardinal(P) + LNewAvailableSize);
      PCardinal(LPNextBlockHeader)^ :=
        PCardinal(LPNextBlockHeader)^ and (not PreviousMediumBlockIsFreeFlag);
    end
    else
    begin
      {Split the block in two}
      LPNextBlock := PMediumFreeBlock(Cardinal(P) + LNewBlockSize);
      {Set the size of the second split}
      PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^ := LSecondSplitSize or (IsMediumBlockFlag or IsFreeBlockFlag);
      {Store the size of the second split as the second last dword}
      PCardinal(Cardinal(LPNextBlock) + LSecondSplitSize - 8)^ := LSecondSplitSize;
      {Put the remainder in a bin if it is big enough}
      if LSecondSplitSize >= MinimumMediumBlockSize then
        InsertMediumBlockIntoBin(LPNextBlock, LSecondSplitSize);
    end;
    {Set the size and flags for this block}
    PCardinal(Cardinal(P) - BlockHeaderSize)^ := LNewBlockSize or LBlockFlags;
  end;

  {In-place downsize of a medium block. On entry ANewSize must be less than half
   of LOldAvailableSize.}
  procedure MediumBlockInPlaceDownsize;
  begin
    {Round up to the next medium block size}
    LNewBlockSize := ((Size + (BlockHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset))
      and -MediumBlockGranularity) + MediumBlockSizeOffset;
    {Get the size of the second split}
    LSecondSplitSize := (LOldAvailableSize + BlockHeaderSize) - LNewBlockSize;
    {Lock the medium blocks}
    LockMediumBlocks;
    {Set the new size}
    PCardinal(Cardinal(P) - BlockHeaderSize)^ :=
      (PCardinal(Cardinal(P) - BlockHeaderSize)^ and ExtractMediumAndLargeFlagsMask)
      or LNewBlockSize;
    {Is the next block in use?}
    LPNextBlock := PCardinal(Cardinal(P) + LOldAvailableSize + BlockHeaderSize);
    LNextBlockSizeAndFlags := PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^;
    if LNextBlockSizeAndFlags and IsFreeBlockFlag = 0 then
    begin
      {The next block is in use: flag its previous block as free}
      PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^ :=
        LNextBlockSizeAndFlags or PreviousMediumBlockIsFreeFlag;
    end
    else
    begin
      {The next block is free: combine it}
      LNextBlockSizeAndFlags := LNextBlockSizeAndFlags and DropMediumAndLargeFlagsMask;
      Inc(LSecondSplitSize, LNextBlockSizeAndFlags);
      if LNextBlockSizeAndFlags >= MinimumMediumBlockSize then
        RemoveMediumFreeBlock(LPNextBlock);
    end;
    {Set the split}
    LPNextBlock := PCardinal(Cardinal(P) + LNewBlockSize);
    {Store the free part's header}
    PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^ := LSecondSplitSize or (IsMediumBlockFlag or IsFreeBlockFlag);
    {Store the trailing size field}
    PCardinal(Cardinal(LPNextBlock) + LSecondSplitSize - 8)^ := LSecondSplitSize;
    {Bin this free block}
    if LSecondSplitSize >= MinimumMediumBlockSize then
      InsertMediumBlockIntoBin(LPNextBlock, LSecondSplitSize);
    {Unlock the medium blocks}
    MediumBlocksLocked := False;
  end;

begin
  {Get the block header: Is it actually a small block?}
  LBlockHeader := PCardinal(Cardinal(P) - BlockHeaderSize)^;
  {Is it a small block that is in use?}
  if LBlockHeader and (IsFreeBlockFlag or IsMediumBlockFlag or IsLargeBlockFlag) = 0 then
  begin
    {----------------------------Small block------------------------------}
    {The block header is a pointer to the block pool: Get the block type}
    LPSmallBlockType := PSmallBlockPoolHeader(LBlockHeader).BlockType;
    {Get the available size inside blocks of this type.}
    LOldAvailableSize := LPSmallBlockType.BlockSize - BlockHeaderSize;
    {Is it an upsize or a downsize?}
    if LOldAvailableSize >= Cardinal(Size) then
    begin
      {It's a downsize. Do we need to allocate a smaller block? Only if the new
       block size is less than a quarter of the available size less
       SmallBlockDownsizeCheckAdder bytes}
      if (Cardinal(Size) * 4 + SmallBlockDownsizeCheckAdder) >= LOldAvailableSize then
      begin
        {In-place downsize - return the pointer}
        Result := P;
        exit;
      end
      else
      begin
        {Allocate a smaller block}
        Result := SysGetMem(Size);
        {Allocated OK?}
        if Result <> nil then
        begin
          {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
          MoveX8L4(P^, Result^, Size);
{$else}
          Move(P^, Result^, Size);
{$endif}
          {Free the old pointer}
          SysFreeMem(P);
        end;
      end;
    end
    else
    begin
      {This pointer is being reallocated to a larger block and therefore it is
       logical to assume that it may be enlarged again. Since reallocations are
       expensive, there is a minimum upsize percentage to avoid unnecessary
       future move operations.}
      {Must grow with at least 100% + x bytes}
      LNewAllocSize := LOldAvailableSize * 2 + SmallBlockUpsizeAdder;
      {Still not large enough?}
      if LNewAllocSize < Cardinal(Size) then
        LNewAllocSize := Size;
      {Allocate the new block}
      Result := SysGetMem(LNewAllocSize);
      {Allocated OK?}
      if Result <> nil then
      begin
        {Do we need to store the requested size? Only large blocks store the
         requested size.}
        if LNewAllocSize > (MaximumMediumBlockSize - BlockHeaderSize) then
          PLargeBlockHeader(Cardinal(Result) - LargeBlockHeaderSize).UserAllocatedSize := Size;
        {Move the data across}
{$ifdef UseCustomFixedSizeMoveRoutines}
        LPSmallBlockType.UpsizeMoveProcedure(P^, Result^, LOldAvailableSize);
{$else}
        Move(P^, Result^, LOldAvailableSize);
{$endif}
        {Free the old pointer}
        SysFreeMem(P);
      end;
    end;
  end
  else
  begin
    {Is this a medium block or a large block?}
    if LBlockHeader and (IsFreeBlockFlag or IsLargeBlockFlag) = 0 then
    begin
      {-------------------------Medium block------------------------------}
      {What is the available size in the block being reallocated?}
      LOldAvailableSize := (LBlockHeader and DropMediumAndLargeFlagsMask);
      {Get a pointer to the next block}
      LPNextBlock := PCardinal(Cardinal(P) + LOldAvailableSize);
      {Subtract the block header size from the old available size}
      Dec(LOldAvailableSize, BlockHeaderSize);
      {Is it an upsize or a downsize?}
      if Cardinal(Size) > LOldAvailableSize then
      begin
        {Can we do an in-place upsize?}
        LNextBlockSizeAndFlags := PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^;
        {Is the next block free?}
        if LNextBlockSizeAndFlags and IsFreeBlockFlag <> 0 then
        begin
          LNextBlockSize := LNextBlockSizeAndFlags and DropMediumAndLargeFlagsMask;
          {The available size including the next block}
          LNewAvailableSize := LOldAvailableSize + LNextBlockSize;
          {Can the block fit?}
          if Cardinal(Size) <= LNewAvailableSize then
          begin
            {The next block is free and there is enough space to grow this
             block in place.}
            if IsMultiThread then
            begin
              {Multi-threaded application - lock medium blocks and re-read the
               information on the blocks.}
              LockMediumBlocks;
              {Re-read the info for this block}
              LBlockFlags := PCardinal(Cardinal(P) - BlockHeaderSize)^ and ExtractMediumAndLargeFlagsMask;
              {Re-read the info for the next block}
              LNextBlockSizeAndFlags := PCardinal(Cardinal(LPNextBlock) - BlockHeaderSize)^;
              {Recalculate the next block size}
              LNextBlockSize := LNextBlockSizeAndFlags and DropMediumAndLargeFlagsMask;
              {The available size including the next block}
              LNewAvailableSize := LOldAvailableSize + LNextBlockSize;
              {Is the next block still free and the size still sufficient?}
              if (LNextBlockSizeAndFlags and IsFreeBlockFlag <> 0)
                and (Cardinal(Size) <= LNewAvailableSize) then
              begin
                {Upsize the block in-place}
                MediumBlockInPlaceUpsize;
                {Unlock the medium blocks}
                MediumBlocksLocked := False;
                {Return the result}
                Result := P;
                {Done}
                exit;
              end;
              {Couldn't use the block: Unlock the medium blocks}
              MediumBlocksLocked := False;
            end
            else
            begin
              {Extract the block flags}
              LBlockFlags := ExtractMediumAndLargeFlagsMask and LBlockHeader;
              {Upsize the block in-place}
              MediumBlockInPlaceUpsize;
              {Return the result}
              Result := P;
              {Done}
              exit;
            end;
          end;
        end;
        {Couldn't upsize in place. Grab a new block and move the data across:
         If we have to reallocate and move medium blocks, we grow by at
         least 25%}
        LMinimumUpsize := LOldAvailableSize + (LOldAvailableSize shr 2);
        if Cardinal(Size) < LMinimumUpsize then
          LNewAllocSize := LMinimumUpsize
        else
          LNewAllocSize := Size;
        {Allocate the new block}
        Result := SysGetMem(LNewAllocSize);
        if Result <> nil then
        begin
          {If its a Large block - store the actual user requested size}
          if LNewAllocSize > (MaximumMediumBlockSize - BlockHeaderSize) then
            PLargeBlockHeader(Cardinal(Result) - LargeBlockHeaderSize).UserAllocatedSize := Size;
          {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
          MoveX16L4(P^, Result^, LOldAvailableSize);
{$else}
          Move(P^, Result^, LOldAvailableSize);
{$endif}
          {Free the old block}
          SysFreeMem(P);
        end;
      end
      else
      begin
        {Must be less than half the current size or we don't bother resizing.}
        if Cardinal(Size * 2) >= LOldAvailableSize then
        begin
          Result := P;
        end
        else
        begin
          {In-place downsize? Balance the cost of moving the data vs. the cost of
           fragmenting the memory pool. Medium blocks in use may never be smaller
           than MinimumMediumBlockSize.}
          if Size >= (MinimumMediumBlockSize - BlockHeaderSize) then
          begin
            MediumBlockInPlaceDownsize;
            Result := P;
          end
          else
          begin
            {The requested size is less than the minimum medium block size. If
             the requested size is less than the threshold value (currently a
             quarter of the minimum medium block size), move the data to a small
             block, otherwise shrink the medium block to the minimum allowable
             medium block size.}
            if Cardinal(Size) >= MediumInPlaceDownsizeLimit then
            begin
              {The request is for a size smaller than the minimum medium block
               size, but not small enough to justify moving data: Reduce the
               block size to the minimum medium block size}
              Size := MinimumMediumBlockSize - BlockHeaderSize;
              {Is it already at the minimum medium block size?}
              if LOldAvailableSize > Cardinal(Size) then
                MediumBlockInPlaceDownsize;
              Result := P;
            end
            else
            begin
              {Allocate the new block}
              Result := SysGetMem(Size);
              if Result <> nil then
              begin
                {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
                MoveX8L4(P^, Result^, Size);
{$else}
                Move(P^, Result^, Size);
{$endif}
                {Free the old block}
                SysFreeMem(P);
              end;
            end;
          end;
        end;

      end;
    end
    else
    begin
      {Is this a valid large block?}
      if LBlockHeader and (IsFreeBlockFlag or IsMediumBlockFlag) = 0 then
      begin
        {-----------------------Large block------------------------------}
        Result := ReallocateLargeBlock(P, Size);
      end
      else
      begin
        {-----------------------Invalid block------------------------------}
        {Bad pointer: probably an attempt to reallocate a free memory block.}
        Result := nil;
      end;
    end;
  end;
end;
{$else}
function SysReallocMem(P: Pointer; Size: Integer): Pointer;
asm
  {On entry: eax = P; edx = Size}
  {Get the block header: Is it actually a small block?}
  mov ecx, [eax - 4]
  {Is it a small block?}
  test cl, IsFreeBlockFlag + IsMediumBlockFlag + IsLargeBlockFlag
  {Save ebx}
  push ebx
  {Save esi}
  push esi
  {Save the original pointer in esi}
  mov esi, eax
  {Is it a small block?}
  jnz @NotASmallBlock
  {----------------------------Small block--------------------------------}
  {Get the block type in ebx}
  mov ebx, TSmallBlockPoolHeader[ecx].BlockType
  {Get the available size inside blocks of this type.}
  movzx ecx, TSmallBlockType[ebx].BlockSize
  sub ecx, 4
  {Is it an upsize or a downsize?}
  cmp ecx, edx
  jb @SmallUpsize
  {It's a downsize. Do we need to allocate a smaller block? Only if the new
   size is less than a quarter of the available size less
   SmallBlockDownsizeCheckAdder bytes}
  lea ebx, [edx * 4 + SmallBlockDownsizeCheckAdder]
  cmp ebx, ecx
  jb @NotSmallInPlaceDownsize
  {In-place downsize - return the original pointer}
  pop esi
  pop ebx
  ret
  {Align branch target}
  nop
@NotSmallInPlaceDownsize:
  {Save the requested size}
  mov ebx, edx
  {Allocate a smaller block}
  mov eax, edx
  call SysGetMem
  {Allocated OK?}
  test eax, eax
  jz @SmallDownsizeDone
  {Move data across: count in ecx}
  mov ecx, ebx
  {Destination in edx}
  mov edx, eax
  {Save the result in ebx}
  mov ebx, eax
  {Original pointer in eax}
  mov eax, esi
  {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
  call MoveX8L4
{$else}
  call Move
{$endif}
  {Free the original pointer}
  mov eax, esi
  call SysFreeMem
  {Return the pointer}
  mov eax, ebx
@SmallDownsizeDone:
  pop esi
  pop ebx
  ret
  {Align branch target}
  nop
  nop
@SmallUpsize:
  {State: esi = P, edx = Size, ecx = Current Block Size, ebx = Current Block Type}
  {This pointer is being reallocated to a larger block and therefore it is
   logical to assume that it may be enlarged again. Since reallocations are
   expensive, there is a minimum upsize percentage to avoid unnecessary
   future move operations.}
  {Small blocks always grow with at least 100% + SmallBlockUpsizeAdder bytes}
  lea ecx, [ecx + ecx + SmallBlockUpsizeAdder]
  {save edi}
  push edi
  {Save the requested size in edi}
  mov edi, edx
  {New allocated size is the maximum of the requested size and the minimum
   upsize}
  xor eax, eax
  sub ecx, edx
  adc eax, -1
  and eax, ecx
  add eax, edx
  {Allocate the new block}
  call SysGetMem
  {Allocated OK?}
  test eax, eax
  jz @SmallUpsizeDone
  {Do we need to store the requested size? Only large blocks store the
   requested size.}
  cmp edi, MaximumMediumBlockSize - BlockHeaderSize
  jbe @NotSmallUpsizeToLargeBlock
  {Store the user requested size}
  mov [eax - 8], edi
@NotSmallUpsizeToLargeBlock:
  {Get the size to move across}
  movzx ecx, TSmallBlockType[ebx].BlockSize
  sub ecx, BlockHeaderSize
  {Move to the new block}
  mov edx, eax
  {Save the result in edi}
  mov edi, eax
  {Move from the old block}
  mov eax, esi
  {Move the data across}
{$ifdef UseCustomFixedSizeMoveRoutines}
  call TSmallBlockType[ebx].UpsizeMoveProcedure
{$else}
  call Move
{$endif}
  {Free the old pointer}
  mov eax, esi
  call SysFreeMem
  {Done}
  mov eax, edi
@SmallUpsizeDone:
  pop edi
  pop esi
  pop ebx
  ret
  {Align branch target}
{$ifndef UseCustomFixedSizeMoveRoutines}
  nop
  nop
{$endif}
  nop
@NotASmallBlock:
  {Is this a medium block or a large block?}
  test cl, IsFreeBlockFlag + IsLargeBlockFlag
  jnz @PossibleLargeBlock
  {----------------------------Medium block-------------------------------}
  {Status: ecx = Current Block Size + Flags, eax/esi = P,
   edx = Requested Size}
  mov ebx, ecx
  {Drop the flags from the header}
  and ecx, DropMediumAndLargeFlagsMask
  {Save edi}
  push edi
  {Get a pointer to the next block in edi}
  lea edi, [eax + ecx]
  {Subtract the block header size from the old available size}
  sub ecx, BlockHeaderSize
  {Get the complete flags in ebx}
  and ebx, ExtractMediumAndLargeFlagsMask
  {Is it an upsize or a downsize?}
  cmp edx, ecx
  {Save ebp}
  push ebp
  {Is it an upsize or a downsize?}
  ja @MediumBlockUpsize
  {Status: ecx = Current Block Size - 4, bl = Current Block Flags,
   edi = @Next Block, eax/esi = P, edx = Requested Size}
  {Must be less than half the current size or we don't bother resizing.}
  lea ebp, [edx + edx]
  cmp ebp, ecx
  jb @MediumMustDownsize
@MediumNoResize:
  {Restore registers}
  pop ebp
  pop edi
  pop esi
  pop ebx
  {Return}
  ret
  {Align branch target}
  nop
  nop
  nop
@MediumMustDownsize:
  {In-place downsize? Balance the cost of moving the data vs. the cost of
   fragmenting the memory pool. Medium blocks in use may never be smaller
   than MinimumMediumBlockSize.}
  cmp edx, MinimumMediumBlockSize - BlockHeaderSize
  jae @MediumBlockInPlaceDownsize
  {The requested size is less than the minimum medium block size. If the
  requested size is less than the threshold value (currently a quarter of the
  minimum medium block size), move the data to a small block, otherwise shrink
  the medium block to the minimum allowable medium block size.}
  cmp edx, MediumInPlaceDownsizeLimit
  jb @MediumDownsizeRealloc
  {The request is for a size smaller than the minimum medium block size, but
   not small enough to justify moving data: Reduce the block size to the
   minimum medium block size}
  mov edx, MinimumMediumBlockSize - BlockHeaderSize
  {Is it already at the minimum medium block size?}
  cmp ecx, edx
  jna @MediumNoResize
@MediumBlockInPlaceDownsize:
  {Round up to the next medium block size}
  lea ebp, [edx + BlockHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset]
  and ebp, -MediumBlockGranularity;
  add ebp, MediumBlockSizeOffset
  {Get the size of the second split}
  add ecx, BlockHeaderSize
  sub ecx, ebp
  {Lock the medium blocks}
  cmp IsMultiThread, False
  je @DoMediumInPlaceDownsize
  {We have to re-read the flags}
@DoMediumLockForDownsize:
  {Lock the medium blocks}
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumDownsizeRereadFlags
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @DoMediumLockForDownsize
  {Couldn't lock the medium blocks - sleep and try again}
  push ecx
  push InitialSleepTime
  call Sleep
  pop ecx
  {Try again}
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg MediumBlocksLocked, ah
  je @MediumDownsizeRereadFlags
  {Couldn't lock the medium blocks - sleep and try again}
  push ecx
  push AdditionalSleepTime
  call Sleep
  pop ecx
  {Try again}
  jmp @DoMediumLockForDownsize
  {Align branch target}
  nop
@MediumDownsizeRereadFlags:
  mov ebx, ExtractMediumAndLargeFlagsMask
  and ebx, [esi - 4]
@DoMediumInPlaceDownsize:
  {Set the new size}
  or ebx, ebp
  mov [esi - 4], ebx
  {Get the second split size in ebx}
  mov ebx, ecx
  {Is the next block in use?}
  mov edx, [edi - 4]
  test dl, IsFreeBlockFlag
  jnz @MediumDownsizeNextBlockFree
  {The next block is in use: flag its previous block as free}
  or edx, PreviousMediumBlockIsFreeFlag
  mov [edi - 4], edx
  jmp @MediumDownsizeDoSplit
  {Align branch target}
  nop
@MediumDownsizeNextBlockFree:
  {The next block is free: combine it}
  mov eax, edi
  and edx, DropMediumAndLargeFlagsMask
  add ebx, edx
  add edi, edx
  cmp edx, MinimumMediumBlockSize
  jb @MediumDownsizeDoSplit
  call RemoveMediumFreeBlock
@MediumDownsizeDoSplit:
  {Store the trailing size field}
  mov [edi - 8], ebx
  {Store the free part's header}
  lea eax, [ebx + IsMediumBlockFlag + IsFreeBlockFlag];
  mov [esi + ebp - 4], eax
  {Bin this free block}
  cmp ebx, MinimumMediumBlockSize
  jb @MediumBlockDownsizeDone
  lea eax, [esi + ebp]
  mov edx, ebx
  call InsertMediumBlockIntoBin
@MediumBlockDownsizeDone:
  {Unlock the medium blocks}
  mov MediumBlocksLocked, False
  {Result = old pointer}
  mov eax, esi
  {Restore registers}
  pop ebp
  pop edi
  pop esi
  pop ebx
  {Return}
  ret
  {Align branch target}
@MediumDownsizeRealloc:
  {Save the requested size}
  mov edi, edx
  mov eax, edx
  {Allocate the new block}
  call SysGetMem
  test eax, eax
  jz @MediumBlockDownsizeExit
  {Save the result}
  mov ebp, eax
  mov edx, eax
  mov eax, esi
  mov ecx, edi
  {Move the data across}
{$ifdef UseCustomVariableSizeMoveRoutines}
  call MoveX8L4
{$else}
  call Move
{$endif}
  mov eax, esi
  call SysFreeMem
  {Return the result}
  mov eax, ebp
@MediumBlockDownsizeExit:
  pop ebp
  pop edi
  pop esi
  pop ebx
  ret
  {Align branch target}
@MediumBlockUpsize:
  {Status: ecx = Current Block Size - 4, bl = Current Block Flags,
   edi = @Next Block, eax/esi = P, edx = Requested Size}
  {Can we do an in-place upsize?}
  mov eax, [edi - 4]
  test al, IsFreeBlockFlag
  jz @CannotUpsizeMediumBlockInPlace
  {Get the total available size including the next block}
  and eax, DropMediumAndLargeFlagsMask
  {ebp = total available size including the next block (excluding the header)}
  lea ebp, [eax + ecx]
  {Can the block fit?}
  cmp edx, ebp
  ja @CannotUpsizeMediumBlockInPlace
  {The next block is free and there is enough space to grow this
   block in place.}
  cmp IsMultiThread, False
  je @DoMediumInPlaceUpsize
@DoMediumLockForUpsize:
  {Lock the medium blocks}
  mov eax, $100
  {Attempt to lock the medium blocks}
  lock cmpxchg MediumBlocksLocked, ah
  je @RecheckMediumInPlaceUpsize
  {The pause instruction improves spinlock performance}
  pause
  {"Busy waiting" or "sleep and retry" strategy?}
  cmp NeverSleepOnMMThreadContention, 0
  jne @DoMediumLockForUpsize
  {Couldn't lock the medium blocks - sleep and try again}
  push ecx
  push edx
  push InitialSleepTime
  call Sleep
  pop edx
  pop ecx
  {Try again}
  mov eax, $100
  {Attempt to grab the block type}
  lock cmpxchg MediumBlocksLocked, ah
  je @RecheckMediumInPlaceUpsize
  {Couldn't lock the medium blocks - sleep and try again}
  push ecx
  push edx
  push AdditionalSleepTime
  call Sleep
  pop edx
  pop ecx
  {Try again}
  jmp @DoMediumLockForUpsize
  {Align branch target}
  nop
@RecheckMediumInPlaceUpsize:
  {Re-read the info for this block}
  mov ebx, ExtractMediumAndLargeFlagsMask
  and ebx, [esi - 4]
  {Re-read the info for the next block}
  mov eax, [edi - 4]
  {Next block still free?}
  test al, IsFreeBlockFlag
  jz @NextMediumBlockChanged
  {Recalculate the next block size}
  and eax, DropMediumAndLargeFlagsMask
  {The available size including the next block}
  lea ebp, [eax + ecx]
  {Can the block still fit?}
  cmp edx, ebp
  ja @NextMediumBlockChanged
@DoMediumInPlaceUpsize:
  {Is the next block binnable?}
  cmp eax, MinimumMediumBlockSize
  {Remove the next block}
  jb @MediumInPlaceNoNextRemove
  mov eax, edi
  push ecx
  push edx
  call RemoveMediumFreeBlock
  pop edx
  pop ecx
@MediumInPlaceNoNextRemove:
  {Medium blocks grow a minimum of 25% in in-place upsizes}
  mov eax, ecx
  shr eax, 2
  add eax, ecx
  {Get the maximum of the requested size and the minimum growth size}
  xor edi, edi
  sub eax, edx
  adc edi, -1
  and eax, edi
  {Round up to the nearest block size granularity}
  lea eax, [eax + edx + BlockHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset]
  and eax, -MediumBlockGranularity
  add eax, MediumBlockSizeOffset
  {Calculate the size of the second split}
  lea edx, [ebp + BlockHeaderSize]
  sub edx, eax
  {Does it fit?}
  ja @MediumInPlaceUpsizeSplit
  {Grab the whole block: Mark it as used in the block following it}
  and dword ptr [esi + ebp], not PreviousMediumBlockIsFreeFlag
  {The block size is the full available size plus header}
  add ebp, 4
  {Upsize done}
  jmp @MediumUpsizeInPlaceDone
  {Align branch target}
  nop
  nop
@MediumInPlaceUpsizeSplit:
  {Store the size of the second split as the second last dword}
  mov [esi + ebp - 4], edx
  {Set the second split header}
  lea edi, [edx + IsMediumBlockFlag + IsFreeBlockFlag]
  mov [esi + eax - 4], edi
  mov ebp, eax
  cmp edx, MinimumMediumBlockSize
  jb @MediumUpsizeInPlaceDone
  add eax, esi
  call InsertMediumBlockIntoBin
@MediumUpsizeInPlaceDone:
  {Set the size and flags for this block}
  or ebp, ebx
  mov [esi - 4], ebp
  {Unlock the medium blocks}
  mov MediumBlocksLocked, False
  {Result = old pointer}
  mov eax, esi
@MediumBlockResizeDone2:
  {Restore registers}
  pop ebp
  pop edi
  pop esi
  pop ebx
  {Return}
  ret
  {Align branch target for @CannotUpsizeMediumBlockInPlace}
  nop
  nop
@NextMediumBlockChanged:
  {The next medium block changed while the medium blocks were being locked}
  mov MediumBlocksLocked, False
@CannotUpsizeMediumBlockInPlace:
  {Couldn't upsize in place. Grab a new block and move the data across:
   If we have to reallocate and move medium blocks, we grow by at
   least 25%}
  mov eax, ecx
  shr eax, 2
  add eax, ecx
  {Get the maximum of the requested size and the minimum growth size}
  xor edi, edi
  sub eax, edx
  adc edi, -1
  and eax, edi
  add eax, edx
  {Save the size to allocate}
  mov ebp, eax
  {Save the size to move across}
  mov edi, ecx
  {Get the block}
  push edx
  call SysGetMem
  pop edx
  {Success?}
  test eax, eax
  jz @MediumBlockResizeDone2
  {If it's a Large block - store the actual user requested size}
  cmp ebp, MaximumMediumBlockSize - BlockHeaderSize
  jbe @MediumUpsizeNotLarge
  mov [eax - 8], edx
@MediumUpsizeNotLarge:
  {Save the result}
  mov ebp, eax
  {Move the data across}
  mov edx, eax
  mov eax, esi
  mov ecx, edi
{$ifdef UseCustomVariableSizeMoveRoutines}
  call MoveX16L4
{$else}
  call Move
{$endif}
  {Free the old block}
  mov eax, esi
  call SysFreeMem
  {Restore the result}
  mov eax, ebp
  {Restore registers}
  pop ebp
  pop edi
  pop esi
  pop ebx
  {Return}
  ret
  {Align branch target}
  nop
@PossibleLargeBlock:
  {-----------------------Large block------------------------------}
  {Restore registers}
  pop esi
  pop ebx
  {Is this a valid large block?}
  test cl, IsFreeBlockFlag + IsMediumBlockFlag
  jz ReallocateLargeBlock
  {-----------------------Invalid block------------------------------}
  xor eax, eax
end;
{$endif}

{Allocates a block and fills it with zeroes}
{$ifdef UsePascalCode}
function SysAllocMem(Size: Cardinal): Pointer;
begin
  Result := SysGetMem(Size);
  {Large blocks are already zero filled}
  if (Result <> nil) and (Size <= (MaximumMediumBlockSize - BlockHeaderSize)) then
    FillChar(Result^, Size, 0);
end;
{$else}
function SysAllocMem(Size: Cardinal): Pointer;
asm
  push ebx
  {Get the size rounded down to the previous multiple of 4 into ebx}
  lea ebx, [eax - 1]
  and ebx, -4
  {Get the block}
  call SysGetMem
  {Could a block be allocated? ecx = 0 if yes, $ffffffff if no}
  cmp eax, 1
  sbb ecx, ecx
  {Point edx to the last dword}
  lea edx, [eax + ebx]
  {ebx = $ffffffff if no block could be allocated, otherwise size rounded down
   to previous multiple of 4}
  or ebx, ecx
  {Large blocks are already zero filled}
  cmp ebx, MaximumMediumBlockSize - BlockHeaderSize
  jae @Done
  {Make the counter negative based}
  neg ebx
  {Load zero into st(0)}
  fldz
  {Clear groups of 8 bytes. Block sizes are always four less than a multiple
   of 8, with a minimum of 12 bytes}
@FillLoop:
  fst qword ptr [edx + ebx]
  add ebx, 8
  js @FillLoop
  {Clear the last four bytes}
  mov [edx], ecx
  {Clear st(0)}
  ffree st(0)
@Done:
  pop ebx
end;
{$endif}

{----------Leak Checking and State Reporting Support Functions------------}

{Advances to the next medium block. Returns nil if the end of the medium block
 pool has been reached}
function NextMediumBlock(APMediumBlock: Pointer): Pointer;
var
  LBlockSize: Cardinal;
begin
  {Get the size of this block}
  LBlockSize := PCardinal(Cardinal(APMediumBlock) - 4)^ and DropMediumAndLargeFlagsMask;
  {Advance the pointer}
  Result := Pointer(Cardinal(APMediumBlock) + LBlockSize);
  {Is the next block the end of medium pool marker?}
  LBlockSize := PCardinal(Cardinal(Result) - 4)^ and DropMediumAndLargeFlagsMask;
  if LBlockSize = 0 then
    Result := nil;
end;

{Gets the first medium block in the medium block pool}
function GetFirstMediumBlockInPool(APMediumBlockPoolHeader: PMediumBlockPoolHeader): Pointer;
begin
  if (MediumSequentialFeedBytesLeft = 0)
    or (Cardinal(LastSequentiallyFedMediumBlock) < Cardinal(APMediumBlockPoolHeader))
    or (Cardinal(LastSequentiallyFedMediumBlock) > Cardinal(APMediumBlockPoolHeader) + MediumBlockPoolSize) then
  begin
    Result := Pointer(Cardinal(APMediumBlockPoolHeader) + MediumBlockPoolHeaderSize);
  end
  else
  begin
    {Is the sequential feed pool empty?}
    if MediumSequentialFeedBytesLeft <> MediumBlockPoolSize - MediumBlockPoolHeaderSize then
      Result := LastSequentiallyFedMediumBlock
    else
      Result := nil;
  end;
end;

{Gets the first and last block pointer for a small block pool}
procedure GetFirstAndLastSmallBlockInPool(APSmallBlockPool: PSmallBlockPoolHeader;
  var AFirstPtr, ALastPtr: Pointer);
var
  LBlockSize: Cardinal;
begin
  {Get the pointer to the first block}
  AFirstPtr := Pointer(Cardinal(APSmallBlockPool) + SmallBlockPoolHeaderSize);
  {Get a pointer to the last block}
  if (APSmallBlockPool.BlockType.CurrentSequentialFeedPool <> APSmallBlockPool)
    or (Cardinal(APSmallBlockPool.BlockType.NextSequentialFeedBlockAddress) > Cardinal(APSmallBlockPool.BlockType.MaxSequentialFeedBlockAddress)) then
  begin
    {Not the sequential feed - point to the end of the block}
    LBlockSize := PCardinal(Cardinal(APSmallBlockPool) - 4)^ and DropMediumAndLargeFlagsMask;
    ALastPtr := Pointer(Cardinal(APSmallBlockPool) + LBlockSize - APSmallBlockPool.BlockType.BlockSize);
  end
  else
  begin
    {The sequential feed pool - point to before the next sequential feed block}
    ALastPtr := Pointer(Cardinal(APSmallBlockPool.BlockType.NextSequentialFeedBlockAddress) - 1);
  end;
end;

{--------------------Memory Leak Checking and Reporting-------------------}

{$ifdef IncludeMemoryLeakTrackingCode}
{Converts a cardinal to string at the buffer location, returning the new
 buffer position.}
function CardinalToStrBuf(ACardinal: Cardinal; ABuffer: PChar): PChar;
asm
  {On entry: eax = ACardinal, edx = ABuffer}
  push edi
  mov edi, edx                //Pointer to the first character in edi
  //Calculate leading digit: divide the number by 1e9
  add eax, 1                  //Increment the number
  mov edx, $89705f41          //1e9 reciprocal
  mul edx                     //Multplying with reciprocal
  shr eax, 30                 //Save fraction bits
  mov ecx, edx                //First digit in bits <31:29>
  and edx, $1fffffff          //Filter fraction part edx<28:0>
  shr ecx, 29                 //Get leading digit into accumulator
  lea edx, [edx + edx * 4]    //Calculate ...
  add edx, eax                //... 5*fraction
  mov eax, ecx                //Copy leading digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #2
  mov eax, edx                //Point format such that 1.0 = 2^28
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 28                 //Next digit
  and edx, $0fffffff          //Fraction part edx<27:0>
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #3
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:27>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<26:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 27                 //Next digit
  and edx, $07ffffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #4
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:26>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<25:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 26                 //Next digit
  and edx, $03ffffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #5
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:25>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<24:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 25                 //Next digit
  and edx, $01ffffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #6
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:24>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<23:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 24                 //Next digit
  and edx, $00ffffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #7
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:23>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<31:23>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 23                 //Next digit
  and edx, $007fffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #8
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:22>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<22:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 22                 //Next digit
  and edx, $003fffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #9
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:21>
  lea edx, [edx + edx * 4]    //5*fraction, new fraction edx<21:0>
  cmp ecx, 1                  //Any non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 21                 //Next digit
  and edx, $001fffff          //Fraction part
  or ecx, eax                 //Accumulate next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store digit out to memory
  //Calculate digit #10
  lea eax, [edx + edx * 4]    //5*fraction, new digit eax<31:20>
  cmp ecx, 1                  //Any-non-zero digit yet ?
  sbb edi, -1                 //Yes->increment ptr, No->keep old ptr
  shr eax, 20                 //Next digit
  or eax, '0'                 //Convert digit to ASCII
  mov [edi], al               //Store last digit and end marker out to memory
  {Return a pointer to the next character}
  lea eax, [edi + 1]
  {Restore edi}
  pop edi
end;

{Appends the source text to the destination and returns the new destination
 position}
function AppendStringToBuffer(const ASource, ADestination: PChar; ACount: Cardinal): PChar;
begin
  System.Move(ASource^, ADestination^, ACount);
  Result := Pointer(Cardinal(ADestination) + ACount);
end;

{Returns the class for a memory block. Returns nil if it is not a valid class}
function GetObjectClass(APointer: Pointer): TClass;
var
  LMemInfo: TMemInfo;

  {Checks whether the given address is a valid address for a VMT entry.}
  function IsValidVMTAddress(APAddress: PCardinal): Boolean;
  begin
    {Do some basic pointer checks: Must be dword aligned and beyond 64K}
    if (Cardinal(APAddress) > 65535)
      and (Cardinal(APAddress) and 3 = 0) then
    begin
      {Do we need to recheck the virtual memory?}
      if (Cardinal(LMemInfo.BaseAddress) > Cardinal(APAddress))
        or ((Cardinal(LMemInfo.BaseAddress) + Cardinal(LMemInfo.RegionSize)) < (Cardinal(APAddress) + 4)) then
      begin
        {Get the VM status for the pointer}
        LMemInfo.RegionSize := 0;
        VirtualQuery(APAddress,  LMemInfo, SizeOf(LMemInfo));
      end;
      {Check the readability of the memory address}
      Result := (Cardinal(LMemInfo.RegionSize) >= 4)
        and (LMemInfo.State = MEM_COMMIT)
        and (LMemInfo.Protect and (PAGE_READONLY or PAGE_READWRITE
          or PAGE_EXECUTE or PAGE_EXECUTE_READ or PAGE_EXECUTE_READWRITE or PAGE_EXECUTE_WRITECOPY) <> 0)
        and (LMemInfo.Protect and PAGE_GUARD = 0);
    end
    else
      Result := False;
  end;

  {Returns true if AClassPointer points to a class VMT}
  function InternalIsValidClass(AClassPointer: Pointer; ADepth: Integer = 0): Boolean;
  var
    LParentClassSelfPointer: PCardinal;
  begin
    {Check that the self pointer as well as parent class self pointer addresses
     are valid}
    if (ADepth < 1000)
      and IsValidVMTAddress(Pointer(Integer(AClassPointer) + vmtSelfPtr))
      and IsValidVMTAddress(Pointer(Integer(AClassPointer) + vmtParent)) then
    begin
      {Get a pointer to the parent class' self pointer}
      LParentClassSelfPointer := PPointer(Integer(AClassPointer) + vmtParent)^;
      {Check that the self pointer as well as the parent class is valid}
      Result := (PPointer(Integer(AClassPointer) + vmtSelfPtr)^ = AClassPointer)
        and ((LParentClassSelfPointer = nil)
          or (IsValidVMTAddress(LParentClassSelfPointer)
            and InternalIsValidClass(PCardinal(LParentClassSelfPointer^), ADepth + 1)));
    end
    else
      Result := False;
  end;

begin
  {Get the class pointer from the (suspected) object}
  Result := TClass(PCardinal(APointer)^);
  {No VM info yet}
  LMemInfo.RegionSize := 0;
  {Check the block}
  if not InternalIsValidClass(Pointer(Result), 0) then
    Result := nil;
end;
{$endif}

{$ifdef IncludeMemoryLeakTrackingCode}
{Locks the expected leaks. Returns false if the list could not be allocated.}
function LockExpectedMemoryLeaksList: Boolean;
begin
  {Lock the expected leaks list}
  if IsMultiThread then
  begin
    while LockCmpxchg(0, 1, @ExpectedMemoryLeaksListLocked) <> 0 do
    begin
      if not NeverSleepOnMMThreadContention then
      begin
        Sleep(InitialSleepTime);
        if LockCmpxchg(0, 1, @ExpectedMemoryLeaksListLocked) = 0 then
          break;
        Sleep(AdditionalSleepTime);
      end;
    end;
  end;
  {Allocate the list if it does not exist}
  if ExpectedMemoryLeaks = nil then
    ExpectedMemoryLeaks := VirtualAlloc(nil, ExpectedMemoryLeaksListSize, MEM_COMMIT, PAGE_READWRITE);
  {Done}
  Result := ExpectedMemoryLeaks <> nil;
end;
{$endif}

{Registers expected memory leaks. Returns true on success. The list of leaked
 blocks is limited, so failure is possible if the list is full.}
function SysRegisterExpectedMemoryLeak(P: Pointer): boolean;
begin
{$ifdef IncludeMemoryLeakTrackingCode}
  if LockExpectedMemoryLeaksList and
    (ExpectedMemoryLeaks.NumExpectedLeaks < high(ExpectedMemoryLeaks.ExpectedLeaks)) then
  begin
    ExpectedMemoryLeaks.ExpectedLeaks[ExpectedMemoryLeaks.NumExpectedLeaks] := P;
    Inc(ExpectedMemoryLeaks.NumExpectedLeaks);
    Result := True;
  end
  else
    Result := False;
  ExpectedMemoryLeaksListLocked := False;
{$else}
  Result := False;
{$endif}
end;

function SysUnregisterExpectedMemoryLeak(P: Pointer): boolean;
{$ifdef IncludeMemoryLeakTrackingCode}
var
  LIndex: integer;
{$endif}
begin
  {Default to error}
  Result := False;
{$ifdef IncludeMemoryLeakTrackingCode}
  if (ExpectedMemoryleaks <> nil) and LockExpectedMemoryLeaksList then
  begin
    for LIndex := 0 to ExpectedMemoryleaks.NumExpectedLeaks - 1 do
    begin
      if ExpectedMemoryleaks.ExpectedLeaks[LIndex] = P then
      begin
        ExpectedMemoryleaks.ExpectedLeaks[LIndex] :=
          ExpectedMemoryleaks.ExpectedLeaks[ExpectedMemoryleaks.NumExpectedLeaks - 1];
        Dec(ExpectedMemoryleaks.NumExpectedLeaks);
        Result := True;
        break;
      end;
    end;
    ExpectedMemoryLeaksListLocked := False;
  end;
{$endif}
end;

{$ifdef IncludeMemoryLeakTrackingCode}
{Checks for memory leaks on shutdown}
procedure ScanForMemoryLeaks;
type
  {Leaked class type}
  TLeakedClass = packed record
    ClassPointer: TClass;
    NumLeaks: Cardinal;
  end;
  TLeakedClasses = array[0..255] of TLeakedClass;
  PLeakedClasses = ^TLeakedClasses;
  {Leak statistics for a small block type}
  TSmallBlockLeaks = array[0..NumSmallBlockTypes - 1] of TLeakedClasses;
  {A leaked medium or large block}
  TMediumAndLargeBlockLeaks = array[0..4095] of Cardinal;
var
  {The leaked classes for small blocks}
  LSmallBlockLeaks: TSmallBlockLeaks;
  LMediumAndLargeBlockLeaks: TMediumAndLargeBlockLeaks;
  LNumMediumAndLargeLeaks: Integer;
  LPLargeBlock: PLargeBlockHeader;
  LLeakMessage: array[0..32767] of char;
  LMsgPtr: PChar;
  LClassName: ShortString;
  LExpectedLeaksOnly, LSmallLeakHeaderAdded, LBlockSizeHeaderAdded: Boolean;
  LBlockTypeInd, LMediumBlockSize, LLargeBlockSize,
    LClassInd, LPreviousBlockSize, LThisBlockSize, LBlockInd: Cardinal;
  LPMediumBlock: Pointer;
  LPMediumBlockPoolHeader: PMediumBlockPoolHeader;
  LMediumBlockHeader: Cardinal;

  {Checks the small block pool for leaks.}
  procedure CheckSmallBlockPoolForLeaks(APSmallBlockPool: PSmallBlockPoolHeader);
  var
    LLeakedClass: TClass;
    LCharInd, LClassIndex, LStringLength: Integer;
    LPStr: PChar;
    LPossibleString: boolean;
    LCurPtr, LEndPtr: Pointer;
    LBlockTypeIndex: Cardinal;
    LPLeakedClasses: PLeakedClasses;
  begin
    {Get the block type index}
    LBlockTypeIndex := (Cardinal(APSmallBlockPool.BlockType) - Cardinal(@SmallBlockTypes[0])) div SizeOf(TSmallBlockType);
    LPLeakedClasses := @LSmallBlockLeaks[LBlockTypeIndex];
    {Get the first and last pointer for the pool}
    GetFirstAndLastSmallBlockInPool(APSmallBlockPool, LCurPtr, LEndPtr);
    {Step through all blocks}
    while Cardinal(LCurPtr) <= Cardinal(LEndPtr) do
    begin
      {Is this block an unexpected leak?}
      if ((PCardinal(Cardinal(LCurPtr) - 4)^ and IsFreeBlockFlag) = 0)
        and (not SysUnregisterExpectedMemoryLeak(LCurPtr)) then
      begin
        LExpectedLeaksOnly := False;
        {Default to an unknown block}
        LClassIndex := 0;
        {Get the class contained by the block}
        LLeakedClass := GetObjectClass(LCurPtr);
        {Not a class? -> is it perhaps a string?}
        if LLeakedClass = nil then
        begin
          {Reference count < 256}
          if (PCardinal(LCurPtr)^ < 256) then
          begin
            LStringLength := PCardinal(Cardinal(LCurPtr) + 4)^;
            {Does the string fit?}
            if (LStringLength > 0)
              and (LStringLength <= (APSmallBlockPool.BlockType.BlockSize - (8 + 1 + 4))) then
            begin
              {Check that all characters are in range #32..#127}
              LPStr := PChar(Cardinal(LCurPtr) + 8);
              LPossibleString := True;
              for LCharInd := 1 to LStringLength do
              begin
                LPossibleString := LPossibleString and (LPStr^ >= #32) and (LPStr^ < #128);
                Inc(LPStr);
              end;
              {Must have a trailing #0}
              if LPossibleString and (LPStr^ = #0) then
              begin
                LClassIndex := 1;
              end;
            end;
          end;
        end
        else
        begin
          LClassIndex := 2;
          while LClassIndex <= High(TLeakedClasses) do
          begin
            if (LPLeakedClasses[LClassIndex].ClassPointer = LLeakedClass)
              or (LPLeakedClasses[LClassIndex].ClassPointer = nil) then
            begin
              break;
            end;
            Inc(LClassIndex);
          end;
          if LClassIndex <= High(TLeakedClasses) then
            LPLeakedClasses[LClassIndex].ClassPointer := LLeakedClass
          else
            LClassIndex := 0;
        end;
        {Add to the number of leaks for the class}
        Inc(LPLeakedClasses[LClassIndex].NumLeaks);
      end;
      {Next block}
      Inc(Cardinal(LCurPtr), APSmallBlockPool.BlockType.BlockSize);
    end;
  end;

begin
  {Clear the leak arrays}
  FillChar(LSmallBlockLeaks, SizeOf(LSmallBlockLeaks), 0);
  FillChar(LMediumAndLargeBlockLeaks, SizeOf(LMediumAndLargeBlockLeaks), 0);
  {Step through all the medium block pools}
  LNumMediumAndLargeLeaks := 0;
  {No unexpected leaks so far}
  LExpectedLeaksOnly := True;
  {Step through all the medium block pools}
  LPMediumBlockPoolHeader := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
  while LPMediumBlockPoolHeader <> @MediumBlockPoolsCircularList do
  begin
    LPMediumBlock := GetFirstMediumBlockInPool(LPMediumBlockPoolHeader);
    while LPMediumBlock <> nil do
    begin
      LMediumBlockHeader := PCardinal(Cardinal(LPMediumBlock) - 4)^;
      {Is the block in use?}
      if LMediumBlockHeader and IsFreeBlockFlag = 0 then
      begin
        if (LMediumBlockHeader and IsSmallBlockPoolInUseFlag) <> 0 then
        begin
          {Get all the leaks for the small block pool}
          CheckSmallBlockPoolForLeaks(LPMediumBlock);
        end
        else
        begin
          if LNumMediumAndLargeLeaks < length(LMediumAndLargeBlockLeaks) then
          begin
            LMediumBlockSize := (LMediumBlockHeader and DropMediumAndLargeFlagsMask) - BlockHeaderSize;
            {Is it an expected leak?}
            if not SysUnregisterExpectedMemoryLeak(LPMediumBlock) then
            begin
              LExpectedLeaksOnly := False;
              {Add the leak to the list}
              LMediumAndLargeBlockLeaks[LNumMediumAndLargeLeaks] := LMediumBlockSize;
              Inc(LNumMediumAndLargeLeaks);
            end;
          end;
        end;
      end;
      {Next medium block}
      LPMediumBlock := NextMediumBlock(LPMediumBlock);
    end;
    {Get the next medium block pool}
    LPMediumBlockPoolHeader := LPMediumBlockPoolHeader.NextMediumBlockPoolHeader;
  end;
  {Get all leaked large blocks}
  LPLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
  while (LPLargeBlock <> @LargeBlocksCircularList)
    and (LNumMediumAndLargeLeaks < length(LMediumAndLargeBlockLeaks)) do
  begin
    {Is it an expected leak?}
    if not SysUnregisterExpectedMemoryLeak(Pointer(Cardinal(LPLargeBlock) + LargeBlockHeaderSize)) then
    begin
      {Add the leak}
      LExpectedLeaksOnly := False;
      LLargeBlockSize := (LPLargeBlock.BlockSizeAndFlags and DropMediumAndLargeFlagsMask)
        - BlockHeaderSize - LargeBlockHeaderSize;
      LMediumAndLargeBlockLeaks[LNumMediumAndLargeLeaks] := LLargeBlockSize;
      Inc(LNumMediumAndLargeLeaks);
    end;
    {Get the next large block}
    LPLargeBlock := LPLargeBlock.NextLargeBlockHeader;
  end;
  {Display the leak message if required}
  if not LExpectedLeaksOnly then
  begin
    {Small leak header has not been added}
    LSmallLeakHeaderAdded := False;
    LPreviousBlockSize := 0;
    {Set up the leak message header so long}
    LMsgPtr := AppendStringToBuffer(LeakMessageHeader, @LLeakMessage[0], length(LeakMessageHeader));
    {Step through all the small block types}
    for LBlockTypeInd := 0 to NumSmallBlockTypes - 1 do
    begin
      LThisBlockSize := SmallBlockTypes[LBlockTypeInd].BlockSize - BlockHeaderSize;
      LBlockSizeHeaderAdded := False;
      {Any leaks?}
      for LClassInd := high(LSmallBlockLeaks[LBlockTypeInd]) downto 0 do
      begin
        {Is there still space in the message buffer? Reserve space for the message
         footer.}
        if LMsgPtr > @LLeakMessage[high(LLeakMessage) - 2048] then
          break;
        {Check the count}
        if LSmallBlockLeaks[LBlockTypeInd][LClassInd].NumLeaks > 0 then
        begin
          {Need to add the header?}
          if not LSmallLeakHeaderAdded then
          begin
            LMsgPtr := AppendStringToBuffer(SmallLeakDetail, LMsgPtr, Length(SmallLeakDetail));
            LSmallLeakHeaderAdded := True;
          end;
          {Need to add the size header?}
          if not LBlockSizeHeaderAdded then
          begin
            LMsgPtr^ := #13;
            Inc(LMsgPtr);
            LMsgPtr^ := #10;
            Inc(LMsgPtr);
            LMsgPtr := CardinalToStrBuf(LPreviousBlockSize + 1, LMsgPtr);
            LMsgPtr^ := ' ';
            Inc(LMsgPtr);
            LMsgPtr^ := '-';
            Inc(LMsgPtr);
            LMsgPtr^ := ' ';
            Inc(LMsgPtr);
            LMsgPtr := CardinalToStrBuf(LThisBlockSize, LMsgPtr);
            LMsgPtr := AppendStringToBuffer(BytesMessage, LMsgPtr, Length(BytesMessage));
            LBlockSizeHeaderAdded := True;
          end
          else
          begin
            LMsgPtr^ := ',';
            Inc(LMsgPtr);
            LMsgPtr^ := ' ';
            Inc(LMsgPtr);
          end;
          {Show the count}
          case LClassInd of
            {Unknown}
            0:
            begin
              LMsgPtr := AppendStringToBuffer(UnknownClassNameMsg, LMsgPtr, Length(UnknownClassNameMsg));
            end;
            {Strings}
            1:
            begin
              LMsgPtr := AppendStringToBuffer(StringBlockMessage, LMsgPtr, Length(StringBlockMessage));
            end;
            {Classes}
          else
            begin
              LClassName := LSmallBlockLeaks[LBlockTypeInd][LClassInd].ClassPointer.ClassName;
              LMsgPtr := AppendStringToBuffer(@LClassName[1], LMsgPtr, Length(LClassName));
            end;
          end;
          {Add the count}
          LMsgPtr^ := ' ';
          Inc(LMsgPtr);
          LMsgPtr^ := 'x';
          Inc(LMsgPtr);
          LMsgPtr^ := ' ';
          Inc(LMsgPtr);
          LMsgPtr := CardinalToStrBuf(LSmallBlockLeaks[LBlockTypeInd][LClassInd].NumLeaks, LMsgPtr);
        end;
      end;
      LPreviousBlockSize := LThisBlockSize;
    end;
    {Add the medium/large block leak message}
    if LNumMediumAndLargeLeaks > 0 then
    begin
      {Any non-small leaks?}
      if LSmallLeakHeaderAdded then
      begin
        LMsgPtr^ := #13;
        Inc(LMsgPtr);
        LMsgPtr^ := #10;
        Inc(LMsgPtr);
        LMsgPtr^ := #13;
        Inc(LMsgPtr);
        LMsgPtr^ := #10;
        Inc(LMsgPtr);
      end;
      {Add the medium/large block leak message}
      LMsgPtr := AppendStringToBuffer(LargeLeakDetail, LMsgPtr, Length(LargeLeakDetail));
      {List all the blocks}
      for LBlockInd := 0 to LNumMediumAndLargeLeaks - 1 do
      begin
        if LBlockInd <> 0 then
        begin
          LMsgPtr^ := ',';
          Inc(LMsgPtr);
          LMsgPtr^ :=  ' ';
          Inc(LMsgPtr);
        end;
        LMsgPtr := CardinalToStrBuf(LMediumAndLargeBlockLeaks[LBlockInd], LMsgPtr);
        {Is there still space in the message buffer? Reserve space for the
         message footer.}
        if LMsgPtr > @LLeakMessage[high(LLeakMessage) - 2048] then
          break;
      end;
    end;
    {Set the message footer}
    AppendStringToBuffer(LeakMessageFooter, LMsgPtr, Length(LeakMessageFooter));
    {Show the message}
    MessageBox(0, LLeakMessage, LeakMessageTitle,
      MB_OK or MB_ICONERROR or MB_TASKMODAL);
  end;
end;
{$endif}

{-------------Memory Manager and Memory Usage Stats Reporting-------------}

{Returns statistics about the current state of the memory manager}
procedure GetMemoryManagerState(var AMemoryManagerState: TMemoryManagerState);
var
  LPMediumBlockPoolHeader: PMediumBlockPoolHeader;
  LPMediumBlock: Pointer;
  LInd: Integer;
  LBlockTypeIndex, LMediumBlockSize, LMediumBlockHeader, LLargeBlockSize: Cardinal;
  LPLargeBlock: PLargeBlockHeader;
begin
  {Clear the results}
  FillChar(AMemoryManagerState, SizeOf(AMemoryManagerState), 0);
  {Set the small block size stats}
  for LInd := 0 to NumSmallBlockTypes - 1 do
  begin
    AMemoryManagerState.SmallBlockTypeStates[LInd].InternalBlockSize :=
      SmallBlockTypes[LInd].BlockSize;
    AMemoryManagerState.SmallBlockTypeStates[LInd].UseableBlockSize :=
      SmallBlockTypes[LInd].BlockSize - BlockHeaderSize;
    if Integer(AMemoryManagerState.SmallBlockTypeStates[LInd].UseableBlockSize) < 0 then
      AMemoryManagerState.SmallBlockTypeStates[LInd].UseableBlockSize := 0;
  end;
  {Lock all small block types}
  LockAllSmallBlockTypes;
  {Lock the medium blocks}
  LockMediumBlocks;
  {Step through all the medium block pools}
  LPMediumBlockPoolHeader := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
  while LPMediumBlockPoolHeader <> @MediumBlockPoolsCircularList do
  begin
    {Add to the medium block used space}
    Inc(AMemoryManagerState.ReservedMediumBlockAddressSpace, MediumBlockPoolSize);
    LPMediumBlock := GetFirstMediumBlockInPool(LPMediumBlockPoolHeader);
    while LPMediumBlock <> nil do
    begin
      LMediumBlockHeader := PCardinal(Cardinal(LPMediumBlock) - 4)^;
      {Is the block in use?}
      if LMediumBlockHeader and IsFreeBlockFlag = 0 then
      begin
        {Get the block size}
        LMediumBlockSize := LMediumBlockHeader and DropMediumAndLargeFlagsMask;
        if (LMediumBlockHeader and IsSmallBlockPoolInUseFlag) <> 0 then
        begin
          {Get the block type index}
          LBlockTypeIndex := (Cardinal(PSmallBlockPoolHeader(LPMediumBlock).BlockType)
            - Cardinal(@SmallBlockTypes[0])) div SizeOf(TSmallBlockType);
          {Subtract from medium block usage}
          Dec(AMemoryManagerState.ReservedMediumBlockAddressSpace, LMediumBlockSize);
          {Add it to the reserved space for the block size}
          Inc(AMemoryManagerState.SmallBlockTypeStates[LBlockTypeIndex].ReservedAddressSpace, LMediumBlockSize);
          {Add the usage for the pool}
          Inc(AMemoryManagerState.SmallBlockTypeStates[LBlockTypeIndex].AllocatedBlockCount,
            PSmallBlockPoolHeader(LPMediumBlock).BlocksInUse);
        end
        else
        begin
          Inc(AMemoryManagerState.AllocatedMediumBlockCount);
          Inc(AMemoryManagerState.TotalAllocatedMediumBlockSize, LMediumBlockSize - BlockHeaderSize);
        end;
      end;
      {Next medium block}
      LPMediumBlock := NextMediumBlock(LPMediumBlock);
    end;
    {Get the next medium block pool}
    LPMediumBlockPoolHeader := LPMediumBlockPoolHeader.NextMediumBlockPoolHeader;
  end;
  {Unlock medium blocks}
  MediumBlocksLocked := False;
  {Unlock all the small block types}
  for LInd := 0 to NumSmallBlockTypes - 1 do
    SmallBlockTypes[LInd].BlockTypeLocked := False;
  {Step through all the large blocks}
  LockLargeBlocks;
  LPLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
  while (LPLargeBlock <> @LargeBlocksCircularList) do
  begin
    LLargeBlockSize := LPLargeBlock.BlockSizeAndFlags and DropMediumAndLargeFlagsMask;
    Inc(AMemoryManagerState.AllocatedLargeBlockCount);
    Inc(AMemoryManagerState.ReservedLargeBlockAddressSpace, LLargeBlockSize);
    Inc(AMemoryManagerState.TotalAllocatedLargeBlockSize, LPLargeBlock.UserAllocatedSize);
    {Get the next large block}
    LPLargeBlock := LPLargeBlock.NextLargeBlockHeader;
  end;
  LargeBlocksLocked := False;
end;

{Gets the state of every 64K block in the 4GB address space}
procedure GetMemoryMap(var AMemoryMap: TMemoryMap);
var
  LPMediumBlockPoolHeader: PMediumBlockPoolHeader;
  LPLargeBlock: PLargeBlockHeader;
  LLargeBlockSize, LChunkIndex, LInd: Cardinal;
  LMBI: TMemInfo;
begin
  {Clear the map}
  FillChar(AMemoryMap, SizeOf(AMemoryMap), ord(csUnallocated));
  {Step through all the medium block pools}
  LockMediumBlocks;
  LPMediumBlockPoolHeader := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
  while LPMediumBlockPoolHeader <> @MediumBlockPoolsCircularList do
  begin
    {Add to the medium block used space}
    LChunkIndex := Cardinal(LPMediumBlockPoolHeader) shr 16;
    for LInd := 0 to (MediumBlockPoolSize - 1) shr 16 do
      AMemoryMap[LChunkIndex + LInd] := csAllocated;
    {Get the next medium block pool}
    LPMediumBlockPoolHeader := LPMediumBlockPoolHeader.NextMediumBlockPoolHeader;
  end;
  MediumBlocksLocked := False;
  {Step through all the large blocks}
  LockLargeBlocks;
  LPLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
  while (LPLargeBlock <> @LargeBlocksCircularList) do
  begin
    LChunkIndex := Cardinal(LPLargeBlock) shr 16;
    LLargeBlockSize := LPLargeBlock.BlockSizeAndFlags and DropMediumAndLargeFlagsMask;
    for LInd := 0 to (LLargeBlockSize - 1) shr 16 do
      AMemoryMap[LChunkIndex + LInd] := csAllocated;
    {Get the next large block}
    LPLargeBlock := LPLargeBlock.NextLargeBlockHeader;
  end;
  LargeBlocksLocked := False;
  {Fill in the rest of the map}
  for LInd := 0 to 65535 do
  begin
    {If the chunk is not allocated by this MM, what is its status?}
    if AMemoryMap[LInd] = csUnallocated then
    begin
      {Get all the reserved memory blocks and windows allocated memory blocks, etc.}
      VirtualQuery(Pointer(LInd * 65536), LMBI, SizeOf(LMBI));
      if LMBI.State = MEM_COMMIT then
        AMemoryMap[LInd] := csSysAllocated
      else
        if LMBI.State = MEM_RESERVE then
          AMemoryMap[LInd] := csSysReserved;
    end;
  end;
end;

{Returns summarised information about the state of the memory manager.}
function GetHeapStatus: THeapStatus;
var
  LPMediumBlockPoolHeader: PMediumBlockPoolHeader;
  LPMediumBlock: Pointer;
  LBlockTypeIndex, LMediumBlockSize, LMediumBlockHeader, LLargeBlockSize,
    LSmallBlockUsage, LSmallBlockOverhead: Cardinal;
  LInd: Integer;
  LPLargeBlock: PLargeBlockHeader;
begin
  {Clear the structure}
  FillChar(Result, SizeOf(Result), 0);
  {Lock all small block types}
  LockAllSmallBlockTypes;
  {Lock the medium blocks}
  LockMediumBlocks;
  {Step through all the medium block pools}
  LPMediumBlockPoolHeader := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
  while LPMediumBlockPoolHeader <> @MediumBlockPoolsCircularList do
  begin
    {Add to the total and committed address space}
    Inc(Result.TotalAddrSpace, ((MediumBlockPoolSize + $ffff) and $ffff0000));
    Inc(Result.TotalCommitted, ((MediumBlockPoolSize + $ffff) and $ffff0000));
    {Add the medium block pool overhead}
    Inc(Result.Overhead, (((MediumBlockPoolSize + $ffff) and $ffff0000)
      - MediumBlockPoolSize + MediumBlockPoolHeaderSize));
    {Get the first medium block in the pool}
    LPMediumBlock := GetFirstMediumBlockInPool(LPMediumBlockPoolHeader);
    while LPMediumBlock <> nil do
    begin
      {Get the block header}
      LMediumBlockHeader := PCardinal(Cardinal(LPMediumBlock) - 4)^;
      {Get the block size}
      LMediumBlockSize := LMediumBlockHeader and DropMediumAndLargeFlagsMask;
      {Is the block in use?}
      if LMediumBlockHeader and IsFreeBlockFlag = 0 then
      begin
        if (LMediumBlockHeader and IsSmallBlockPoolInUseFlag) <> 0 then
        begin
          {Get the block type index}
          LBlockTypeIndex := (Cardinal(PSmallBlockPoolHeader(LPMediumBlock).BlockType)
            - Cardinal(@SmallBlockTypes[0])) div SizeOf(TSmallBlockType);
          {Get the usage in the block}
          LSmallBlockUsage := PSmallBlockPoolHeader(LPMediumBlock).BlocksInUse
            * SmallBlockTypes[LBlockTypeIndex].BlockSize;
          {Get the total overhead for all the small blocks}
          LSmallBlockOverhead := PSmallBlockPoolHeader(LPMediumBlock).BlocksInUse
              * BlockHeaderSize;
          {Add to the totals}
          Inc(Result.FreeSmall, LMediumBlockSize - LSmallBlockUsage - BlockHeaderSize);
          Inc(Result.Overhead, LSmallBlockOverhead + BlockHeaderSize);
          Inc(Result.TotalAllocated, LSmallBlockUsage - LSmallBlockOverhead);
        end
        else
        begin
          {Add to the result}
          Inc(Result.TotalAllocated, LMediumBlockSize - BlockHeaderSize);
          Inc(Result.Overhead, BlockHeaderSize);
        end;
      end
      else
      begin
        {The medium block is free}
        Inc(Result.FreeBig, LMediumBlockSize);
      end;
      {Next medium block}
      LPMediumBlock := NextMediumBlock(LPMediumBlock);
    end;
    {Get the next medium block pool}
    LPMediumBlockPoolHeader := LPMediumBlockPoolHeader.NextMediumBlockPoolHeader;
  end;
  {Add the sequential feed unused space}
  Inc(Result.Unused, MediumSequentialFeedBytesLeft);
  {Unlock the medium blocks}
  MediumBlocksLocked := False;
  {Unlock all the small block types}
  for LInd := 0 to NumSmallBlockTypes - 1 do
    SmallBlockTypes[LInd].BlockTypeLocked := False;
  {Step through all the large blocks}
  LockLargeBlocks;
  LPLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
  while (LPLargeBlock <> @LargeBlocksCircularList) do
  begin
    LLargeBlockSize := LPLargeBlock.BlockSizeAndFlags and DropMediumAndLargeFlagsMask;
    Inc(Result.TotalAddrSpace, LLargeBlockSize);
    Inc(Result.TotalCommitted, LLargeBlockSize);
    Inc(Result.TotalAllocated, LPLargeBlock.UserAllocatedSize);
    Inc(Result.Overhead, LLargeBlockSize - LPLargeBlock.UserAllocatedSize);
    {Get the next large block}
    LPLargeBlock := LPLargeBlock.NextLargeBlockHeader;
  end;
  LargeBlocksLocked := False;
  {Set the total number of free bytes}
  Result.TotalFree := Result.FreeSmall + Result.FreeBig + Result.Unused;
end;

{------------------------Memory Manager Sharing---------------------------}

{Wrapper around CreateWindowEx, but preserves the FPU control word}
function CreateWindow(lpClassName: PChar; lpWindowName: PChar;
  dwStyle: DWORD; X, Y, nWidth, nHeight: Integer; hWndParent: HWND;
  hMenu: HMENU; hInstance: HINST; lpParam: Pointer): HWND;
var
  FPUCW: Word;
begin
  {Protect the FPU control word}
  FPUCW := Get8087CW;
  Result := CreateWindowEx(0, lpClassName, lpWindowName, dwStyle, X, Y,
    nWidth, nHeight, hWndParent, hMenu, hInstance, lpParam);
  Set8087CW(FPUCW);
end;

{Generates a string identifying the process}
procedure BuildProcessIDString;
var
  i, LProcessID: Cardinal;
begin
  LProcessID := GetCurrentProcessId;
  for i := 0 to 7 do
  begin
    UniqueProcessIDString[8 - i] :=
      HexTable[((LProcessID shr (i * 4)) and $F)];
  end;
end;

{Searches the current process for a shared memory manager}
function FindSharedMemoryManager: PMemoryManagerEx;
var
  LSharedMMWindow: HWND;
begin
  BuildProcessIDString;
  {Find the shared memory manager}
  LSharedMMWindow := FindWindow('STATIC', PChar(@UniqueProcessIDString[1]));
  if LSharedMMWindow = 0 then
  begin
    {No shared memory manager in the process}
    Result := nil;
  end
  else
  begin
    {Get the address of the shared memory manager}
    Result := PMemoryManagerEx(GetWindowLong(LSharedMMWindow, GWL_USERDATA));
  end;
end;

{Searches the current process for a shared memory manager. If no memory has
 been allocated using this memory manager it will switch to using the shared
 memory manager instead. Returns true if another memory manager was found and
 it could be shared.}
function AttemptToUseSharedMemoryManager: Boolean;
var
  LPMemoryManagerEx: PMemoryManagerEx;
begin
  if not IsMemoryManagerSet then
  begin
    {Is this MM being shared? If so, switching to another MM is not allowed}
    if MMSharingWindow = 0 then
    begin
      {May not switch memory manager after memory has been allocated}
      if (MediumBlockPoolsCircularList.NextMediumBlockPoolHeader = @MediumBlockPoolsCircularList)
        and (LargeBlocksCircularList.NextLargeBlockHeader = @LargeBlocksCircularList) then
      begin
        LPMemoryManagerEx := FindSharedMemoryManager;
        if LPMemoryManagerEx <> nil then
        begin
          SetMemoryManager(LPMemoryManagerEx^);
          Result := True;
        end
        else
          Result := False;
      end
      else
      begin
        {Memory has already been allocated using this memory manager. We cannot
         rip the memory manager out from under live pointers.}
        MessageBox(0, LivePointersErrorMsg, ShareMMErrorTitle,
          MB_OK or MB_ICONERROR or MB_TASKMODAL);
        Result := False;
      end;
    end
    else
    begin
      {Display an error message: not allowed to switch memory manager if it is
       being shared.}
        MessageBox(0, BeingSharedErrorMsg, ShareMMErrorTitle,
          MB_OK or MB_ICONERROR or MB_TASKMODAL);
      Result := False;
    end;
  end
  else
  begin
    {Another memory manager has already been installed.}
    Result := False;
  end;
end;

{Starts sharing this memory manager with other modules in the current process.
 Only one memory manager may be shared per process, so this function may fail.}
function ShareMemoryManager: Boolean;
begin
  if (not IsMemoryManagerSet) and (MMSharingWindow = 0) then
  begin
    {Is any other module already sharing its MM?}
    if (FindSharedMemoryManager = nil) then
    begin
      {No memory manager installed yet - create the invisible window}
      MMSharingWindow := CreateWindow('STATIC', PChar(@UniqueProcessIDString[1]),
        WS_POPUP, 0, 0, 0, 0, 0, 0, hInstance, nil);
      {The window data is a pointer to this shared memory manager}
      SetWindowLong(MMSharingWindow, GWL_USERDATA, Integer(@ThisMemoryManager));
      {Sharing this MM}
      Result := True;
    end
    else
    begin
      {Another module is already sharing its memory manager}
      Result := False;
    end;
  end
  else
  begin
    {Either another memory manager has been set or this memory manager is
     already being shared}
    Result := False;
  end;
end;

{--------------------------Memory Manager Setup---------------------------}

{Builds the block size to small block type lookup table}
procedure BuildBlockTypeLookupTable;
var
  LBlockTypeInd, LStartIndex, LNextStartIndex: Cardinal;
  LBlockTypeVal: Byte;
begin
  LStartIndex := 0;
  for LBlockTypeInd := 0 to high(SmallBlockTypes) do
  begin
    {Is this a valid block type for the alignment restriction?}
    if (MinimumBlockAlignment = mba8Byte)
      or (SmallBlockTypes[LBlockTypeInd].BlockSize and 15 = 0) then
    begin
      LNextStartIndex := SmallBlockTypes[LBlockTypeInd].BlockSize div SmallBlockGranularity;
      {Store the block type index * 4 in the appropriate slots.}
      LBlockTypeVal := LBlockTypeInd * 4;
      while LStartIndex < LNextStartIndex do
      begin
        AllocSize2SmallBlockTypeIndX4[LStartIndex] := LBlockTypeVal;
        Inc(LStartIndex);
      end;
      {Set the start of the next block type}
      LStartIndex := LNextStartIndex;
    end;
  end;
end;

function GetMinimumBlockAlignment: TMinimumBlockAlignment;
begin
  Result := MinimumBlockAlignment;
end;

procedure SetMinimumBlockAlignment(AMinimumBlockAlignment: TMinimumBlockAlignment);
begin
  if AMinimumBlockAlignment <> MinimumBlockAlignment then
  begin
    MinimumBlockAlignment := AMinimumBlockAlignment;
    {Rebuild the size to small block type lookup table}
    BuildBlockTypeLookupTable;
  end;
end;

{Initializes the lookup tables for the memory manager}
procedure InitializeMemoryManager;
var
  i, LMinimumPoolSize, LOptimalPoolSize, LGroupNumber, LBlocksPerPool: Cardinal;
  LPMediumFreeBlock: PMediumFreeBlock;
begin
  {---------------------Set up the small block types----------------------}
  for i := 0 to high(SmallBlockTypes) do
  begin
    {The upsize move procedure may move chunks in 16 bytes even with 8-byte
    alignment, since the new size will always be at least 8 bytes bigger than
    the old size.}
{$ifdef UseCustomFixedSizeMoveRoutines}
    if not Assigned(SmallBlockTypes[i].UpsizeMoveProcedure) then
  {$ifdef UseCustomVariableSizeMoveRoutines}
      SmallBlockTypes[i].UpsizeMoveProcedure := MoveX16L4;
  {$else}
      SmallBlockTypes[i].UpsizeMoveProcedure := Move;
  {$endif}
{$endif}
    {Set the first "available pool" to the block type itself, so that the
     allocation routines know that there are currently no pools with free
     blocks of this size.}
    SmallBlockTypes[i].PreviousPartiallyFreePool := @SmallBlockTypes[i];
    SmallBlockTypes[i].NextPartiallyFreePool := @SmallBlockTypes[i];
    {Cannot sequential feed yet: Ensure that the next address is greater than
     the maximum address}
    SmallBlockTypes[i].MaxSequentialFeedBlockAddress := pointer(0);
    SmallBlockTypes[i].NextSequentialFeedBlockAddress := pointer(1);
    {Get the mask to use for finding a medium block suitable for a block pool}
    LMinimumPoolSize :=
      ((SmallBlockTypes[i].BlockSize * MinimumSmallBlocksPerPool
        + (SmallBlockPoolHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset))
      and -MediumBlockGranularity) + MediumBlockSizeOffset;
    if LMinimumPoolSize < MinimumMediumBlockSize then
      LMinimumPoolSize := MinimumMediumBlockSize;
    {Get the closest group number for the minimum pool size}
    LGroupNumber := (LMinimumPoolSize + (- MinimumMediumBlockSize + MediumBlockBinsPerGroup * MediumBlockGranularity div 2))
      div (MediumBlockBinsPerGroup * MediumBlockGranularity);
    {Too large?}
    if LGroupNumber > 7 then
      LGroupNumber := 7;
    {Set the bitmap}
    SmallBlockTypes[i].AllowedGroupsForBlockPoolBitmap := Byte(Byte(-1) shl LGroupNumber);
    {Set the minimum pool size}
    SmallBlockTypes[i].MinimumBlockPoolSize := MinimumMediumBlockSize + LGroupNumber * (MediumBlockBinsPerGroup * MediumBlockGranularity);
    {Get the optimal block pool size}
    LOptimalPoolSize := ((SmallBlockTypes[i].BlockSize * TargetSmallBlocksPerPool
        + (SmallBlockPoolHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset))
      and -MediumBlockGranularity) + MediumBlockSizeOffset;
    {Limit the optimal pool size to within range}
    if LOptimalPoolSize < OptimalSmallBlockPoolSizeLowerLimit then
      LOptimalPoolSize := OptimalSmallBlockPoolSizeLowerLimit;
    if LOptimalPoolSize > OptimalSmallBlockPoolSizeUpperLimit then
      LOptimalPoolSize := OptimalSmallBlockPoolSizeUpperLimit;
    {How many blocks will fit in the adjusted optimal size?}
    LBlocksPerPool := (LOptimalPoolSize - SmallBlockPoolHeaderSize) div SmallBlockTypes[i].BlockSize;
    {Recalculate the optimal pool size to minimize wastage due to a partial
     last block.}
    SmallBlockTypes[i].OptimalBlockPoolSize :=
      ((LBlocksPerPool * SmallBlockTypes[i].BlockSize + (SmallBlockPoolHeaderSize + MediumBlockGranularity - 1 - MediumBlockSizeOffset))
        and -MediumBlockGranularity) + MediumBlockSizeOffset;
  end;
  {Build the requested size to block type lookup table}
  BuildBlockTypeLookupTable;
  {--------------------------Set up the medium blocks---------------------}
  {There are currently no medium block pools}
  MediumBlockPoolsCircularList.PreviousMediumBlockPoolHeader := @MediumBlockPoolsCircularList;
  MediumBlockPoolsCircularList.NextMediumBlockPoolHeader := @MediumBlockPoolsCircularList;
  {All medium bins are empty}
  for i := 0 to high(MediumBlockBins) do
  begin
    LPMediumFreeBlock := @MediumBlockBins[i];
    LPMediumFreeBlock.PreviousFreeBlock := LPMediumFreeBlock;
    LPMediumFreeBlock.NextFreeBlock := LPMediumFreeBlock;
  end;
  {------------------------Set up the large blocks------------------------}
  LargeBlocksCircularList.PreviousLargeBlockHeader := @LargeBlocksCircularList;
  LargeBlocksCircularList.NextLargeBlockHeader := @LargeBlocksCircularList;
end;

{Frees all allocated memory.}
procedure FreeAllMemory;
var
  LPMediumBlockPoolHeader, LPNextMediumBlockPoolHeader: PMediumBlockPoolHeader;
  LPMediumFreeBlock: PMediumFreeBlock;
  LPLargeBlock, LPNextLargeBlock: PLargeBlockHeader;
  LInd: integer;
begin
  {Free all block pools}
  LPMediumBlockPoolHeader := MediumBlockPoolsCircularList.NextMediumBlockPoolHeader;
  while LPMediumBlockPoolHeader <> @MediumBlockPoolsCircularList do
  begin
    {Get the next medium block pool so long}
    LPNextMediumBlockPoolHeader := LPMediumBlockPoolHeader.NextMediumBlockPoolHeader;
    {Free this pool}
    VirtualFree(LPMediumBlockPoolHeader, 0, MEM_RELEASE);
    {Next pool}
    LPMediumBlockPoolHeader := LPNextMediumBlockPoolHeader;
  end;
  {Clear all small block types}
  for LInd := 0 to high(SmallBlockTypes) do
  begin
    SmallBlockTypes[Lind].PreviousPartiallyFreePool := @SmallBlockTypes[Lind];
    SmallBlockTypes[Lind].NextPartiallyFreePool := @SmallBlockTypes[Lind];
    SmallBlockTypes[Lind].NextSequentialFeedBlockAddress := pointer(1);
    SmallBlockTypes[Lind].MaxSequentialFeedBlockAddress := nil;
  end;
  {Clear all medium block pools}
  MediumBlockPoolsCircularList.PreviousMediumBlockPoolHeader := @MediumBlockPoolsCircularList;
  MediumBlockPoolsCircularList.NextMediumBlockPoolHeader := @MediumBlockPoolsCircularList;
  {All medium bins are empty}
  for LInd := 0 to high(MediumBlockBins) do
  begin
    LPMediumFreeBlock := @MediumBlockBins[LInd];
    LPMediumFreeBlock.PreviousFreeBlock := LPMediumFreeBlock;
    LPMediumFreeBlock.NextFreeBlock := LPMediumFreeBlock;
  end;
  {Free all large blocks}
  LPLargeBlock := LargeBlocksCircularList.NextLargeBlockHeader;
  while LPLargeBlock <> @LargeBlocksCircularList do
  begin
    {Get the next large block}
    LPNextLargeBlock := LPLargeBlock.NextLargeBlockHeader;
    {Free this large block}
    VirtualFree(LPLargeBlock, 0, MEM_RELEASE);
    {Next large block}
    LPLargeBlock := LPNextLargeBlock;
  end;
  {There are no large blocks allocated}
  LargeBlocksCircularList.PreviousLargeBlockHeader := @LargeBlocksCircularList;
  LargeBlocksCircularList.NextLargeBlockHeader := @LargeBlocksCircularList;
end;

procedure FinalizeMemoryManager;
begin
  {Destroy the sharing window if applicable}
  if MMSharingWindow <> 0 then
  begin
    DestroyWindow(MMSharingWindow);
    MMSharingWindow := 0;
  end;
{$ifdef IncludeMemoryLeakTrackingCode}
  {Should memory leaks be reported?}
  if ReportMemoryLeaksOnShutdown then
    ScanForMemoryLeaks;
  {Free the expected memory leaks list}
  if ExpectedMemoryLeaks <> nil then
  begin
    VirtualFree(ExpectedMemoryLeaks, 0, MEM_RELEASE);
    ExpectedMemoryLeaks := nil;
  end;
{$endif}
  {Clean up: Free all memory allocated through this memory manager. If this is
   a library that is frequently loaded and unloaded then it is necessary to
   prevent the process from running out of address space.}
  FreeAllMemory;
end;

