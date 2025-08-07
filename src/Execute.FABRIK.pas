unit Execute.FABRIK;

{

  Delphi IK Solver based on FABRIK (c)2025 Execute SARL

  based on
   https://www.youtube.com/watch?v=Ihp6tOCYHug
   https://editor.p5js.org/rjgilmour/sketches/2sbLGqpuZ

}

interface

uses
  System.Math.Vectors;

type
  TSegment = record
    Length: Single;
    StartPoint: TPoint3D;
    EndPoint: TPoint3D;
  end;

  TPartsParent = record
    BodyPart: Integer;
    Segment : Integer;
  end;

  TBodyParts = record
    Parent: TPartsParent;
    Segments: TArray<TSegment>;
    constructor Create(const ADirection: TPoint3D; const ASegments: array of Single; AParent, ASegment: Integer);
    procedure Resolve(Target: TPoint3D);
  end;

  TFABRIK = class
    BodyParts: TArray<TBodyParts>;
    function AddBodyParts(const ADirection: TPoint3D; const ASegments: array of Single; AParent: Integer = -1; ASegment: Integer = -1): Integer;
    function GetBase(BodyPart: Integer): TPoint3D;
  end;

implementation

{ TBodyParts }

constructor TBodyParts.Create(const ADirection: TPoint3D;
  const ASegments: array of Single; AParent, ASegment: Integer);
begin
  Parent.BodyPart := AParent;
  Parent.Segment := ASegment;
  var L := Length(ASegments);
  var P := TPoint3D.Zero;
  SetLength(Segments, L);
  for var I := 0 to L - 1 do
  begin
    Segments[I].Length := ASegments[I];
    Segments[I].StartPoint := P;
    P := P + ADirection * ASegments[I];
    Segments[I].EndPoint := P;
  end;
end;

procedure TBodyParts.Resolve(Target: TPoint3D);
begin
// pass1
  for var I := High(Segments) downto 0 do
  begin
    var V := Segments[I].StartPoint;
    Segments[I].StartPoint := Target;
    Target := Target + (V - Target).Normalize * Segments[I].Length;
  end;
// pass2
  Target := TPoint3D.Zero;
  for var I := 0 to High(Segments) do
  begin
    var V := Segments[I].StartPoint;
    Segments[I].StartPoint := Target;
    Target := Target + (V - Target).Normalize * Segments[I].Length;
    Segments[I].EndPoint := Target;
  end;
end;

{ TFABRIK }

function TFABRIK.AddBodyParts(const ADirection: TPoint3D;
  const ASegments: array of Single; AParent: Integer = -1; ASegment: Integer = -1): Integer;
begin
  Result := Length(BodyParts);
  SetLength(BodyParts, Result + 1);
  BodyParts[Result].Create(ADirection.Normalize, ASegments, AParent, ASegment);
end;

function TFABRIK.GetBase(BodyPart: Integer): TPoint3D;
begin
  var Parent := BodyParts[BodyPart].Parent.BodyPart;
  if Parent < 0 then
    Result := TPoint3D.Zero
  else
    Result := BodyParts[Parent].Segments[BodyParts[BodyPart].Parent.Segment].EndPoint;
end;

end.
