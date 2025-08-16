unit Execute.Spider.FMX;

{
  IK Spider for Delphi FMX (c)2025 Execute SARL

  FABRIK (Forward And Backward Reaching Inverse Kinematics) implementation for Delphi

  based on:
   https://www.youtube.com/watch?v=Ihp6tOCYHug
   https://www.youtube.com/watch?v=e6Gjhr1IP6w

}


{.$DEFINE SHOW_SPOT}
{.$DEFINE SHOW_POLE}
{.$DEFINE SHOW_STEPS}
interface

uses
  System.UITypes,
  System.Classes,
  System.Math,
  System.Math.Vectors,
  FMX.Types3D,
  FMX.Controls3D,
  FMX.Objects3D,
  FMX.MaterialSources;

const
  LEG_COUNT = 8; // 2, 4, 6, 8
  LEG_MOD   = LEG_COUNT div 2;
{$IF (LEG_COUNT = 2)}
  STEP      = 0;
  WALK_STEP = 3;
{$ELSE}
  STEP      = 6 / (LEG_MOD - 1); // can't set LEG_COUNT = 2
  WALK_STEP = STEP * 0.9;
{$ENDIF}

  BODY_HEIGHT = 6;

type
  TIKSpider = class;

  TSegment = record
    Bone: TDummy;
    Mesh: TCube;
    Tail: TDummy;
    constructor Create(AParent: TControl3D; ALength: Single; AColor: TLightMaterialSource);
  end;

  TLeg = record
    Hook: TDummy;
    Spot: {$IFDEF SHOW_SPOT}TSphere{$ELSE}TPoint3D{$ENDIF};
  {$IFDEF SHOW_POLE}
    Pole: TSphere;
  {$ENDIF}
    Source: TPoint3D;
    Control: TPoint3D;
    Target: TPoint3D;
    Walking: Boolean;
    Length: Single;
    Segments: array[0..2] of TSegment;
    constructor Create(AIndex: Integer; ASpider: TIKSpider);
    procedure SetStep(ASpider: TIKSpider; Step: Single);
    procedure NextStep(ASpider: TIKSpider; Step: Single);
    function Walk(T: Single): TPoint3D;
  end;

  TGroundLevelEvent = procedure(Sender: TObject; var Position: TPoint3D) of object;

  TIKSpider = class(TDummy)
  private
    FBody: TCube;
    FLegs: array[0..LEG_COUNT - 1] of TLeg;
    FColor: TLightMaterialSource;
    FDrag: Boolean;
    FRayPos: TVector3D;
    FRayDir: TVector3D;
    FPlane: TVector3D;
    FMove: Single;
    FStep: Single;
    FGroundLevel: TGroundLevelEvent;
  {$IFDEF SHOW_STEPS}
    procedure DoRender(Sender: TObject; Context: TContext3D);
  {$ENDIF}
    procedure BodyMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D);
    procedure BodyMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D);
    procedure BodyMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D);
    procedure IKResolve(T: Single);
    procedure GroundLevel(var Target: TPoint3D);
  public
    constructor Create(AOwner: TComponent); override;
    property OnGroundLevel: TGroundLevelEvent read FGroundLevel write FGroundLevel;
  end;

implementation

function AngleTo(const V1, V2: TPoint3D): Single;
begin
  var L := V1.Length * V2.Length;
  if L < 0.001 then
    Result := 0
  else
    Result := ArcCos(V1.DotProduct(V2)/ L);
end;

type
  TControl3DHelper = class helper for TControl3D
    procedure SetMatrix(const M: TMatrix3D);
    procedure AlignDirection(const Direction: TPoint3d);
  end;

procedure TControl3DHelper.SetMatrix(const M: TMatrix3D);
begin
  FLocalMatrix := M;
  RecalcAbsolute;
  RebuildRenderingList;
  Repaint;
end;

procedure TControl3DHelper.AlignDirection(const Direction: TPoint3d);
begin
  var Dir := TControl3D(Parent).AbsoluteToLocal3D(Direction).Normalize;
  var u := TPoint3D.Create(0, 1, 0);
  var w := u.CrossProduct(Dir);
  var d := u.DotProduct(Dir);
  var Q : TQuaternion3D;
  if w.Length < 0.001 then
  begin
    if d < 0 then
      Q := TQuaternion3D.Create(0, 0, PI)
    else
      Q := TQuaternion3D.Identity;
  end else begin
    Q := TQuaternion3D.Create(w.Normalize, ArcCos(d)).Normalize;
  end;
  SetMatrix(Q);
