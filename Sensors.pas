unit Sensors;

//{$DEFINE DEBUG}
{$UNDEF DEBUG}

interface

uses SerialPort, Windows, SysUtils, Classes, ComCtrls, Math;

type
    TType = (TYPE_FLOAT, TYPE_UINT8, TYPE_UINT16, TYPE_UINT32, TYPE_INT8, TYPE_INT16, TYPE_INT32, TYPE_BOOL, TYPE_RAW);

    TDimension = (NONE, METER, KILOGRAM, SECOND, AMPERE, KELVIN, MOLE, CANDELA, DEGREE);

    TPrefix = (PICO, NANO, MICRO, MILLI, CENTI, DECI, NO_PREFIX, DECA, HECTO, KILO, MEGA, GIGA, TERA);

    TSensorSubUnit = record
        dimension : TDimension;
        exponent  : smallint;
    end;

    TSensorUnit = record
        name : string;
        symbol : string;
        prefix : TPrefix;
        baseunits : array[0..3] of TSensorSubUnit;
    end;

    TValue = record
       typ : TType;
       case TType of
            TYPE_FLOAT : (f : single);
            TYPE_INT8, TYPE_INT16, TYPE_INT32 : (i : integer);
            TYPE_UINT8, TYPE_UINT16, TYPE_UINT32 : (u : cardinal);
            TYPE_RAW : (r : array[0..3] of byte);
    end;

    TAscii85 = array[0..4] of char;

    TValueVector = array of TValue;

    TRange = record
        min : TValue;
        max : TValue;
        digits : smallint;
    end;

    TSensorMeasurement = record
        name        : string;
        units       : TSensorUnit;
        duration    : smallint;
        range       : smallint;
        NoOfRanges  : smallint;
        ranges      : array[0..3] of TRange;
        size        : smallint;
        typ         : TType;
    end;

    TSensor = record
        name : string;
        part : string;
        NoOfMeasurements : smallint;
        Measurements : array of TSensorMeasurement;
    end;

    TActorAction = record
        name  : string;
        units : TSensorUnit;
        range : TRange;
        size  : smallint;
        typ   : TType;
    end;

    TActor = record
        name : string;
        part : string;
        NoOfActions : smallint;
        Actions : array of TActorAction;
    end;

    TSensorArray = array of TSensor;
    TActorArray = array of TActor;

    TSensors = class(TObject)
    private
        fcomport : TSerialPort;
        fSensors : TSensorArray;
        fActors  : TActorArray;

        fNoOfSensors : integer;
        fNoOfActors  : integer;

        fTreeView : TTreeView;
        fConnected : boolean;

        reply : THandle;

        RootNode : TTreeNode;
        SensorNodes : array of TTreeNode;
        MeasurementNodes : array of array of TTreeNode;
        RangeNodes : array of array of TTreeNode;

        tmp_cmd : string;
        tmp_value : TValueVector;

        procedure make_cmd(data : string);
        procedure parse_cmd(command : string);

        function wait_forReply() : boolean;

        procedure refresh_tree();

        procedure get_NoOfSensors();
        procedure get_SensorInfo(sensor : integer);
        procedure get_MeasurementInfo(sensor, measurement : integer);
        procedure get_MeasurementUnitInfo(sensor, measurement : integer);

//        procedure get_NoOfActors();
//        procedure get_ActorInfo(actor : integer);
//        procedure get_ActionInfo(actor, action : integer);
//        procedure get_ActionUnitInfo(actor, action : integer);

        function  explode(text, delimiter : string; var list : TStringList) : integer;
        procedure set_value(var value : TValue; typ : TType; data : string);
        procedure set_units(var units : TSensorUnit; data : string);

        function make_durationstring(measurement : TSensorMeasurement) : string;
        function make_typestring(measurement : TSensorMeasurement) : string;
        function make_rangestring(measurement : TSensorMeasurement; range : smallint) : string;
        function make_unitstring(units : TSensorUnit; full : boolean) : string;

        function encode_ascii85(data : TValue) : TAscii85;
        function decode_ascii85(data : TAscii85) : TValue;

    public
        constructor Create();
        destructor Destroy(); override;

        procedure Connect(port, baud : integer);
        function Initialize() : boolean;

        procedure Disconnect();

        procedure selected(var sensor, measurement, range : integer);

        procedure value(sensor : integer; measurement : integer; var data : TValueVector);
        function valueFormat(sensor : integer; measurement : integer) : string;
        procedure set_range(sensor, measurement, range : integer);

        property NoOfSensors : integer read fNoOfSensors;
        property Sensors     : TSensorArray read fSensors;

        property NoOfActors : integer read fNoOfActors;
        property Actors     : TActorArray read fActors;

        property Connected : boolean read fConnected;
        property TreeView  : TTreeView read fTreeView write fTreeView;

    end;

