program SensorArray;

uses
  Forms,
  Unit1 in 'Unit1.pas' {Form1},
  SerialPort in 'SerialPort.pas',
  Sensors in 'Sensors.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'Sensor Array';
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.
