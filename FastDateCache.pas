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
// $Version:0.6.1$ $Revision:1.1$ $Author:masroore$ $RevDate:9/18/2007 14:36:34$
//
////////////////////////////////////////////////////////////////////////////////

{
 * Extremely fast date formatter cache.
 * Computes string representations of dates and caches
 * the results so that subsequent requests within the same
 * minute will be fast.
 *
 * If consecutive calls are frequently very different, then this
 * may be a little slower than a normal DateFormat.
 *
 * The caching and non-caching versions of date formatters were executed
 * 1,000,000 times in a single-threaded app.
 * Results:
 *   HTTPFormatDate      625 msecs
 *   HTTPFormatDateEx    657 msecs
 *   HTTPDate           2359 msecs
 *
 * The same test was done in a multi-threaded app with 50 threads,
 * "HTTPDateCached" performed 4-6 times faster than "HTTPDate"!
 *
 * This unit provides minor performance boost for heavily loaded servers.
 * On the downside, on "idle" servers it may actually degrade
 * performance (note however, that on a less busy server the performance
 * penalty will be insignificant).
}

unit FastDateCache;

interface

{$I NITROHTTPD.inc}

uses
  Windows, SysUtils, FastLock;

{$IFDEF CACHE_HTTP_DATE}
type
  TFastDateCache = class
  private
    FDateFormat: string;
    FLastMinutes, FLastSeconds, FHitWindow: Word;
    FCachedResult: String;
    FLock: TFastLock;
  public
    constructor Create(DateFormat: string);
    destructor Destroy; override;

    function HTTPFormatDate(DateTime: TDateTime): String;
    function HTTPFormatDateEx(DateTime: TDateTime): String;
  end;

function HTTPDateCached(DateTime: TDateTime): String;

{$ENDIF}

function HTTPDate(DateTime: TDateTime): String;

implementation

const
  C_DATESTRLEN     = 29;

var
  g_UTCOffset: TDateTime;

{$IFDEF CACHE_HTTP_DATE}
var
  g_DateCache: TFastDateCache;

{
var
  g_TimeZoneBias: LongInt;

procedure GetTimeZoneBias;
var
  TZ: TTimeZoneInformation;
begin
  if GetTimeZoneInformation(TZ) = TIME_ZONE_ID_DAYLIGHT then
    g_TimeZoneBias := TZ.DaylightBias + TZ.Bias + TZ.StandardBias
  else
    g_TimeZoneBias := TZ.Bias + TZ.StandardBias;
end;

function HTTPDate(DateTime: TDateTime): String;
const
  ShortMonths = 'JanFebMarAprMayJunJulAugSepOctNovDec';
  ShortDay    = 'SunMonTueWedThuFriSat';
var
  Year, Month, Day, WeekDay: Word;
begin
  DateTime := DateTime + g_TimeZoneBias / 1440;

  DecodeDate(DateTime, Year, Month, Day);
  WeekDay := DayOfWeek(DateTime);
  Result  := Copy(ShortDay, (WeekDay - 1) * 3 + 1, 3) +
    FormatDateTime(', dd ', DateTime) + Copy(ShortMonths, (Month - 1) * 3 + 1, 3) +
    FormatDateTime(' yyyy ', DateTime) +
    FormatDateTime('hh:nn:ss', DateTime) + ' GMT';
end;
}

{$ENDIF}

function CalcUTCOffset: TDateTime;
var
  TZBias: Longint;
  TZInfo: TTimeZoneInformation;
begin
  Case GetTimeZoneInformation(TZInfo) of
    TIME_ZONE_ID_UNKNOWN  :
       TZBias := TZInfo.Bias;
    TIME_ZONE_ID_DAYLIGHT :
      TZBias := TZInfo.Bias + TZInfo.DaylightBias;
    TIME_ZONE_ID_STANDARD :
      TZBias := TZInfo.Bias + TZInfo.StandardBias;
  end;

  Result := EncodeTime(Abs(TZBias) div 60, Abs(TZBias) mod 60, 0, 0);

  if TZBias > 0 then
    Result := 0 - Result;
end;

function HTTPDate(DateTime: TDateTime): String;
const
  C_DAYS: array[1..7] of string[3] = ('Sun', 'Mon', 'Tue', 'Wed',
                                   'Thu', 'Fri', 'Sat');
  C_MONTHS: array[1..12] of string[3] = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                                      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
  C_FMTSTR: string = '%s, %2.2d %s %4.4d %2.2d:%2.2d:%2.2d GMT';
