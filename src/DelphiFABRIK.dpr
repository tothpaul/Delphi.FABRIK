program DelphiFABRIK;

uses
  System.StartUpCopy,
  FMX.Forms,
  DelphiFABRIK.Main in 'DelphiFABRIK.Main.pas' {Main},
  Execute.FMX.DragCube in 'Execute.FMX.DragCube.pas',
  Execute.FABRIK in 'Execute.FABRIK.pas',
  Execute.FABRIK.FMX in 'Execute.FABRIK.FMX.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMain, Main);
  Application.Run;
end.
