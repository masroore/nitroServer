[!outputon]
[!if=(Delphi, "TRUE")]
[!if=(Codebehind, "FALSE")]
<%@WebService Language="Delphi" Class="[!Namespace].[!InterfaceName]"%>

[!endif]
unit [!IntfUnitName];

interface

uses System.Web.Services;

type
[!if=(Samples, "TRUE")]

  TEnumTest = (etNone, etAFew, etSome, etAlot);

  TDoubleArray = array of Double;

  TMyEmployee = class
  private
    FLastName: AnsiString;
    FFirstName: AnsiString;
    FSalary: Double;
  published
    property LastName: AnsiString read FLastName write FLastName;
    property FirstName: AnsiString read FFirstName write FFirstName;
    property Salary: Double read FSalary write FSalary;
  end;
[!endif]

[!if=(Comments, "TRUE")]
  { [!InterfaceName] class declaration }
[!endif]
  [!InterfaceName] = class(System.Web.Services.WebService)
[!if=(Comments, "TRUE")]
  { Put method definitions here preceded by each preceded by 
    [WebMethodAttribute] }
[!endif]
[!if=(Samples, "TRUE")]
    [WebMethodAttribute]
    function echoEnum(const Value: TEnumTest): TEnumTest; 
    [WebMethodAttribute]
    function echoDoubleArray(const Value: TDoubleArray): TDoubleArray;
    [WebMethodAttribute]
    function echoMyEmployee(const Value: TMyEmployee): TMyEmployee;
    [WebMethodAttribute]
    function echoDouble(const Value: Double): Double; 
[!endif]
  end;

[!if=(Factory, "TRUE")]
function Get[!InterfaceName]: [!InterfaceName];

var 
  This[!InterfaceName]: [!InterfaceName] := Nil;

[!endif]
implementation

[!if=(Factory, "TRUE")]
function Get[!InterfaceName]: [!InterfaceName];
begin
  if not Assigned(This[!InterfaceName]) then
    This[!InterfaceName] := [!InterfaceName].Create;
end;

var 
  This[!InterfaceName]: [!InterfaceName];

[!endif]
[!if=(Comments, "TRUE")]

  { Put method implementation for class here }
[!endif]
[!if=(Samples, "TRUE")]

function [!InterfaceName].echoEnum(const Value: TEnumTest): TEnumTest; 
begin
[!if=(Comments, "TRUE")]
  { TODO : Implement method echoEnum }
[!endif]
  Result := Value;
end;

function [!InterfaceName].echoDoubleArray(const Value: TDoubleArray): TDoubleArray; 
begin
[!if=(Comments, "TRUE")]
  { TODO : Implement method echoDoubleArray }
[!endif]
  Result := Value;
end;

function [!InterfaceName].echoMyEmployee(const Value: TMyEmployee): TMyEmployee; 
begin
[!if=(Comments, "TRUE")]
  { TODO : Implement method echoMyEmployee }
[!endif]
  Result := Value;
end;

function [!InterfaceName].echoDouble(const Value: Double): Double; 
begin
[!if=(Comments, "TRUE")]
  { TODO : Implement method echoDouble }
[!endif]
  Result := Value;
end;
[!endif]

[!if=(Factory, "TRUE")]
initialization
  This[!InterfaceName] := Get[!InterfaceName];
[!endif]
end.
[!endif]
[!if=(CSharp, "TRUE")]
[!if=(Codebehind, "FALSE")]
<%@WebService Language="C#" Class="[!Namespace].[!InterfaceName]"%>
[!endif]

using System;
using System.Collections;
using System.ComponentModel;
using System.Data;
using System.Diagnostics;
using System.Web;
using System.Web.Services;
using System.Xml.Serialization;

namespace [!Namespace]
{
  /// <summary>
  /// summary description for [!IntfUnitName]
  /// </summary>
  
[!if=(Comments, "TRUE")]
  // [!InterfaceName] class declaration 
[!endif]
  [WebService(Namespace="[!Namespace]", Description="TODO: add description.")]
  public class [!InterfaceName] : System.Web.Services.WebService
  {
[!if=(Comments, "TRUE")]
  // Put method definitions here preceded by each preceded by:
  //   [WebMethod(Description="TODO: add Method Description")] 

[!endif]
[!if=(Samples, "TRUE")]
    [WebMethod(Description="TODO: add Method Description")] 
    public TEnumTest echoEnum(TEnumTest Value)
    {
[!if=(Comments, "TRUE")]
    //   TODO: Implement method here
[!endif]
      return Value;
    }
    [WebMethod(Description="TODO: add Method Description")] 
    public System.Double echoDouble(System.Double Value)
    {
[!if=(Comments, "TRUE")]
    //   TODO: Implement method here
[!endif]
      return Value;
    }
    [WebMethod(Description="TODO: add Method Description")] 
    public System.Double[] echoDoubleArray(System.Double[] Value)
    {
[!if=(Comments, "TRUE")]
    //   TODO: Implement method here
[!endif]
      return Value;
    }
    [WebMethod(Description="TODO: add Method Description")] 
    public TMyEmployee echoMyEmployee(TMyEmployee Value)
    {
[!if=(Comments, "TRUE")]
    //   TODO: Implement method here
[!endif]
      return Value;
    }
[!endif]
  }

[!if=(Samples, "TRUE")]

  [System.Xml.Serialization.XmlTypeAttribute(Namespace="[!NameSpace]")]
  public enum TEnumTest { etNone, etAFew, etSome, etAlot }

  public class TMyEmployee {

    /// <remarks/>
    public System.String LastName;
    public System.String FirstName;
    public System.Double Salary;
  }
[!endif]
}

