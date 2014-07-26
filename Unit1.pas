unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs, Registry,
  StdCtrls, ComCtrls, Sensors, ExtCtrls, TeeProcs, TeEngine, Chart,
  Buttons, Series, Math;

type
  TForm1 = class(TForm)
    SettingsBox: TGroupBox;
    comlist: TComboBox;
    comlist_refresh: TButton;
    baudlist: TComboBox;
    connect: TButton;
    DebugBox: TGroupBox;
    debug: TMemo;
    sensorlistbox: TGroupBox;
    getsensorlist: TButton;
    sensortree: TTreeView;
    sensorchart: TChart;
    Series1: TFastLineSeries;
    Timer1: TTimer;
    SpeedButton1: TSpeedButton;
    s_no: TEdit;
    m_no: TEdit;
    Series2: TFastLineSeries;
    Series3: TFastLineSeries;
    Series4: TFastLineSeries;
    colorpanel: TPanel;
    procedure comlist_refreshClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure connectClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure getsensorlistClick(Sender: TObject);
    procedure Timer1Timer(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
    procedure sensortreeClick(Sender: TObject);
    procedure sensortreeKeyPress(Sender: TObject; var Key: Char);
  private
    { Private declarations }
  public
    { Public declarations }

    procedure add_chart(s : integer; v : TValue);

    function getFloat(v : TValue) : single;
    function getInteger(v : TValue) : integer;

    procedure setColor(v : TValueVector);
  end;

var
  Form1: TForm1;
  SensorArray : TSensors;
  start_time : Cardinal;

implementation

{$R *.DFM}

procedure TForm1.comlist_refreshClick(Sender: TObject);
var
    reg: TRegistry;
    st: Tstrings;
    i: Integer;
    devicepath : string;
    devicename : string;
    portnumber : integer;
begin
    comlist.Clear;
    comlist.Text := 'Choose Port';
    reg := TRegistry.Create;
    try
        reg.RootKey := HKEY_LOCAL_MACHINE;
        reg.OpenKey('hardware\devicemap\serialcomm', False);
        st := TstringList.Create;
        try
            reg.GetValueNames(st);
            for i := 0 to st.Count - 1 do
            begin
                devicepath := reg.Readstring(st.strings[i]);
                devicename := Copy(st.strings[i], 9, length(st.strings[i]) - 9);

                portnumber := strtoint(Copy(devicepath, 4, length(devicepath) - 3));

                comlist.items.AddObject(devicepath + ' (' + devicename  + ')', TObject(portnumber));
                
            end;
        finally
            st.Free;
        end;
        reg.CloseKey;
    finally
        reg.Free;
    end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
    SensorArray := TSensors.Create();
    SensorArray.TreeView := sensortree;
    comlist_refreshClick(self);
    baudlist.ItemIndex := 10;
end;

procedure TForm1.connectClick(Sender: TObject);
var
    port, baud : integer;
begin
    if assigned(SensorArray) then begin
        if SensorArray.connected then
        begin
            SensorArray.Disconnect();
            connect.Caption := 'Open';
        end else
        begin
            port := comlist.ItemIndex;
            baud := baudlist.ItemIndex;

            if (port > -1) AND (baud > -1) then
            begin
                form1.Cursor := crHourGlass;
                SensorArray.Connect(integer(comlist.Items.Objects[port]), strtoint(baudlist.items.strings[baud]));
                form1.Cursor := crDefault;
                connect.Caption := 'Close';
            end;
        end;
    end;
end;

procedure TForm1.FormClose(Sender: TObject; var Action: TCloseAction);
begin
    SensorArray.Destroy;
end;

procedure TForm1.getsensorlistClick(Sender: TObject);
begin
    SensorArray.Initialize();
end;

procedure TForm1.Timer1Timer(Sender: TObject);
var
    v : TValueVector;
    i : integer;

    l : TValue;
begin
    if SensorArray.Connected then
    begin
        timer1.enabled := false;
        SensorArray.value(strtoint(s_no.text), strtoint(m_no.text), v);

        for i := 0 to length(v) - 1 do
        begin
            add_chart(i, v[i]);
        end;

        // Vektor
        if length(v) = 3 then
        begin
            l.typ := TYPE_FLOAT;

            case (v[0].typ) of
            TYPE_FLOAT :
                    l.f := sqrt(power(v[0].f, 2) + power(v[1].f, 2) + power(v[2].f, 2));

            TYPE_UINT8,
            TYPE_UINT16,
            TYPE_UINT32:
                begin
                    l.f := sqrt(power(v[0].u, 2) + power(v[1].u, 2) + power(v[2].u, 2));
                    setColor(v);
                end;

            TYPE_INT8,
            TYPE_INT16,
            TYPE_INT32:
                    l.f := sqrt(power(v[0].i, 2) + power(v[1].i, 2) + power(v[2].i, 2));

            end;

            add_chart(3, l);
        end;

        timer1.enabled := true;
    end;
end;

procedure TForm1.SpeedButton1Click(Sender: TObject);
var
    v : TValue;
begin
    if timer1.Enabled then
    begin
        timer1.Enabled := false;
        SpeedButton1.Down := false;
        SpeedButton1.Caption := 'Capture';
    end else
    begin
        sensorchart.Series[0].Clear;
        sensorchart.Series[1].Clear;
        sensorchart.Series[2].Clear;
        sensorchart.Series[3].Clear;
        timer1.Enabled := true;
        SpeedButton1.Down := true;
        SpeedButton1.Caption := 'Stop';
        start_time := GetTickCount();
    end;
end;

procedure TForm1.sensortreeClick(Sender: TObject);
var
    s, m, r : integer;
begin
    SensorArray.selected(s, m, r);

    if (s > -1) AND (m > -1) then
    begin
        if (r = -1) then
        begin
            debug.lines.add(SensorArray.valueFormat(s, m));

            sensorchart.title.text.Clear;
            sensorchart.Title.Text.Add(SensorArray.Sensors[s].name + ' (' + SensorArray.Sensors[s].measurements[m].name + ')');
            sensorchart.LeftAxis.Title.Caption := SensorArray.Sensors[s].measurements[m].name + ' [' + PrefixSymbols[integer(SensorArray.Sensors[s].measurements[m].units.prefix)] + SensorArray.Sensors[s].measurements[m].units.symbol + ']';

            r := SensorArray.Sensors[s].measurements[m].range;

            sensorchart.LeftAxis.Maximum := getFloat(SensorArray.Sensors[s].measurements[m].ranges[r].max);
            sensorchart.LeftAxis.Minimum := getFloat(SensorArray.Sensors[s].measurements[m].ranges[r].min);

            s_no.text := inttostr(s);
            m_no.text := inttostr(m);
        end else
        begin
            SensorArray.set_range(s, m, r);
        end;
    end;
end;

procedure TForm1.sensortreeKeyPress(Sender: TObject; var Key: Char);
var
    s, m, r : integer;
begin
    if (key = #13) then
    begin
        SensorArray.selected(s, m, r);

        if (s > -1) AND (m > -1) AND (r = -1) then
            debug.lines.add(SensorArray.valueFormat(s, m));
    end;
end;

procedure TForm1.add_chart(s : integer; v: TValue);
var
    sample_time : Cardinal;
begin
        sample_time := GetTickCount();

        case (v.typ) of
        TYPE_FLOAT :
            sensorchart.Series[s].AddXY((sample_time-start_time) / 1000, v.f);

        TYPE_UINT8,
        TYPE_UINT16,
        TYPE_UINT32:
             sensorchart.Series[s].AddXY((sample_time-start_time) / 1000, v.u);

        TYPE_INT8,
        TYPE_INT16,
        TYPE_INT32:
            sensorchart.Series[s].AddXY((sample_time-start_time) / 1000, v.i);
        end;
end;

function TForm1.getFloat(v: TValue): single;
begin
    case (v.typ) of
        TYPE_FLOAT :
            Result := v.f;

        TYPE_UINT8,
        TYPE_UINT16,
        TYPE_UINT32:
            Result := v.u;

        TYPE_INT8,
        TYPE_INT16,
        TYPE_INT32:
            Result := v.i;
    end;
end;

function TForm1.getInteger(v: TValue): integer;
begin
    case (v.typ) of
        TYPE_FLOAT :
            Result := round(v.f);

        TYPE_UINT8,
        TYPE_UINT16,
        TYPE_UINT32:
            Result := v.u;

        TYPE_INT8,
        TYPE_INT16,
        TYPE_INT32:
            Result := v.i;
    end;
end;

procedure TForm1.setColor(v: TValueVector);
var
    s, r, g, b: integer;
begin
    r := v[0].u;
    g := v[1].u;
    b := v[2].u;

    s := r + g + b;

    r := floor($FF / s * r);
    g := floor($FF / s * g);
    b := floor($FF / s * b);

    debug.lines.add('S : ' + inttostr(s) +
                    ' R : ' + inttostr(r) +
                    ' G : ' + inttostr(g) +
                    ' B : ' + inttostr(b));

    colorpanel.color := RGB(r,g,b);
end;

end.
