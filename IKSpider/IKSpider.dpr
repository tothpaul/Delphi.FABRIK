program IKSpider;

uses
  System.StartUpCopy,
  FMX.Forms,
  IKSpider.Main in 'IKSpider.Main.pas' {Main},
  Execute.Spider.FMX in 'Execute.Spider.FMX.pas',
  Execute.FMX.DragCube in '..\src\Execute.FMX.DragCube.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