const
    TypeNames : array[0..8] of string = ('Float', 'UInt8', 'UInt16', 'UInt32', 'Int8', 'Int16', 'Int32', 'Bool', 'Raw');
    DimensionNames : array[0..8] of string = ('', 'Meter', 'Kilogram', 'Second', 'Ampere', 'Kelvin', 'Mole', 'Candela', 'Degree');
    DimensionSymbols : array[0..8] of string = ('1', 'm', 'kg', 's', 'A', 'K', 'mol', 'cd', 'deg');
    PrefixNames : array[0..12] of string = ('pico', 'nano', 'micro', 'milli', 'centi', 'deci', '', 'deca', 'hecto', 'kilo', 'mega', 'giga', 'tera');
    PrefixSymbols : array[0..12] of string = ('p', 'n', 'µ', 'm', 'c', 'd', '', 'da', 'h', 'k', 'M', 'G', 'T');
    PrefixExponents : array[0..12] of integer = (-12, -9, -6, -3, -2, -1, 0, +1, +2, +3, +6, +9, +12); 
    ExponentNames : array[1..4] of string = ('', 'Square', 'Cubic', 'Hypercubic');
    ExponentSymbols : array[1..4] of string = ('', '²', '³', '^4');

    CmdStartChar : char = '{';
    CmdStopChar  : char = '}';
    CmdDelimiter : char = '|';

implementation

uses Unit1;

{ TSensors }

constructor TSensors.Create;
begin
    fcomport := TSerialPort.Create();
    fConnected := false;

    fcomport.OnReceive := make_cmd;
    tmp_cmd := '';

    fNoOfSensors := 0;
    SetLength(fSensors, 0);

    fNoOfActors := 0;
    SetLength(fActors, 0);

    reply := CreateEvent(nil, True, False, nil);
end;

destructor TSensors.Destroy;
begin
    fcomport.terminate;

    if reply <> 0 then
        CloseHandle(reply);
end;

procedure TSensors.Connect(port, baud: integer);
begin
    fConnected := fcomport.open(port, baud, 8, NOPARITY, ONESTOPBIT);

    if assigned(fTreeView) AND fConnected then
    begin
        fTreeView.Enabled := true;
        refresh_tree();
    end else
        fTreeView.Enabled := false;
end;

procedure TSensors.Disconnect;
begin
    fcomport.close();
    fConnected := false;
    
    if assigned(fTreeView) then
        fTreeView.Enabled := false;
end;

procedure TSensors.make_cmd(data: string);
var
    pos_start : integer;
    pos_end : integer;
begin
    while (length(data) > 0) do
    begin

        pos_start := Pos(CmdStartChar, data);
        pos_end   := Pos(CmdStopChar, data);

        if (pos_start > 0) AND (pos_end > 0) AND (pos_start < pos_end) then
        begin
            tmp_cmd := copy(data, pos_start + 1, pos_end - pos_start - 1);
            Delete(data, pos_start, pos_end - pos_start + 1);

            parse_cmd(tmp_cmd);
{$IFNDEF DEBUG}
            tmp_cmd := '';
{$ENDIF}
        end
        else
        if (pos_start > 0) then
        begin
            tmp_cmd := copy(data, pos_start + 1, length(data) - pos_start);
            Delete(data,  pos_start, length(data) - pos_start + 1);
          end
        else
        if (pos_end > 0) then
        begin
             tmp_cmd := tmp_cmd + copy(data, 1, pos_end - 1);
             Delete(data, 1, pos_end);
             parse_cmd(tmp_cmd);
{$IFNDEF DEBUG}
            tmp_cmd := '';
{$ENDIF}
        end
        else
        begin
             tmp_cmd := tmp_cmd + data;
             SetLength(data, 0);
       end;
    end;
