unit SerialPort;

interface

uses Windows, SysUtils, Classes;

type
    TRxHandler = procedure(data : string) of object;
    TTxEmptyHandler = procedure() of object;
    TBreakHandler = procedure() of object;
    TRingHandler = procedure() of object;
    TSignalHandler = procedure(signal : integer; state : boolean) of object;
    TErrorHandler = procedure(e : integer) of object;

    TSerialPort = class(TThread)
    protected
        event : cardinal;
        rxdata: string;
        status : TOverlapped;

        read, write : TOverlapped;
        procedure Execute; override;

    private
        porthandle : THandle;
        portstate : cardinal;

        fConnected : boolean;
        fEcho : boolean;

        fComPort  : integer;
        fBaudRate : integer;
        fByteSize : integer;
        fParity   : integer;
        fStopBits : integer;

        fDTR : boolean;
        fRTS : boolean;
        fCTS : boolean;
        fDSR : boolean;
        fRLSD : boolean;
        fRING : boolean;

        fRxQue : integer;
        fTxQue : integer;

        fRxHandler      : TRxHandler;
        fTxEmptyHandler : TTxEmptyHandler;
        fBreakHandler   : TBreakHandler;
        fRingHandler    : TRingHandler;
        fSignalHandler  : TSignalHandler;
        fErrorHandler   : TErrorHandler;

        procedure opencom();
        procedure closecom();

        function receive(var data : string) : boolean;

        procedure set_DTR(value : boolean);
        procedure set_RTS(value : boolean);

        function get_CTS() : boolean;
        function get_DSR() : boolean;
        function get_RLSD() : boolean;
        function get_RING() : boolean;

        function get_RxQue() : integer;
        function get_TxQue() : integer;

        function get_CommState(var state : _COMSTAT; var error : DWORD) : boolean;

        procedure HandleEvent();

        procedure OnTerminate(Sender: TObject);

    public
        constructor Create();
        destructor Destroy(); override;

        function open(comport, baudrate, bytesize, parity, stopbits: integer) : boolean;
        procedure close();

        function send(data : string) : boolean;

        procedure break();
        procedure unbreak();

        procedure purge();

        property connected : boolean read fConnected;
        property echo : boolean read fEcho write fEcho;

        property ComPort  : integer read fComPort;
        property BaudRate : integer read fBaudRate;
        property StopBits : integer read fStopBits;
        property Parity   : integer read fParity;
        property ByteSize : integer read fByteSize;

        property DTR : boolean read fDTR write set_DTR;
        property RTS : boolean read fRTS write set_RTS;
        property CTS : boolean read get_CTS;
        property DSR : boolean read get_DSR;
        property RLSD : boolean read get_RLSD;
        property RING : boolean read get_RING;

        property RxQue : integer read get_RxQue;
        property TxQue : integer read get_TxQue;

        property OnReceive      : TRxHandler      read fRxHandler      write fRxHandler;
        property OnTxEmpty      : TTxEmptyHandler read fTxEmptyHandler write fTxEmptyHandler;
        property OnBreak        : TBreakHandler   read fBreakHandler   write fBreakHandler;
        property OnRing         : TRingHandler    read fRingHandler    write fRingHandler;
        property OnSignalChange : TSignalHandler  read fSignalHandler  write fSignalHandler;
        property OnLineError    : TErrorHandler   read fErrorHandler   write fErrorHandler;
        
    end;

implementation

uses unit1;

{ TSerialPort }

constructor TSerialPort.Create();
begin
    FreeOnTerminate := false;
    fConnected := false;
    porthandle := 0;
    fEcho := false;
    fComPort := 0;
    fBaudRate := 0;
    fStopBits := 0;
    fParity := 0;
    fByteSize := 0;

    inherited Create(false);    // CreateSuspended = false -> Run Execute immediately
end;

destructor TSerialPort.Destroy;
begin
    closecom();
    inherited;
end;

procedure TSerialPort.opencom();
var
    port : string;
    DCB : TDCB;
    timeout: PCOMMTIMEOUTS;
    error : DWORD;
begin
    port := '\\.\COM' + inttostr(fComPort);
    
    porthandle := CreateFile(Pchar(port), GENERIC_WRITE OR GENERIC_READ, 0, nil, OPEN_EXISTING, FILE_FLAG_OVERLAPPED, 0);

    if porthandle = INVALID_HANDLE_VALUE then begin
        raise Exception.Create('TSerialPort : Unable to open port COM' + inttostr(fComPort));
    end else
    begin
        DCB.DCBlength := sizeof(DCB);
        DCB.ByteSize := fByteSize;
        DCB.Parity := fParity;
        DCB.BaudRate := fBaudRate;
        DCB.Flags := 5123;
        DCB.StopBits := fStopBits;
