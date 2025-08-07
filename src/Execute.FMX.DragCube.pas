unit Execute.FMX.DragCube;

{

  Draggable 3D Cube for Delphi FMX (c)2025 Execute SARL

}

interface

uses
  System.UITypes,
  System.Classes,
  System.SysUtils,
  System.Math.Vectors,
  FMX.Objects3D,
  FMX.Types3D,
  FMX.Controls3D,
  FMX.MaterialSources;

type
  TDragCube = class(TDummy)
  private
    FOnMove: TNotifyEvent;
    FMoveParent: Boolean;
    FSize: Single;
    FPlanes: array[0..5] of TControl3D;
    procedure DoMove(const Delta: TPoint3D);
    procedure SetSize(Value: Single);
  public
    constructor Create(AOwner: TComponent); override;
    property OnMove: TNotifyEvent read FOnMove write FOnMove;
    property MoveParent: Boolean read FMoveParent write FMoveParent;
    property Size: Single read FSize write SetSize;
  end;

implementation

type
  TMovabledPlane = class(TCube)
  private
    FPlane: TVector3D;
    FActive: Boolean;
    FRayPos: TVector3D;
    FRayDir: TVector3D;
    FColor: TAlphaColor;
  protected
    procedure MouseDown3D(Button: TMouseButton; Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D); override;
    procedure MouseMove3D(Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D); override;
    procedure MouseUp3D(Button: TMouseButton; Shift: TShiftState; X, Y: Single; RayPos, RayDir: TVector3D); override;
    procedure DoMouseEnter; override;
    procedure DoMouseLeave; override;
    procedure SetColor(Color: TAlphaColor);
  public
    constructor Create(AOwner: TComponent); override;
  end;

{ TDragCube }

constructor TDragCube.Create(AOwner: TComponent);
begin
  inherited;
  FPlanes[0] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[0]) do
  begin
    Parent := Self;
    Depth := 0.001;
    Position.Z := -0.5;
    FPlane.Z := +1;
    SetColor(TAlphaColors.Blue);
  end;

  FPlanes[1] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[1]) do
  begin
    Parent := Self;
    Depth := 0.001;
    Position.Z := +0.5;
    FPlane.Z := -1;
    SetColor(TAlphaColors.Blue);
  end;

  FPlanes[2] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[2]) do
  begin
    Parent := Self;
    Width := 0.001;
    Position.X := +0.5;
    FPlane.X := +1;
    SetColor(TAlphaColors.Yellow);
  end;

  FPlanes[3] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[3]) do
  begin
    Parent := Self;
    Width := 0.001;
    Position.X := -0.5;
    FPlane.X := -1;
    SetColor(TAlphaColors.Yellow);
  end;

  FPlanes[4] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[4]) do
  begin
    Parent := Self;
    Height := 0.001;
    Position.Y := -0.5;
    FPlane.Y := -1;
    SetColor(TAlphaColors.Red);
  end;

  FPlanes[5] := TMovabledPlane.Create(Self);
  with TMovabledPlane(FPlanes[5]) do
  begin
    Parent := Self;
    Height := 0.001;
    Position.Y := +0.5;
    FPlane.Y := +1;
    SetColor(TAlphaColors.Red);
  end;
end;

procedure TDragCube.DoMove(const Delta: TPoint3D);
begin
  if FMoveParent and (Parent is TControl3D) then
    TControl3D(Parent).Position.Point := TControl3D(Parent).Position.Point + Delta
  else
    Position.Point := Position.Point + Delta;
  if Assigned(FOnMove) then
    FOnMove(Self);
end;

procedure TDragCube.SetSize(Value: Single);
begin
  FPlanes[0].SetSize(Value, Value, 0.001);
  FPlanes[1].SetSize(Value, Value, 0.001);
  FPlanes[2].SetSize(0.001, Value, Value);
  FPlanes[3].SetSize(0.001, Value, Value);
  FPlanes[4].SetSize(Value, 0.001, Value);
  FPlanes[5].SetSize(Value, 0.001, Value);

  Value := Value / 2;
  FPlanes[0].Position.Z := -Value;
  FPlanes[1].Position.Z := +Value;
  FPlanes[2].Position.X := +Value;
  FPlanes[3].Position.X := -Value;
  FPlanes[4].Position.Y := -Value;
  FPlanes[5].Position.Y := +Value;
end;

{ TMovabledPlane }

constructor TMovabledPlane.Create(AOwner: TComponent);
begin
  inherited;
  AutoCapture := True;
  MaterialSource := TColorMaterialSource.Create(Self);
end;

procedure TMovabledPlane.DoMouseEnter;
begin
  inherited;
  FColor := TColorMaterialSource(MaterialSource).Color;
  SetColor(TAlphaColors.Chartreuse);
  Repaint;
end;

procedure TMovabledPlane.DoMouseLeave;
begin
  inherited;
  SetColor(FColor);
  Repaint;
end;

procedure TMovabledPlane.MouseDown3D(Button: TMouseButton; Shift: TShiftState;
  X, Y: Single; RayPos, RayDir: TVector3D);
begin
  inherited;
  if Button = TMouseButton.mbLeft then
  begin
    FActive := True;
    FRayPos := LocalToAbsoluteVector(RayPos);
    FRayDir := LocalToAbsoluteDirection(RayDir);
  end;
end;

procedure TMovabledPlane.MouseMove3D(Shift: TShiftState; X, Y: Single; RayPos,
  RayDir: TVector3D);
var
  P, I1, I2: TPoint3D;
begin
  inherited;
  if FActive then
  begin
    RayPos := LocalToAbsoluteVector(RayPos);
    RayDir := LocalToAbsoluteDirection(RayDir);
    P := LocalToAbsoluteVector(FPlane);
    if not RayCastPlaneIntersect(FRayPos, FRayDir, AbsolutePosition, P, I1) then
      Exit;
    if not RayCastPlaneIntersect(RayPos, RayDir, AbsolutePosition, P, I2) then
      Exit;
    I1 := TDragCube(Parent).AbsoluteToLocalVector(I1);
    I2 := TDragCube(Parent).AbsoluteToLocalVector(I2);
    FRayPos := RayPos;
    FRayDir := RayDir;
    TDragCube(Parent).DoMove(I2 - I1);
  end;
end;

procedure TMovabledPlane.MouseUp3D(Button: TMouseButton; Shift: TShiftState; X,
  Y: Single; RayPos, RayDir: TVector3D);
begin
  inherited;
  FActive := False;
end;

procedure TMovabledPlane.SetColor(Color: TAlphaColor);
begin
  TColorMaterialSource(MaterialSource).Color := Color;
end;

end.