end;

function TSensors.decode_ascii85(data: TAscii85): TValue;
var
    i : smallint;
    m : Int64;
begin
    m := 1;
    Result.u := 0;

    for i := 4 downto 0 do
    begin
        Result.u := Result.u + (ord(data[i]) - 33) * m;
        m := m * 85;
    end;
end;

function TSensors.encode_ascii85(data: TValue): TAscii85;
var
    i : smallint;
begin
    for i := 4 downto 0 do
    begin
        Result[i] := chr((data.u mod 85) + 33);
        data.u := round(data.u / 85);
    end;
end;

procedure TSensors.set_value(var value: TValue; typ: TType; data: string);
var
    tmp : TAscii85;
//    pS : PSingle;
//    pI : PLongInt;
begin
    if (length(data) = 5) then
    begin
        tmp[0] := data[1];
        tmp[1] := data[2];
        tmp[2] := data[3];
        tmp[3] := data[4];
        tmp[4] := data[5];

        value := decode_ascii85(tmp);
        value.typ := typ;
{
        value.r[0] := ord(data[1]);
        value.r[1] := ord(data[2]);
        value.r[2] := ord(data[3]);
        value.r[3] := ord(data[4]);

        pS := PSingle(@value.r[0]);
        pI := PLongInt(@value.r[0]);

        case typ of
            TYPE_FLOAT  : value.f := pS^;
            TYPE_INT8   : value.i := $000000FF AND (pI^);
            TYPE_UINT8  : value.u := Cardinal($000000FF AND (pI^));
            TYPE_INT16  : value.i := $0000FFFF AND (pI^);
            TYPE_UINT16 : value.u := Cardinal($0000FFFF AND (pI^));
            TYPE_INT32  : value.i := pI^;
            TYPE_UINT32 : value.u := Cardinal(pI^);
        end;
}

    end else
    begin
        value.u := 0;
        value.typ := typ;
    end;
end;

procedure TSensors.set_units(var units: TSensorUnit; data: string);
var
    subunits : TStringList;
    s : integer;
    d, e : string;

begin
    subunits := TStringList.Create();
    explode(data, ';', subunits);

    if (subunits.Count = 4) then
    begin
        for s := 0 to 3 do
        begin
            d := copy(subunits.Strings[s], 1, 1);
            e := copy(subunits.Strings[s], 3, 2);

            units.baseunits[s].dimension := TDimension(strtoint(d));
            units.baseunits[s].exponent  := strtoint(e);
        end;
    end;

    subunits.free();
end;

function TSensors.make_typestring(measurement: TSensorMeasurement): string;
begin
{    if (measurement.typ = TYPE_FLOAT) then
        Result := inttostr(measurement.digits) + ' digits '
    else }
        Result := '';

    Result := concat(Result, TypeNames[integer(measurement.typ)] + '[' + inttostr(measurement.size) + ']');

end;

function TSensors.make_unitstring(units : TSensorUnit; full : boolean): string;
var
    n, d : integer;
    npc, npo : string;
    dpc, dpo : string;

    numerator : string;
    denominator : string;
    separator : string;
    u : integer;
begin
    numerator := '';
    denominator := '';
    n := 0;
    d := 0;
    npc := '';
    npo := '';
    dpc := '';
    dpo := '';

    for u := 0 to 3 do
    begin
        if units.baseunits[u].exponent > 0 then
        begin
            if (full) then
                numerator := concat(numerator,
                                    ' ',
                                    ExponentNames[units.baseunits[u].exponent],
                                    DimensionNames[integer(units.baseunits[u].dimension)])
            else
                numerator := concat(numerator,
                                    ' ',
                                    DimensionSymbols[integer(units.baseunits[u].dimension)],
                                    ExponentSymbols[abs(units.baseunits[u].exponent)]);
            inc(n);
        end;

        if units.baseunits[u].exponent < 0 then
        begin
            if (full) then
                denominator := concat(denominator,
                                      ' ',
                                      ExponentNames[abs(units.baseunits[u].exponent)],
                                      DimensionNames[integer(units.baseunits[u].dimension)])
            else
                denominator := concat(denominator,
                                      ' ',
                                      DimensionSymbols[integer(units.baseunits[u].dimension)],
                                      ExponentSymbols[abs(units.baseunits[u].exponent)]);
            inc(d);
        end;
    end;

    numerator   := trim(numerator);
    denominator := trim(denominator);

    if (full) then separator := ' per ' else separator := ' / ';

    if (n > 1) then
    begin
        npo := '(';
        npc := ')';
    end;

    if (d > 1) then
    begin
        dpo := '(';
        dpc := ')';
    end;

    if (length(numerator) = 0) then
        numerator := '1';

    if (length(denominator) > 0) then
        Result := npo + trim(numerator) + npc + separator + dpo + trim(denominator) + dpc
    else
        Result := trim(numerator);
