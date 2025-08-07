unit Execute.FABRIK.FMX;

interface

{

  Delphi IK Solver based on FABRIK (c)2025 Execute SARL

  based on
   https://www.youtube.com/watch?v=Ihp6tOCYHug
   https://editor.p5js.org/rjgilmour/sketches/2sbLGqpuZ

}

uses
  System.UITypes,
  System.Math,
  System.Math.Vectors,
  FMX.Types3D,
  FMX.Objects3D,
  FMX.Controls3D,
  FMX.MaterialSources,
  Execute.FMX.DragCube,
  Execute.FABRIK;

type
  TControl3DHelper = class helper for TControl3D
    function LocalPosition: TPoint3D; inline;
    procedure SetMatrix(const M: TMatrix3D);
  end;

  TBodyBone = record
    Bone: TDummy;
    Mesh: TCube;
    Tail: TDummy;
    constructor Create(Parent: TControl3D; const Segment: TSegment; Color: TLightMaterialSource);
    procedure AlignBone(const Direction: TPoint3D);
  end;

  TBodyBones = record
    Bones: TArray<TBodyBone>;
    Color: TLightMaterialSource;
  end;

  TFMX_FABRIK = class(TFABRIK)
  private
    FBase: TControl3D;
    FBones: TArray<TBodyBones>;
    FDrags: TArray<TDragCube>;
    FRoot : TDragCube;
    procedure DragMove(Sender: TObject);
  public
    constructor Create(ABase: TControl3D);
    procedure DrawParts(Context: TContext3D);
    procedure CreateBones;
    procedure SetBoneColor(Index: Integer; Color: TAlphaColor);
    procedure IKResolve(Iterations: Integer);
    procedure AlignBones;
  end;

implementation

{ TControl3DHelper }

function TControl3DHelper.LocalPosition: TPoint3D;
begin
  Result := LocalMatrix.M[3];
end;

procedure TControl3DHelper.SetMatrix(const M: TMatrix3D);
begin
  FLocalMatrix := M;
  RecalcAbsolute;
  RebuildRenderingList;
  Repaint;
end;

{ TBodyBone }

constructor TBodyBone.Create(Parent: TControl3D; const Segment: TSegment; Color: TLightMaterialSource);
begin
  Bone := TDummy.Create(Parent);
  Bone.Parent := Parent;

  Mesh := TCube.Create(Bone);
  Mesh.MaterialSource := Color;
  Mesh.Parent := Bone;
  Mesh.SetSize(0.25, Segment.Length, 0.25);
  Mesh.Position.Y := Segment.Length / 2;

  Tail := TDummy.Create(Mesh);
  Tail.Parent := Mesh;
  Tail.Position.Y := Segment.Length / 2;
end;

procedure TBodyBone.AlignBone(const Direction: TPoint3D);
begin
  var Dir := TControl3D(Bone.Parent).AbsoluteToLocal3D(Direction).Normalize;
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
  Bone.SetMatrix(Q);
end;

{ TFMX_FABRIK }

constructor TFMX_FABRIK.Create(ABase: TControl3D);
begin
  inherited Create;
  FBase := ABase;
end;

procedure TFMX_FABRIK.CreateBones;
begin
  var L := Length(BodyParts);
  SetLength(FBones, L);
  SetLength(FDrags, L);
  var Parent := FBase;
  var Base := FBase.LocalPosition;
  for var I := 0 to L - 1 do
  begin
    if BodyParts[I].Parent.BodyPart < 0 then
      Parent := FBase
    else
      Parent := FBones[BodyParts[I].Parent.BodyPart].Bones[BodyParts[I].Parent.Segment].Tail;

    FBones[I].Color := TLightMaterialSource.Create(FBase);
    var SL := Length(BodyParts[I].Segments);
    SetLength(FBones[I].Bones, SL);
    var V0 := Base + GetBase(I);
    var V: TPoint3D;
    for var S := 0 to SL - 1 do
    begin
      V := V0 + BodyParts[I].Segments[S].EndPoint;
      FBones[I].Bones[S].Create(Parent, BodyParts[I].Segments[S], FBones[I].Color);
      FBones[I].Bones[S].AlignBone(V * FBase.AbsoluteMatrix);
      Parent := FBones[I].Bones[S].Tail;
    end;

    FDrags[I] := TDragCube.Create(FBase);
    FDrags[I].Parent := FBase.Parent;
    FDrags[I].Position.Point := V + (V - V0).Normalize/2;
    FDrags[I].Size := 0.5;
    FDrags[I].Tag := I;
    FDrags[I].OnMove := DragMove;

    FRoot := TDragCube.Create(FBase);
    FRoot.Parent := FBase;
    FRoot.Size := 0.5;
    FRoot.MoveParent := True;
    FRoot.OnMove := DragMove;
  end;
end;

procedure TFMX_FABRIK.SetBoneColor(Index: Integer; Color: TAlphaColor);
begin
  FBones[Index].Color.Diffuse := Color;
end;

procedure TFMX_FABRIK.DrawParts(Context: TContext3D);
begin
  var S := TPoint3D.Create(0.25, 0.25, 0.25);
  var Base := FBase.LocalPosition;
  for var I := 0 to High(BodyParts) do
  begin
    var V0 := Base + GetBase(I);
    var V2 := V0;
    for var J := 0 to High(BodyParts[I].Segments) do
    begin
      var V1 := V2;
      V2 := V0 + BodyParts[I].Segments[J].EndPoint;
      Context.DrawLine(V1, V2, 1, TAlphaColors.Cadetblue);
      Context.DrawCube(V2, S, 1, TalphaColors.Red);
    end;
  end;
end;

procedure TFMX_FABRIK.DragMove(Sender: TObject);
begin
  IKResolve(10);
end;

procedure TFMX_FABRIK.IKResolve(Iterations: Integer);
begin
  for var I := 1 to Iterations do
  begin
    for var P := 0 to High(BodyParts) do
      BodyParts[P].Resolve(FBase.AbsoluteToLocal3D(FDrags[P].AbsolutePosition) - GetBase(P));
  end;
  AlignBones;
end;

procedure TFMX_FABRIK.AlignBones;
begin
  var L := Length(BodyParts);
  for var I := 0 to L - 1 do
  begin
    var V0 := GetBase(I);
    var SL := Length(BodyParts[I].Segments);
    for var S := 0 to SL - 1 do
    begin
      var V := V0 + BodyParts[I].Segments[S].EndPoint;
      FBones[I].Bones[S].AlignBone(V * FBase.AbsoluteMatrix);
    end;
  end;
end;

end.