//        DCB.EvtChar := '>';
        DCB.EofChar := #0;
        DCB.ErrorChar := #0;
        DCB.XoffChar := #0;
        DCB.XonChar := #0;
        DCB.XonLim :=  0;
        DCB.XoffLim := 0;

        status.Offset := 0;
        status.OffsetHigh := 0;
        status.Internal := 0;
        status.InternalHigh := 0;
        status.hEvent := CreateEvent(nil, True, False, '');

        read.Offset := 0;
        read.OffsetHigh := 0;
        read.Internal := 0;
        read.InternalHigh := 0;
        read.hEvent := CreateEvent(nil, True, False, '');

        write.Offset := 0;
        write.OffsetHigh := 0;
        write.Internal := 0;
        write.InternalHigh := 0;
        write.hEvent := CreateEvent(nil, True, False, '');


        if not SetCommState(porthandle, DCB) then begin
            error := GetLastError();
            raise Exception.Create('TSerial Port : Unable to configure Port. Error (' + inttostr(error) + ')');
        end;

        GetMem(timeout, sizeof(COMMTIMEOUTS));

        GetCommTimeouts (porthandle, timeout^);
        timeout.ReadIntervalTimeout        := 300;
        timeout.ReadTotalTimeoutMultiplier := 300;
        timeout.ReadTotalTimeoutConstant   := 300;
        SetCommTimeouts (porthandle, timeout^);

        FreeMem(timeout, sizeof(COMMTIMEOUTS));

        SetupComm(porthandle, 40, 40);

        SetCommMask(porthandle, EV_CTS or EV_BREAK or EV_DSR or
                    EV_ERR or EV_RING or EV_RLSD or EV_RXCHAR or EV_RXFLAG or EV_TXEMPTY);

        fConnected := true;
    end;
end;

procedure TSerialPort.closecom;
begin
    purge();

    if (porthandle > 0) then begin
        SetCommMask(porthandle, 0);
        CloseHandle(porthandle);
    end;

    fConnected := false;
    porthandle := 0;
end;

procedure TSerialPort.Execute;
var
    serialevent, waitresult, bytesread: Cardinal;
    error : DWORD;
begin
    try
        while (not Terminated) do begin
            if (fConnected) then begin

                if not WaitCommEvent(porthandle, serialevent, @status) then
                begin
                    error := GetLastError();

                    if (error = ERROR_IO_PENDING) then
                    begin
                        waitresult := WaitForSingleObject(status.hEvent, INFINITE);

                        case (waitresult) of
                            WAIT_OBJECT_0:
                            begin
                                if GetOverlappedResult(porthandle, status, bytesread, false) then begin
                                    event := serialevent;
                                    //Synchronize(HandleEvent);
                                    HandleEvent();
                                end;
                            end;
                        end;
                    end;
                end else
                begin
                    event := serialevent;
                    //Synchronize(HandleEvent);
                    HandleEvent;
                end;
            end;
        end;
    except
        on e: exception do begin

        end;
    end;
end;

procedure TSerialPort.HandleEvent();
var
    state : _COMSTAT;
    error : DWORD;
begin
    if (event AND EV_RXCHAR = EV_RXCHAR) OR
       (event AND EV_RXFLAG = EV_RXFLAG) then
    begin
        receive(rxdata);

        if assigned(fRxHandler) then
            fRxHandler(rxdata);

        if (fEcho) then
            send(rxdata);
    end;

    if (event AND EV_TXEMPTY = EV_TXEMPTY) then
        if assigned(fTxEmptyHandler) then
            fTxEmptyHandler();

    if (event AND EV_CTS = EV_CTS) then
        if assigned(fSignalHandler) then
            fSignalHandler(EV_CTS, get_CTS());

    if (event AND EV_DSR = EV_DSR) then
        if assigned(fSignalHandler) then
            fSignalHandler(EV_DSR, get_DSR());

    if (event AND EV_RLSD = EV_RLSD) then
        if assigned(fSignalHandler) then
            fSignalHandler(EV_RLSD, get_RLSD());

    if (event AND EV_BREAK = EV_BREAK) then
        if assigned(fBreakHandler) then
            fBreakHandler();

    if (event AND EV_ERR = EV_ERR) then
    begin
        get_CommState(state, error);
        if assigned(fErrorHandler) then
            fErrorHandler(error);
    end;

    if (event AND EV_RING = EV_RING) then
        if assigned(fRingHandler) then
            fRingHandler();

end;

procedure TSerialPort.OnTerminate(Sender: TObject);
begin
    closecom();
    FreeAndNil(self);
end;

procedure TSerialPort.close;
begin
    closecom();
end;