end;

function TSensors.make_durationstring(measurement: TSensorMeasurement): string;
var
    f : integer;
begin
    if (measurement.duration > 0) then
    begin
        f := floor(1000 / measurement.duration);
        Result := inttostr(f) + ' Hz';
    end
    else
        Result := '? Hz';
end;

function TSensors.make_rangestring(measurement: TSensorMeasurement; range : smallint): string;
var
    maximum, minimum : single;
    precision, digits : integer;

    factor : single;
begin
//  factor := power(10.0, PrefixExponents[integer(measurement.units.prefix)]);
    factor := 1;
    
    case (measurement.typ) of
        TYPE_FLOAT :
        begin
            maximum := measurement.ranges[range].max.f * factor;
            minimum := measurement.ranges[range].min.f * factor;
        end;

        TYPE_UINT8,
        TYPE_UINT16,
        TYPE_UINT32:
        begin
            maximum := integer(measurement.ranges[range].max.u) * factor;
            minimum := integer(measurement.ranges[range].min.u) * factor;
        end;

        TYPE_INT8,
        TYPE_INT16,
        TYPE_INT32:
        begin
            maximum := measurement.ranges[range].max.i * factor;
            minimum := measurement.ranges[range].min.i * factor;
        end;
    end;

    digits := measurement.ranges[range].digits;

    precision := ceil(log10(max(abs(maximum), abs(minimum)))) + digits;

    Result := inttostr(range + 1) +
              ' : ' +
              FloatToStrF(minimum, ffFixed, precision, digits) +
              ' to ' +
              FloatToStrF(maximum, ffFixed, precision, digits) +
              ' ' +
              PrefixSymbols[integer(measurement.units.prefix)] + 
              measurement.units.symbol;
end;

procedure TSensors.parse_cmd(command: string);
var
    arg : TStringList;
    args, s, m, v, l : integer;
