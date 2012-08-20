unit FastList;

interface

const
  MaxListSize = MaxInt div 16;

type
  TPointerArray = array[0..MaxListSize - 1] of Pointer;
  PPointerArray = ^TPointerArray;

  TFastList = class(TObject)
  private
    FCapacity: Integer;
    FCount: Integer;
    FList: PPointerArray;
  protected
    function GetItem(const AIndex: integer): Pointer;
    procedure Grow;
    procedure SetCapacity(const ACapacity: Integer);
    procedure SetItem(const AIndex: integer; const Aitem: Pointer);
  public
    destructor Destroy; override;
    function Add(const AItem: pointer): Integer;
    procedure Clear;
    procedure Delete(const AIndex: integer);
    function IndexOf(const AItem: pointer): Integer;
    procedure Insert(const AIndex: integer; const AItem: pointer);
    procedure Pack;
    property Capacity: Integer read FCapacity write SetCapacity;
    property Count: Integer read FCount;
    property Items[const AIndex: integer]: Pointer read GetItem write SetItem;
    default;
    property List: PPointerArray read FList;
  end;

implementation

{
********************************** TFastList ***********************************
}

destructor TFastList.Destroy;
begin
  Clear;
end;

function TFastList.Add(const AItem: pointer): Integer;
begin
  Result := FCount;
  if Result = FCapacity then
    Grow;
  FList^[Result] := AItem;
  inc(FCount);
end;

procedure TFastList.Clear;
begin
  SetCapacity(0);
  FCount := 0;
end;

procedure TFastList.Delete(const AIndex: integer);
begin
  dec(FCount);
  if AIndex < FCount then
    Move(FList^[AIndex + 1], FList^[AIndex], (FCount - AIndex) *
      sizeof(pointer));
end;

function TFastList.GetItem(const AIndex: integer): Pointer;
begin
  Result := FList^[AIndex];
end;

procedure TFastList.Grow;
var
  Delta: Integer;
begin
  if FCapacity > 64 then
    Delta := FCapacity div 4
  else if FCapacity > 8 then
    Delta := 16
  else
    Delta := 4;
  SetCapacity(FCapacity + Delta);
end;

function TFastList.IndexOf(const AItem: pointer): Integer;
begin
  Result := 0;
  while (Result < FCount) and (FList^[Result] <> AItem) do
    Inc(Result);
  if Result = FCount then
    Result := -1;
end;

procedure TFastList.Insert(const AIndex: integer; const AItem: pointer);
begin
  if FCount = FCapacity then
    Grow;
  if AIndex < FCount then
    Move(FList^[AIndex], FList^[AIndex + 1], (FCount - AIndex) *
      sizeof(pointer));
  FList^[AIndex] := AItem;
  inc(FCount);
end;

procedure TFastList.Pack;
var
  i, j: Integer;
begin
  j := 0;
  for i := 0 to FCount - 1 do
  begin
    if FList^[i] <> nil then
      inc(j);
    FList^[j] := FList^[i];
  end;
  FCount := j;
end;

procedure TFastList.SetCapacity(const ACapacity: Integer);
begin
  if ACapacity <> FCapacity then
  begin
    ReallocMem(FList, ACapacity * SizeOf(Pointer));
    FCapacity := ACapacity;
  end;
end;

procedure TFastList.SetItem(const AIndex: integer; const Aitem: Pointer);
begin
  FList^[AIndex] := AItem;
end;

end.