var
  DT : TDateTime;
  Dy, Mo, Yr: Word;
  H, M, S, MS: Word;
  {
  StrIndex: Integer;

  procedure ADDS(S: String; Len: Integer; var Result: String; var StrIndex: Integer); inline;
  begin
    Move(S[1], Result[StrIndex], Len);
    Inc(StrIndex, Len);
  end;

  procedure ADDC(C: Char; var Result: String; var StrIndex: Integer);
  begin
    Result[StrIndex] := C;
    Inc(StrIndex);
  end;

  procedure ADDI(I: Integer; Len: Integer; var Result: String; var StrIndex: Integer);
  var
    S: String;
  begin
    //SetLength(S, Len);
    Str(I:Len, S);
    Move(S[1], Result[StrIndex], Len);
    Inc(StrIndex, Len);
  end;
  }
begin
  DT := DateTime - g_UTCOffset;
  DecodeDate(DT, Yr, Mo, Dy);
  DecodeTime(Dt, H, M, S, MS);

  SetLength(Result, C_DATESTRLEN);
  FormatBuf(Pointer(Result)^, C_DATESTRLEN,
            C_FMTSTR[1], Length(C_FMTSTR),
            [C_DAYS[DayOfWeek(DT)],
            Dy, C_MONTHS[Mo], Yr,
            H, M, S]);

  {
  StrIndex := 1;
  ADDS(C_DAYS[DayOfWeek(DT)] + ', ', 5, Result, StrIndex);
  ADDI(Dy, 2, Result, StrIndex);
  ADDC(' ', Result, StrIndex);
  ADDS(C_MONTHS[Mo], 3, Result, StrIndex);
  ADDC(' ', Result, StrIndex);
  ADDI(Yr, 4, Result, StrIndex);
  ADDC(' ', Result, StrIndex);
  ADDI(H, 2, Result, StrIndex);
  ADDC(':', Result, StrIndex);
  ADDI(M, 2, Result, StrIndex);
  ADDC(':', Result, StrIndex);
  ADDI(S, 2, Result, StrIndex);
  ADDS(' GMT', 4, Result, StrIndex);
  }
end;

{$IFDEF CACHE_HTTP_DATE}

function HTTPDateCached(DateTime: TDateTime): String;
begin
  Result := g_DateCache.HTTPFormatDate(DateTime);
end;

{ TFastDateCache }

constructor TFastDateCache.Create(DateFormat: string);
begin
  inherited Create;

  FLock         := TFastLock.Create(0, False);
  FDateFormat   := DateFormat;
  FLastMinutes  := 0;
  FLastSeconds  := 0;
  FHitWindow    := 60 * 60;
  FCachedResult := '';
end;

destructor TFastDateCache.Destroy;
begin
  FreeAndNil(FLock);
  inherited;
end;

function TFastDateCache.HTTPFormatDate(DateTime: TDateTime): String;
var
  H, Minutes, Seconds, MS: Word;
begin
  DecodeTime(DateTime, H, Minutes, Seconds, MS);

  // Check if we are in the same second
  // and don't care about milliseconds
  FLock.Enter;
  if (FLastSeconds = Seconds) then
  begin
    Result := FCachedResult;
  end
  else
  begin
    // Check if we need to re-generate the cached format string
    if (FLastMinutes <> Minutes) then
      FCachedResult := HTTPDate(DateTime);
    FLastMinutes  := Minutes;
    FLastSeconds  := Seconds;
    Result        := FCachedResult;
  end;
  FLock.Leave;
end;

function TFastDateCache.HTTPFormatDateEx(DateTime: TDateTime): String;
var
  H, Minutes, Seconds, MS: Word;
begin
  DecodeTime(DateTime, H, Minutes, Seconds, MS);

  // Is it not suitable to cache?
  if (FLastSeconds > Seconds) OR
     ((FLastSeconds > 0) AND (Seconds > FLastSeconds + FHitWindow))  then
  begin
    Result := HTTPDate(DateTime);
  end
  else
  // Check if we are in the same second
  // and don't care about milliseconds
  if (FLastSeconds = Seconds) then
    Result := FCachedResult
  else
  begin
    // Check if we need a new format string 
    if (FLastMinutes <> Minutes) then
      FCachedResult := HTTPDate(DateTime);

    FLastMinutes  := Minutes;
    FLastSeconds  := Seconds;
    Result        := FCachedResult;
  end;
end;

{$ENDIF}

initialization
  g_UTCOffset := CalcUTCOffset;
{$IFDEF CACHE_HTTP_DATE}  
  g_DateCache := TFastDateCache.Create('');
finalization
  FreeAndNil(g_DateCache);
{$ENDIF}
end.
