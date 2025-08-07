unit DelphiFABRIK.Main;
{

  Delphi IK Solver based on FABRIK (c)2025 Execute SARL

  based on
   https://www.youtube.com/watch?v=Ihp6tOCYHug
   https://editor.p5js.org/rjgilmour/sketches/2sbLGqpuZ

}
interface

uses
  System.SysUtils,
  System.Types,
  System.UITypes,
  System.Classes,
  System.Variants,
  System.Math,
  System.Math.Vectors,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Types3D, FMX.MaterialSources, FMX.Controls3D,
  FMX.Objects3D, FMX.Viewport3D, FMX.Ani,
  Execute.FMX.DragCube,
  Execute.FABRIK,
  Execute.FABRIK.FMX;


type
  TMain = class(TForm)
    Viewport3D1: TViewport3D;
    RotationY: TDummy;
    RotationX: TDummy;
    Light1: TLight;
    LightMaterialSource1: TLightMaterialSource;
    RootNode: TDummy;
    Dummy1: TDummy;
    BodyRoot: TDummy;
    Bone1: TDummy;
    Mesh1: TCube;
    Tail1: TDummy;
    LightMaterialSource2: TLightMaterialSource;
    LightMaterialSource3: TLightMaterialSource;
    Bone2: TDummy;
    Mesh2: TCube;
    Tail2: TDummy;
    FloatAnimation1: TFloatAnimation;
    Bone3: TDummy;
    Mesh3: TCube;
    Tail3: TDummy;
    procedure Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
    procedure FormCreate(Sender: TObject);
    procedure RootNodeRender(Sender: TObject; Context: TContext3D);
    procedure Bone1Render(Sender: TObject; Context: TContext3D);
    procedure Bone2Render(Sender: TObject; Context: TContext3D);
    procedure FloatAnimation1Process(Sender: TObject);
    procedure Bone3Render(Sender: TObject; Context: TContext3D);
  private
    { Déclarations privées }
    FRotationX, FRotationY: Single;
    FDownX, FDownY: Single;
    FRoot: TPoint3D;
    FFABRIK: TFMX_FABRIK;
    FDragBone1: TDragCube;
    FDragBone2: TDragCube;
    FDragBone3: TDragCube;
    procedure MoveBone(Sender: TObject);
  public
    { Déclarations publiques }
  end;

var
  Main: TMain;

implementation

{$R *.fmx}

type
  TControl3DHelper = class helper for TControl3D
    procedure SetMatrix(const M: TMatrix3D);
  end;

  TPoint3DHelper = record helper for TPoint3D
    function AngleARound(const V, Axis: TPoint3D): Single;
    function AngleTo(const V: TPoint3D): Single;
  end;

procedure TControl3DHelper.SetMatrix(const M: TMatrix3D);
begin
  FLocalMatrix := M;
  RecalcAbsolute;
  RebuildRenderingList;
  Repaint;
end;

function TPoint3DHelper.AngleARound(const V, Axis: TPoint3D): Single;
begin
  Result := AngleTo(V);
  if Axis.DotProduct(CrossProduct(V)) < 0 then
    Result := -Result;
end;

function TPoint3DHelper.AngleTo(const V: TPoint3D): Single;
begin
  var L := Length * V.Length;
  if L < 0.001 then
    Result := 0
  else
    Result := ArcCos(DotProduct(V)/L);
end;

procedure RotateBone(Bone: TDummy; const Target: TPoint3D);
begin
  var Dir := Target.Normalize;
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

procedure RotateBoneAbsolute(Bone: TDummy; const Target: TPoint3D);
begin
  RotateBone(Bone, TControl3D(Bone.Parent).AbsoluteToLocal3D(Target));
end;

{ TMain }


procedure TMain.FormCreate(Sender: TObject);
const
  BodyScale = 1/50;