begin
    arg := TStringList.Create();
    args := explode(command, CmdDelimiter, arg);

    if (args <> -1) AND (arg.count > 0) AND (length(arg.strings[0]) = 1) then
    begin
        case (arg.Strings[0][1]) of
            'a' :
            begin
                if arg.count = 2 then
                begin
                    fNoOfSensors := strtoint(arg.strings[1]);
                    SetLength(fSensors, fNoOfSensors);
                end;
             end;

            'b' :
            begin
                if arg.count = 5 then
                begin
                    s := strtoint(arg.strings[1]);

                    if (s < fNoOfSensors) then
                    begin
                        fSensors[s].name := arg.strings[2];
                        fSensors[s].part := arg.strings[3];
                        fSensors[s].NoOfMeasurements := strtoint(arg.strings[4]);
                        SetLength(fSensors[s].Measurements, fSensors[s].NoOfMeasurements);
                    end;
                end;
            end;

            'c' :
            begin
                if arg.count > 8 then
                begin
                    s := strtoint(arg.strings[1]);
                    m := strtoint(arg.strings[2]);

                    if (s < fNoOfSensors) then
                    begin
                        if (m < fSensors[s].NoOfMeasurements) then
                        begin
                            fSensors[s].Measurements[m].name := arg.strings[3];

                            fSensors[s].Measurements[m].duration := strtointDef(arg.strings[4], 100);

                            fSensors[s].Measurements[m].typ    := TType(strtoint(arg.strings[5]));
                            fSensors[s].Measurements[m].size   := strtoint(arg.strings[6]);
                            fSensors[s].Measurements[m].NoOfRanges := strtoint(arg.strings[7]);

                            fSensors[s].Measurements[m].range := 0;

                            if (arg.count = 8 + fSensors[s].Measurements[m].NoOfRanges * 3) then
                            begin
                                for v := 0 to fSensors[s].Measurements[m].NoOfRanges - 1 do
                                begin
                                    set_value(fSensors[s].Measurements[m].ranges[v].min, fSensors[s].Measurements[m].typ, arg.strings[8 + v*3]);
                                    set_value(fSensors[s].Measurements[m].ranges[v].max, fSensors[s].Measurements[m].typ, arg.strings[9 + v*3]);
                                    fSensors[s].Measurements[m].ranges[v].digits := strtoint(arg.strings[10 + v*3]);
                                end;
                            end;
                        end;
                    end;
                end;
            end;

            'd' :
            begin
                if arg.count = 7 then
                begin
                    s := strtoint(arg.strings[1]);
                    m := strtoint(arg.strings[2]);

                    fSensors[s].Measurements[m].units.name := arg.strings[3];
                    fSensors[s].Measurements[m].units.symbol := arg.strings[4];
                    fSensors[s].Measurements[m].units.prefix := TPrefix(strtoint(arg.strings[5]));

                    set_units(fSensors[s].Measurements[m].units, arg.strings[6]);
                end;
            end;

            'e' :
            begin
                if arg.count > 5 then
                begin
                    s := strtoint(arg.strings[1]);
                    m := strtoint(arg.strings[2]);
                    fSensors[s].Measurements[m].range := strtointDef(arg.strings[3], 0);
                    l := strtoint(arg.strings[4]);

                    if (arg.count = 5 + l) {AND (l = fSensors[s].Measurements[m].size)} then
                    begin
                        setLength(tmp_value, l);

                        for v := 0 to l - 1 do
                        begin
                            set_value(tmp_value[v], fSensors[s].Measurements[m].typ, arg.strings[5 + v]);
                        end;
                    end;
                end;
            end;

            'f' :
            begin
                 if arg.count = 4 then
                 begin
                    s := strtoint(arg.strings[1]);
                    m := strtoint(arg.strings[2]);
                    fSensors[s].Measurements[m].range := strtointDef(arg.strings[3], 0);
                 end;
            end;
            
            else
            begin
//                form1.debug.lines.add('C : Unknown command reply');
            end;
        end;
        SetEvent(reply);
    end;
    arg.Free;
end;

function TSensors.wait_forReply: boolean;
begin
    if (WaitForSingleObject(reply, 1000) = WAIT_OBJECT_0) then
    begin
        ResetEvent(reply);
{$IFDEF DEBUG}
        form1.debug.lines.add(tmp_cmd);
{$ENDIF}
        Result := true;
    end else
    begin
        Result := false;
    end;
end;

procedure TSensors.refresh_tree;
var
    s, m, r : integer;
begin
    if (assigned(fTreeView)) then
    begin
        fTreeView.Items.Clear;
        fTreeView.ShowRoot := True;
        RootNode := fTreeView.Items.Add(nil, 'SensorArray on COM' + inttostr(fComport.ComPort));

        fTreeView.Items.AddChild(RootNode, 'Sensors : ' + inttostr(fNoOfSensors));

        SetLength(SensorNodes, fNoOfSensors);
        SetLength(MeasurementNodes, fNoOfSensors);
        SetLength(RangeNodes, fNoOfSensors);

        for s := 0 to fNoOfSensors - 1 do
        begin
            SensorNodes[s] := fTreeView.Items.AddChild(RootNode, fSensors[s].name);

            fTreeView.Items.AddChild(SensorNodes[s], 'Part : ' + fSensors[s].part);
            fTreeView.Items.AddChild(SensorNodes[s], 'Measurements : ' + inttostr(fSensors[s].NoOfMeasurements));

            SetLength(MeasurementNodes[s], fSensors[s].NoOfMeasurements);
            SetLength(RangeNodes[s], fSensors[s].NoOfMeasurements);

            for m := 0 to Sensors[s].NoOfMeasurements - 1 do
            begin
                MeasurementNodes[s][m] := fTreeView.Items.AddChild(SensorNodes[s], fSensors[s].Measurements[m].name +
                 ' (' + fSensors[s].Measurements[m].units.name + ')');

                fTreeView.Items.AddChild(MeasurementNodes[s][m], 'Rate : ' + make_durationstring(fSensors[s].Measurements[m]));
                fTreeView.Items.AddChild(MeasurementNodes[s][m], 'Type : ' + make_typestring(fSensors[s].Measurements[m]));
                fTreeView.Items.AddChild(MeasurementNodes[s][m], 'Unit : ' + make_unitstring(fSensors[s].Measurements[m].units, false));

                RangeNodes[s][m] := fTreeView.Items.AddChild(MeasurementNodes[s][m], 'Ranges (active : ' +  inttostr(fSensors[s].Measurements[m].range + 1) + ')');

                for r := 0 to fSensors[s].Measurements[m].NoOfRanges - 1 do
                begin
                    fTreeView.Items.AddChild(RangeNodes[s][m], make_rangestring(fSensors[s].Measurements[m], r));
                end;

            end;

        end;

