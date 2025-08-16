unit IKSpider.Main;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Types3D,
  System.Math.Vectors, FMX.Objects3D, FMX.MaterialSources, FMX.Controls3D,
  FMX.Viewport3D,
  Execute.Spider.FMX, Execute.FMX.DragCube;

type
  TMain = class(TForm)
    Viewport3D1: TViewport3D;
    Dummy2: TDummy;
    RotationY: TDummy;
    Dummy1: TDummy;
    Light1: TLight;
    Light2: TLight;
    LightMaterialSource1: TLightMaterialSource;
    Plane1: TPlane;
    Sphere1: TSphere;
    procedure FormCreate(Sender: TObject);
    procedure Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Single);
    procedure Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Single);
  private
    { Déclarations privées }
    FDownX: Single;
    FRotationY: Single;
    FSpider: TIKSpider;
    procedure GroundLevel(Sender: TObject; var Point: TPoint3D);
  public
    { Déclarations publiques }
  end;

var
  Main: TMain;

implementation

{$R *.fmx}

procedure TMain.FormCreate(Sender: TObject);
begin
  FSpider := TIKSpider.Create(Self);
  FSpider.Parent := Dummy1;
  FSpider.OnGroundLevel := GroundLevel;
end;

procedure TMain.GroundLevel(Sender: TObject; var Point: TPoint3D);
begin
  var A, B: TPoint3D;
  case RayCastSphereIntersect(Point, TPoint3D.Create(0, 1, 0), Sphere1.AbsolutePosition, 10, A, B) of
    1: Point := A;
    2: if A.Y < B.Y then Point := A else Point := B;
  end;
end;

procedure TMain.Viewport3D1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Single);
begin
  FDownX := X;
  FRotationY := RotationY.RotationAngle.Y;
end;

procedure TMain.Viewport3D1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Single);
begin
  if ssLeft in Shift then
  begin
    RotationY.RotationAngle.Y := FRotationY + (FDownX - X) / 10;
  end;
end;

end.
