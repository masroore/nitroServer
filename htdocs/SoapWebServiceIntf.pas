[!outputon]
[!if=(Comments, "TRUE")]
{ Invokable interface I[!InterfaceName] }

[!endif]
unit [!IntfUnitName];

interface

uses InvokeRegistry, Types, XSBuiltIns;

type
[!if=(Samples, "TRUE")]

  TEnumTest = (etNone, etAFew, etSome, etAlot);

  TDoubleArray = array of Double;

  TMyEmployee = class(TRemotable)
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
  { Invokable interfaces must derive from IInvokable }
[!endif]
  I[!InterfaceName] = interface(IInvokable)
  ['[!GUIDString]']
[!if=(Comments, "TRUE")]

    { Methods of Invokable interface must not use the default }
    { calling convention; stdcall is recommended }
[!endif]
[!if=(Samples, "TRUE")]
    function echoEnum(const Value: TEnumTest): TEnumTest; stdcall;
    function echoDoubleArray(const Value: TDoubleArray): TDoubleArray; stdcall;
    function echoMyEmployee(const Value: TMyEmployee): TMyEmployee; stdcall;
    function echoDouble(const Value: Double): Double; stdcall;
[!endif]
  end;

implementation

initialization
[!if=(Comments, "TRUE")]
  { Invokable interfaces must be registered }
[!endif]
  InvRegistry.RegisterInterface(TypeInfo(I[!InterfaceName]));

end.