//        fTreeView.fullExpand();
        RootNode.Expand(false);
        fTreeView.Selected := RootNode;
    end;
end;

function TSensors.Initialize: boolean;
var
    s, m : integer;
begin
    get_NoOfSensors();

    for s := 0 to fNoOfSensors - 1 do
    begin
        get_SensorInfo(s);

        for m := 0 to Sensors[s].NoOfMeasurements - 1 do
        begin
            get_MeasurementInfo(s, m);
            get_MeasurementUnitInfo(s, m);
        end;
    end;

    refresh_tree();

    Result := true;
end;

procedure TSensors.get_NoOfSensors;
begin
    if fcomport.connected then
    begin
        fcomport.send(CmdStartChar + 'a' + CmdStopChar + #10);
        wait_forReply();
    end;
end;

procedure TSensors.get_SensorInfo(sensor: integer);
var
    s_no : integer;
begin
    if fcomport.connected then
    begin
        s_no := sensor + ord('0');
        
        fcomport.send(CmdStartChar + 'b' + CmdDelimiter +
                      chr(s_no) + CmdStopChar + #10);

        wait_forReply();
    end;
end;

procedure TSensors.get_MeasurementInfo(sensor, measurement: integer);
var
    s_no : integer;
    m_no : integer;
begin
    if fcomport.connected then
    begin
        s_no := sensor + ord('0');
        m_no := measurement + ord('0');
        
        fcomport.send(CmdStartChar + 'c' + CmdDelimiter +
                      chr(s_no) + CmdDelimiter +
                      chr(m_no) + CmdStopChar + #10);
                      
        wait_forReply();
    end;
end;

procedure TSensors.get_MeasurementUnitInfo(sensor, measurement: integer);
var
    s_no : integer;
    m_no : integer;
begin
    if fcomport.connected then
    begin
        s_no := sensor + ord('0');
        m_no := measurement + ord('0');
        
        fcomport.send(CmdStartChar + 'd' + CmdDelimiter +
                      chr(s_no) + CmdDelimiter +
                      chr(m_no) + CmdStopChar + #10);
                      
        wait_forReply();
    end;
end;

procedure TSensors.set_range(sensor, measurement, range: integer);
var
    s_no : integer;
    m_no : integer;
    r_no : integer;
    ar : smallint;
begin
    if fcomport.connected then
    begin
        if (sensor > -1) AND (measurement > -1) AND
           (sensor < fNoOfSensors) AND (measurement < fSensors[sensor].NoOfMeasurements) AND
           (range < fSensors[sensor].Measurements[measurement].NoOfRanges)
        then
        begin

            s_no := sensor + ord('0');
            m_no := measurement + ord('0');
            r_no := range + ord('0');

            fcomport.send(CmdStartChar + 'f' + CmdDelimiter +
                      chr(s_no) + CmdDelimiter +
                      chr(m_no) + CmdDelimiter +
                      chr(r_no) + CmdStopChar + #10);

            wait_forReply();

            if assigned(fTreeView) then
            begin
                ar := fSensors[sensor].Measurements[measurement].range + 1;
                RangeNodes[sensor][measurement].Text := 'Ranges (active : ' + inttostr(ar) + ')';
            end;
        end;
    end;
end;

procedure TSensors.value(sensor : integer; measurement : integer; var data : TValueVector);
var
    s_no : integer;
    m_no : integer;
    v    : integer;
    ar   : smallint;
begin
    if (sensor > -1) AND (measurement > -1) AND
       (sensor < fNoOfSensors) AND (measurement < fSensors[sensor].NoOfMeasurements) then
    begin
        s_no := sensor + ord('0');
        m_no := measurement + ord('0');

        if fcomport.connected then
            fcomport.send(CmdStartChar + 'e' + CmdDelimiter +
                          chr(s_no) + CmdDelimiter +
                          chr(m_no) + CmdStopChar + #10);

        if (NOT fcomport.connected) OR (NOT wait_forReply()) then
        begin
            SetLength(data, 1);
            for v := 0 to length(data) - 1 do
                data[v].i := 0;
        end else
        begin
            if assigned(fTreeView) then
            begin
                ar := fSensors[sensor].Measurements[measurement].range + 1;
                RangeNodes[sensor][measurement].Text := 'Ranges (active : ' + inttostr(ar) + ')';
            end;

            setLength(data, length(tmp_value));
            data := tmp_value;
        end;

    end else
        raise Exception.Create('TSensors : Sensor- or Measurementindex out of Range!');
end;

function TSensors.valueFormat(sensor, measurement: integer): string;
var
    v : TValueVector;
    b : integer;
    s : integer;
    range : smallint;
begin
    Result := '';

    if (sensor > -1) AND (measurement > -1) AND
       (sensor < fNoOfSensors) AND (measurement < fSensors[sensor].NoOfMeasurements) then
    begin
        value(sensor, measurement, v);

        Result := fSensors[sensor].name + ' (' + fSensors[sensor].measurements[measurement].name + ') : ';

        for s := 0 to length(v) - 1 do begin

            if (length(v) > 1) then
                Result := concat(Result, #13, #10);

            range := fSensors[sensor].measurements[measurement].range;

            case (v[s].typ) of
            TYPE_FLOAT :
                Result := concat(Result, FloatToStrF(v[s].f, ffFixed, 8, fSensors[sensor].measurements[measurement].ranges[range].digits));

            TYPE_UINT8,
            TYPE_UINT16,
            TYPE_UINT32:
                Result := concat(Result, inttostr(v[s].u));

            TYPE_INT8,
            TYPE_INT16,
            TYPE_INT32:
                Result := concat(Result, inttostr(v[s].i));
            end;

            Result := concat(Result, ' ', PrefixSymbols[integer(fSensors[sensor].measurements[measurement].units.prefix)], fSensors[sensor].measurements[measurement].units.symbol);

            Result := concat(Result, ' [');

            for b := 3 downto 0 do
                Result := concat(Result, inttohex(v[s].r[b], 2));

            Result := concat(Result, ']');
        end;
    end;
end;

function TSensors.explode(text, delimiter : string; var list : TStringList) : integer;
var
    p : integer;
begin
    if assigned(list) then
    begin
        while length(text) > 0 do
        begin
            p := pos(delimiter, text);

            if (p > 0) then
            begin
                list.Add(copy(text, 1, p-1));
                Delete(text, 1, p);
            end else
            begin
                list.Add(text);
                text :=  '';
            end;
        end;
        Result := list.Count;
    end else
        Result := -1;
end;

procedure TSensors.selected(var sensor, measurement, range: integer);
var
    i : integer;
begin
    sensor := -1;
    measurement := -1;
    range := -1;

    if (assigned(fTreeView)) then
    begin
        for i := 0 to fTreeView.items.count - 1 do
        begin
            if (fTreeView.items[i].selected) then
            begin
                if (fTreeView.items[i].level = 2) AND (fTreeView.items[i].HasChildren) then
                begin
                    sensor      := fTreeView.Items[i].Parent.Index - 1;
                    measurement := fTreeView.Items[i].Index - 2;
                    range       := -1;
                end
                else if (fTreeView.items[i].level = 4) then
                begin
                    sensor      := fTreeView.items[i].Parent.Parent.Parent.index - 1;
                    measurement := fTreeView.items[i].Parent.Parent.index - 2;
                    range       := fTreeView.items[i].index;
                end;
            end;
        end;
    end;
end;

end.