function TSerialPort.open(comport, baudrate, bytesize, parity, stopbits: integer): boolean;
begin
    fComPort  := comport;

    case (baudrate) of
    CBR_110, CBR_300, CBR_600, CBR_1200, CBR_2400,
    CBR_4800, CBR_9600, CBR_14400, CBR_19200, CBR_38400,
    CBR_56000, CBR_57600, CBR_115200, CBR_128000, CBR_256000:
        fBaudRate := baudrate
    else
        raise Exception.Create('TSerialPort : Invalid Baudrate');
    end;

    if (4 < bytesize) AND (bytesize < 9) then
        fByteSize := bytesize
    else
        raise Exception.Create('TSerialPort : Invalid Bytesize');

    if (0 <= parity) AND (parity < 5) then
        fParity := parity
    else
        raise Exception.Create('TSerialPort : Invalid Parity');

    if (0 <= stopbits) AND (stopbits < 3) then
        fStopBits := stopbits
    else
        raise Exception.Create('TSerialPort : Invalid Stopbits');

    opencom();

    Result := true;
end;

procedure TSerialPort.break;
begin
    if (porthandle > 0) then
        SetCommBreak(porthandle);
end;

procedure TSerialPort.unbreak;
begin
    if (porthandle > 0) then
        ClearCommBreak(porthandle);
end;

procedure TSerialPort.purge;
begin
    if (porthandle > 0) then
        PurgeComm(porthandle, PURGE_RXABORT or PURGE_RXCLEAR or PURGE_TXABORT or PURGE_TXCLEAR);
end;

function TSerialPort.get_CommState(var state : _COMSTAT; var error : DWORD) : boolean;
begin
    if (porthandle > 0) then begin
        Result := ClearCommError(porthandle, error, @state);
    end else
        Result := false;
end;

function TSerialPort.get_RxQue: integer;
var
    state : _COMSTAT;
    error : DWORD;
begin
    if (get_CommState(state, error)) then
        fRxQue := integer(state.cbInQue)
    else
        fRxQue := -1;

    Result := fRxQue;
end;

function TSerialPort.get_TxQue: integer;
var
    state : _COMSTAT;
    error : DWORD;
begin
    if (get_CommState(state, error)) then
        fTxQue := integer(state.cbOutQue)
    else
        fTxQue := -1;

    Result := fTxQue;
end;

function TSerialPort.get_CTS: boolean;
begin
    if (porthandle > 0) then begin
        GetCommModemStatus(porthandle, portstate);

        if ((portstate and MS_CTS_ON) <> 0) then
            fCTS := true
        else
            fCTS := false;

        Result := fCTS;
    end else
        Result := false;
end;

function TSerialPort.get_DSR: boolean;
begin
    if (porthandle > 0) then begin
        GetCommModemStatus(porthandle, portstate);

        if ((portstate and MS_DSR_ON) <> 0) then
            fDSR := true
        else
            fDSR := false;

        Result := fDSR;
    end else
        Result := false;
end;

function TSerialPort.get_RING: boolean;
begin
    if (porthandle > 0) then begin
        GetCommModemStatus(porthandle, portstate);

        if ((portstate and MS_RING_ON) <> 0) then
            fRING := true
        else
        fRING := false;

        Result := fRING;
    end else
        Result := false;
end;

function TSerialPort.get_RLSD: boolean;
begin
    if (porthandle > 0) then begin
        GetCommModemStatus(porthandle, portstate);

        if ((portstate and MS_RLSD_ON) <> 0) then
            fRLSD := true
        else
            fRLSD := false;

        Result := fRLSD;
    end else
        Result := false;
end;

procedure TSerialPort.set_DTR(value: boolean);
begin
    if (porthandle > 0) then begin
        if (value) then
            EscapeCommFunction(porthandle, SETDTR)
        else
            EscapeCommFunction(porthandle, CLRDTR);
    end;
end;

procedure TSerialPort.set_RTS(value: boolean);
begin
    if (porthandle > 0) then begin
        if (value) then
            EscapeCommFunction(porthandle, SETRTS)
        else
            EscapeCommFunction(porthandle, CLRRTS);
    end;
end;

function TSerialPort.send(data: string): boolean;
var
    written : Cardinal;
begin
    if (porthandle > 0) then begin
        Result := not WriteFile(porthandle, data[1], Length(data), written, @write);
    end else
        Result := false;
end;

function TSerialPort.receive(var data: string): boolean;
var
    state : _COMSTAT;
    error : DWORD;
    bytesread : DWORD;
begin
    get_CommState(state, error);
    if (state.cbInQue > 0) then
    begin
        SetLength(data, state.cbInQue);
        Result := ReadFile(porthandle, data[1], state.cbInQue, bytesread, @read);
    end else
        Result := false;
end;

end.