end;

{ TSegment }

constructor TSegment.Create(AParent: TControl3D; ALength: Single; AColor: TLightMaterialSource);
begin
  Bone := TDummy.Create(AParent);
  Bone.Parent := AParent;
  Bone.RotationAngle.Z := 10;

  Mesh := TCube.Create(Bone);
  Mesh.MaterialSource := AColor;
  Mesh.HitTest := False;
  Mesh.Parent := Bone;
  Mesh.SetSize(1, ALength, 1);
  Mesh.Position.Y := ALength/2;

  Tail := TDummy.Create(Mesh);
  Tail.Parent := Mesh;
  Tail.Position.Y := ALength/2;
end;

{ TLeg }

constructor TLeg.Create(AIndex: Integer; ASpider: TIKSpider);
begin
  var A := PI/2 - (1/3*PI)/2 + (AIndex mod LEG_MOD) * (1/3*PI / (LEG_MOD - 1));
  if AIndex >= LEG_MOD then
    A := A + PI;
  var C, S: Single;
  SinCos(A, S, C);
  var X := 7 * S;
  var Z := 7 * C;
{$IFDEF SHOW_SPOT}
  Spot := TSphere.Create(ASpider);
  Spot.Parent := ASpider.FBody;
  Spot.Position.X := X;
  Spot.Position.Y := +BODY_HEIGHT;
  Spot.Position.Z := Z;
  Spot.HitTest := False;
{$ELSE}
  Spot.X := X;
  Spot.Y := 0;
  Spot.Z := Z;
{$ENDIF}
{$IFDEF SHOW_POLE}
  Pole := TSphere.Create(ASpider);
  Pole.Parent := ASpider.FBody;
  Pole.Position.X := 7 * S;
  Pole.Position.Y := -2;
  Pole.Position.Z := 7 * C;
  Pole.HitTest := False;
{$ENDIF}
  Hook := TDummy.Create(ASpider);
  Hook.Parent := ASpider.FBody;
  Hook.Position.X := 3 * S;
  Hook.Position.Y := 3/2;
  Hook.Position.Z := 3 * C;
  if AIndex < LEG_MOD then
    Hook.RotationAngle.Y := 180;
  Hook.RotationAngle.Z := -40;
  var Parent := Hook;
  var L := 3;
  for var I := 0 to High(Segments) do
  begin
    Segments[I].Create(Parent, L, ASpider.FColor);
    Length := Length + Segments[I].Mesh.Height;
    Parent := Segments[I].Tail;
  end;

  Source := {$IFDEF SHOW_SPOT}ASpider.AbsoluteToLocal3D(Spot.AbsolutePosition){$ELSE}Spot{$ENDIF};
  Walking := Odd(AIndex mod LEG_MOD) xor (Odd(LEG_MOD) and (AIndex >= LEG_MOD));

  if Walking then
    Source.Z := Source.Z + WALK_STEP
  else
    Source.Z := Source.Z - WALK_STEP;
  SetStep(ASpider, WALK_STEP);
  Source := {$IFDEF SHOW_SPOT}ASpider.AbsoluteToLocal3D(Spot.AbsolutePosition){$ELSE}Spot{$ENDIF};
  if not Walking then
    Target := Source;
  Control := (Source + Target) / 2 + TPoint3D.Create(0, -2, 0);
end;

procedure TLeg.SetStep(ASpider: TIKSpider; Step: Single);
begin
  ASpider.GroundLevel(Source);
  Target := Source;
  if Walking then
  begin
    Target.Z := Target.Z - 2 * Step;
    ASpider.GroundLevel(Target);
    Control := (Source + Target) / 2 + TPoint3D.Create(0, -2, 0);
  end;
end;

