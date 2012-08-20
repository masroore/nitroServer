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
// $Version:0.6.2$ $Revision:1.4.1.0$ $Author:masroore$ $RevDate:9/30/2007 21:38:14$
//
////////////////////////////////////////////////////////////////////////////////

unit ServerStats;

interface

uses
  Windows, SysUtils;

procedure GetServerStats(var TotalConns,
                             CurrConns,
                             Success,
                             Failure: Integer;
                         var RunningSince: TDateTime);

procedure StatsSuccess;
procedure StatsFailedReq;
procedure StatsIncTotalConn;
procedure StatsIncCurrConn;
procedure StatsDecCurrConn;
procedure StatsStartCounter;
procedure StatsReset;

implementation

var
  g_TotalConns,
  g_CurrConns,
  g_Success,
  g_FailedReq: Integer;
  g_RunningSince: TDateTime;

procedure GetServerStats(var TotalConns,
                             CurrConns,
                             Success,
                             Failure: Integer;
                         var RunningSince: TDateTime);
begin
  TotalConns    := InterlockedExchange(g_TotalConns, g_TotalConns);
  CurrConns     := InterlockedExchange(g_CurrConns, g_CurrConns);
  Success       := InterlockedExchange(g_Success, g_Success);
  Failure       := InterlockedExchange(g_FailedReq, g_FailedReq);
  RunningSince  := g_RunningSince;
end;

procedure StatsSuccess;
begin
  InterlockedIncrement(g_Success);
end;

procedure StatsFailedReq;
begin
  InterlockedIncrement(g_FailedReq);
end;

procedure StatsIncTotalConn;
begin
  InterlockedIncrement(g_TotalConns);
end;

procedure StatsIncCurrConn;
begin
  InterlockedIncrement(g_CurrConns);
  //INFO(0, 'CURR INC ' + IntToStr(InterlockedExchange(g_CurrConns, g_CurrConns)), 2);
end;

procedure StatsDecCurrConn;
begin
  InterlockedDecrement(g_CurrConns);
  //INFO(0, 'CURR DEC ' + IntToStr(InterlockedExchange(g_CurrConns, g_CurrConns)), 2);
end;

procedure StatsStartCounter;
begin
  StatsReset;
  g_RunningSince := Now;
end;

procedure StatsReset;
begin
  InterlockedExchange(g_TotalConns, 0);
  InterlockedExchange(g_CurrConns, 0);
  InterlockedExchange(g_Success, 0);
  InterlockedExchange(g_FailedReq, 0);
end;

end.