begin
  FFABRIK := TFMX_FABRIK.Create(BodyRoot);
  FFABRIK.AddBodyParts(TPoint3D.Create(0, -1, 0), [BodyScale * 50, BodyScale * 75, BodyScale * 40]);
  FFABRIK.AddBodyParts(TPoint3D.Create(-1, 0, 0), [BodyScale * 60, BodyScale * 65], 0, 1);
  FFABRIK.AddBodyParts(TPoint3D.Create(+1, 0, 0), [BodyScale * 60, BodyScale * 65], 0, 1);
  FFABRIK.AddBodyParts(TPoint3D.Create(+1, +1, 0), [BodyScale * 85, BodyScale * 85]);
  FFABRIK.AddBodyParts(TPoint3D.Create(-1, +1, 0), [BodyScale * 85, BodyScale * 85]);
  FFABRIK.CreateBones;
  FFABRIK.SetBoneColor(0, TAlphaColors.Cadetblue);
  FFABRIK.SetBoneColor(1, TAlphaColors.Blueviolet);
  FFABRIK.SetBoneColor(2, TAlphaColors.Brown);
  FFABRIK.SetBoneColor(3, TAlphaColors.Coral);
  FFABRIK.SetBoneColor(4, TAlphaColors.Darkorange);

  // this is to debug AlignParts :(
  FDragBone1 := TDragCube.Create(Self);
  FDragBone1.Parent := Dummy1;
  FDragBone1.Position.Y := 4;
  FDragBone1.OnMove := MoveBone;

  FDragBone2 := TDragCube.Create(Self);
  FDragBone2.Parent := Dummy1;
  FDragBone2.Position.X := 4;
  FDragBone2.Position.Y := 4;
  FDragBone2.OnMove := MoveBone;

  FDragBone3 := TDragCube.Create(Self);
  FDragBone3.Parent := Dummy1;
  FDragBone3.Position.X := 4;
  FDragBone3.Position.Y := 8;
  FDragBone3.OnMove := MoveBone;
end;

procedure TMain.Bone1Render(Sender: TObject; Context: TContext3D);
begin
  var V1 := TPoint3D.Zero;
  var V2 := Bone1.AbsoluteToLocal3D(FDragBone1.AbsolutePosition);
  Context.DrawLine(V1, V2, 1, TAlphaColors.Blueviolet);
end;

procedure TMain.Bone2Render(Sender: TObject; Context: TContext3D);
begin
  var V1 := TPoint3D.Zero;
  var V2 := Bone2.AbsoluteToLocal3D(FDragBone2.AbsolutePosition);
  Context.DrawLine(V1, V2, 1, TAlphaColors.Darkorchid);
end;

procedure TMain.Bone3Render(Sender: TObject; Context: TContext3D);
begin
  var V1 := TPoint3D.Zero;
  var V2 := Bone3.AbsoluteToLocal3D(FDragBone3.AbsolutePosition);
  Context.DrawLine(V1, V2, 1, TAlphaColors.Darkorchid);
end;

procedure TMain.MoveBone(Sender: TObject);
begin
  RotateBoneAbsolute(Bone1, FDragBone1.AbsolutePosition);
  RotateBoneAbsolute(Bone2, FDragBone2.AbsolutePosition);
  RotateBoneAbsolute(Bone3, FDragBone3.AbsolutePosition);
end;

procedure TMain.RootNodeRender(Sender: TObject; Context: TContext3D);
begin
  FFABRIK.DrawParts(Context);
end;

procedure TMain.FloatAnimation1Process(Sender: TObject);
begin
  if Visible then MoveBone(Self);
end;

procedure TMain.Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FRotationX := RotationX.RotationAngle.X;
  FRotationY := RotationY.RotationAngle.Y;
  FDownX := X;
  FDownY := Y;
end;

procedure TMain.Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
  if ssLeft in Shift then
  begin
    RotationX.RotationAngle.X := FRotationX - (FDownY - Y) / 10;
    RotationY.RotationAngle.Y := FRotationY + (FDownX - X) / 10;
  end;
end;


end.