procedure TLeg.NextStep(ASpider: TIKSpider; Step: Single);
begin
  if Step < 0 then
  begin
    if not Walking then
      Source.Z := Source.Z - 2 * Step;
    Step := -Step;
  end else begin
    Source := Target;
  end;
  Walking := not Walking;
  SetStep(ASpider, Step);
end;

function TLeg.Walk(T: Single): TPoint3D;
begin
  if Walking then
  begin
    if T < 0 then
      T := 1 - T;
    var u := 1 - T;
    var uu := u * u;
    var tt := T * T;

    Result := (Source * uu) +
              (Control * (2 * u * T)) +
              (Target * tt);
  end else begin
    Result := Source; // static leg
  end;
end;

{ TIKSpider }

constructor TIKSpider.Create(AOwner: TComponent);
begin
  inherited;
  FColor := TLightMaterialSource.Create(Self);
  FColor.Diffuse := TAlphaColors.Gray;
  FBody := TCube.Create(Self);
  FBody.Parent := Self;
  FBody.SetSize(5, 3, 6);
  FBody.Position.Y := -BODY_HEIGHT;
  FBody.MaterialSource := FColor;
  FBody.AutoCapture := True;
  FBody.OnMouseDown := BodyMouseDown;
  FBody.OnMouseMove := BodyMouseMove;
  FBody.OnMouseUp := BodyMouseUp;
  FPlane.X := 1;

  for var I := 0 to High(FLegs) do
  begin
    FLegs[I].Create(I, Self);
  end;
  FStep := WALK_STEP / 2;
  IKResolve(0);
  IKResolve(0); // fix leg orientation
{$IFDEF SHOW_STEPS}
  OnRender := DoRender; // debug purpose
{$ENDIF}
end;

procedure TIKSpider.BodyMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D);
begin
  FDrag := True;
  FRayPos := FBody.LocalToAbsoluteVector(RayPos);
  FRayDir := FBody.LocalToAbsoluteDirection(RayDir);
end;

procedure TIKSpider.BodyMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single; RayPos, RayDir: TVector3D);
var
  P, I1, I2: TPoint3D;
begin
  if FDrag then
  begin
    RayPos := FBody.LocalToAbsoluteVector(RayPos);
    RayDir := FBody.LocalToAbsoluteDirection(RayDir);
    P := LocalToAbsoluteVector(FPlane);
    if not RayCastPlaneIntersect(FRayPos, FRayDir, AbsolutePosition, P, I1) then
      Exit;
    if not RayCastPlaneIntersect(RayPos, RayDir, AbsolutePosition, P, I2) then
      Exit;
    I1 := AbsoluteToLocalVector(I1);
    I2 := AbsoluteToLocalVector(I2);
    FRayPos := RayPos;
    FRayDir := RayDir;
    I1.Y := I2.Y;
    P := I2 - I1;
    FBody.Position.Point :=  FBody.Position.Point + P;
    FMove := FMove - P.Z;
  // FStep = WALK_STEP / 2 for the initial position
    var T := FMove/FStep;
    while T > 1 do
    begin
      for var I := 0 to High(FLegs) do
        FLegs[I].NextStep(Self, +WALK_STEP);  // if the first step is forward, the next one is at full size
      FMove := FMove - FStep;
      FStep := WALK_STEP;   // then full size always
      T := FMove/FStep;
    end;
    while T < 0 do
    begin
      for var I := 0 to High(FLegs) do
          FLegs[I].NextStep(Self, -FStep);     // if the first step if backword, it is only half of the step
      FMove := FMove + FStep;
      FStep := WALK_STEP;
      T := FMove/FStep;   // then full size always
    end;
    IKResolve(T);
    var G := TPoint3D.Zero;
    for var I := 0 to High(FLegs) do
    begin
      G := G + FLegs[I].Segments[2].Tail.AbsolutePosition;
    end;
    G := G / Length(FLegs);
    FBody.Position.Point := AbsoluteToLocal3D(G) + TPoint3D.Create(0, - BODY_HEIGHT, 0);
//    IKResolve(T);
  end;
end;


procedure TIKSpider.BodyMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D);
begin
  FDrag := False;
end;


procedure TIKSpider.IKResolve(T: Single);
type
  TBoneInfo = record
    StartPoint: TPoint3D;
    EndPoint: TPoint3D;
    Length: Single;
  end;
var
  Points: array[0..2] of TBoneInfo;
begin
  for var L := 0 to High(FLegs) do
  begin
    for var S := 0 to High(FLegs[L].Segments) do
    begin
      Points[S].StartPoint := FLegs[L].Segments[S].Bone.AbsolutePosition;
      Points[S].EndPoint := FLegs[L].Segments[S].Tail.AbsolutePosition;
      Points[S].Length := FLegs[L].Segments[S].Mesh.Height;
    end;

    var Target := LocalToAbsolute3D(FLegs[L].Walk(T));

//    for var Iter := 0 to 1 do
    begin
    // forward
      var Start := Points[0].StartPoint;
      var Stop := Target;
      for var I := High(Points) downto 0 do
      begin
        var V := Points[I].StartPoint;
        Points[I].StartPoint := Stop;
        Stop := Stop + (V - Stop).Normalize * Points[I].Length;
        Points[I].EndPoint := Stop;
      end;

    // backward
      for var I := 0 to High(Points) do
      begin
        var V := Points[I].StartPoint;
        Points[I].StartPoint := Start;
        Start := Start + (V - Start).Normalize * Points[I].Length;
        Points[I].EndPoint := Start;
      end;
    end;

    // fix segments orientations with Pole constraints
  {$IFDEF SHOW_POLE}
    var Pole := TPoint3D(FLegs[L].Pole.AbsolutePosition);
  {$ELSE}
    var Pole :=  FLegs[L].Spot;
    Pole.Y := -2;
    Pole := FBody.LocalToAbsolute3D(Pole);
  {$ENDIF}
    for var I := 1 downto 0 do
    begin
      var M := (Points[I].StartPoint + Points[I + 1].EndPoint)/2;
      var D := M.Distance(Points[I].EndPoint);
      var Axe := (Points[I].StartPoint - Points[I + 1].EndPoint).CrossProduct(Pole - Points[I + 1].EndPoint);
      var Angle := AngleTo(Points[I].StartPoint - M, Points[I].EndPoint - M);
      var Q := TMatrix3D(TQuaternion3D.Create(Axe, Angle));
      Points[I].EndPoint := M + ((Points[I].StartPoint - M).Normalize * D) * Q;
      Points[I + 1].StartPoint := Points[I].EndPoint;
    end;

    for var S := 0 to High(FLegs[L].Segments) do
    begin
      FLegs[L].Segments[S].Bone.AlignDirection(Points[S].EndPoint);
    end;

  end;
end;

{$IFDEF SHOW_STEPS}
procedure TIKSpider.DoRender(Sender: TObject; Context: TContext3D);
var
  A, B: TPoint3D;
begin
// Show walking steps
  for var L := 0 to High(FLegs) do
  begin
     B := FLegs[L].Source;
     for var I := 0 to 100 do
     begin
       A := B;
       B := FLegs[L].Walk(I / 100);
       Context.DrawLine(A, B, 1, TAlphaColors.Red);
     end;
  end;
// Show initial positions
  var R := 8;
  B := TPoint3D.Create(0, 0, R);
  var C, S: Single;
  for var I := 0 to 100 do
  begin
    SinCos(I * 2*PI / 100, S, C);
    A := B;
    B := TPoint3D.Create(R * S, 0, R * C);
    Context.DrawLine(A, B, 1, TAlphaColors.Blueviolet);
  end;

  for var I := 0 to LEG_COUNT - 1 do
  begin
    var T := PI/2 - (1/3*PI)/2 + (I mod LEG_MOD) * (1/3*PI / (LEG_MOD - 1));
    if I >= LEG_MOD then
      T := T + PI;
    SinCos(T, S, C);
    A := TPoint3D.Create(R * S, 0,  R * C);
    Context.DrawLine(TPoint3D.Zero, A, 1, TAlphaColors.Darkgreen);
  end;
end;
{$ENDIF}

procedure TIKSpider.GroundLevel(var Target: TPoint3D);
begin
  Target.Y := 0;
  if Assigned(FGroundLevel) then
  begin
    Target := LocalToAbsolute3D(Target);
    FGroundLevel(Self, Target);
    Target := AbsoluteToLocal3D(Target);
  end;
end;

end.
