object Form1: TForm1
  Left = 1083
  Top = 558
  Width = 769
  Height = 559
  AutoSize = True
  Caption = 'Sensor Array'
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnClose = FormClose
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object SpeedButton1: TSpeedButton
    Left = 232
    Top = 488
    Width = 65
    Height = 25
    Caption = 'Capture'
    OnClick = SpeedButton1Click
  end
  object SettingsBox: TGroupBox
    Left = 0
    Top = 448
    Width = 225
    Height = 73
    Caption = 'Communication Settings'
    TabOrder = 0
    object comlist: TComboBox
      Left = 8
      Top = 16
      Width = 129
      Height = 21
      ItemHeight = 13
      Sorted = True
      TabOrder = 0
      Text = 'Choose Port'
    end
    object comlist_refresh: TButton
      Left = 146
      Top = 16
      Width = 63
      Height = 21
      Caption = 'Refresh'
      TabOrder = 1
      OnClick = comlist_refreshClick
    end
    object baudlist: TComboBox
      Left = 8
      Top = 40
      Width = 129
      Height = 21
      ItemHeight = 13
      TabOrder = 2
      Text = 'Choose Baudrate'
      Items.Strings = (
        '110'
        '150'
        '300'
        '1200'
        '2400'
        '4800'
        '9600'
        '19200'
        '38400'
        '57600'
        '115200'
        '230400'
        '460800'
        '921600')
    end
    object connect: TButton
      Left = 146
      Top = 40
      Width = 63
      Height = 21
      Caption = 'Open'
      TabOrder = 3
      OnClick = connectClick
    end
  end
  object DebugBox: TGroupBox
    Left = 312
    Top = 240
    Width = 441
    Height = 201
    Caption = 'Debug'
    TabOrder = 1
    object debug: TMemo
      Left = 8
      Top = 16
      Width = 425
      Height = 177
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Courier New'
      Font.Style = []
      ParentFont = False
      TabOrder = 0
    end
  end
  object sensorlistbox: TGroupBox
    Left = 0
    Top = 0
    Width = 305
    Height = 441
    Caption = 'Sensor List'
    TabOrder = 2
    object getsensorlist: TButton
      Left = 48
      Top = 400
      Width = 217
      Height = 25
      Caption = 'Get Sensor List'
      TabOrder = 0
      OnClick = getsensorlistClick
    end
    object sensortree: TTreeView
      Left = 8
      Top = 16
      Width = 289
      Height = 377
      Enabled = False
      Font.Charset = ANSI_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Courier New'
      Font.Style = []
      Indent = 16
      ParentFont = False
      ReadOnly = True
      TabOrder = 1
      OnClick = sensortreeClick
      OnKeyPress = sensortreeKeyPress
    end
  end
  object sensorchart: TChart
    Left = 312
    Top = 8
    Width = 433
    Height = 225
    BackWall.Brush.Color = clWhite
    BackWall.Brush.Style = bsClear
    Title.Font.Charset = ANSI_CHARSET
    Title.Font.Color = clBlack
    Title.Font.Height = -16
    Title.Font.Name = 'Courier New'
    Title.Font.Style = []
    Title.Text.Strings = (
      'Sensor Array')
    BottomAxis.ExactDateTime = False
    BottomAxis.Grid.Visible = False
    BottomAxis.Title.Caption = 'Time [s]'
    Legend.Visible = False
    View3D = False
    View3DWalls = False
    Color = clWhite
    TabOrder = 3
    object Series1: TFastLineSeries
      Marks.ArrowLength = 8
      Marks.Visible = False
      SeriesColor = clRed
      LinePen.Color = clRed
      LinePen.Width = 2
      XValues.DateTime = False
      XValues.Name = 'X'
      XValues.Multiplier = 1
      XValues.Order = loAscending
      YValues.DateTime = False
      YValues.Name = 'Y'
      YValues.Multiplier = 1
      YValues.Order = loNone
    end
    object Series2: TFastLineSeries
      Marks.ArrowLength = 8
      Marks.Visible = False
      SeriesColor = clGreen
      LinePen.Color = clGreen
      LinePen.Width = 2
      XValues.DateTime = False
      XValues.Name = 'X'
      XValues.Multiplier = 1
      XValues.Order = loAscending
      YValues.DateTime = False
      YValues.Name = 'Y'
      YValues.Multiplier = 1
      YValues.Order = loNone
    end
    object Series3: TFastLineSeries
      Marks.ArrowLength = 8
      Marks.Visible = False
      SeriesColor = 10485760
      LinePen.Color = 10485760
      LinePen.Width = 2
      XValues.DateTime = False
      XValues.Name = 'X'
      XValues.Multiplier = 1
      XValues.Order = loAscending
      YValues.DateTime = False
      YValues.Name = 'Y'
      YValues.Multiplier = 1
      YValues.Order = loNone
    end
    object Series4: TFastLineSeries
      Marks.ArrowLength = 8
      Marks.Visible = False
      SeriesColor = clBlack
      XValues.DateTime = False
      XValues.Name = 'X'
      XValues.Multiplier = 1
      XValues.Order = loAscending
      YValues.DateTime = False
      YValues.Name = 'Y'
      YValues.Multiplier = 1
      YValues.Order = loNone
    end
  end
  object s_no: TEdit
    Left = 232
    Top = 456
    Width = 25
    Height = 21
    MaxLength = 1
    TabOrder = 4
    Text = '0'
  end
  object m_no: TEdit
    Left = 272
    Top = 456
    Width = 25
    Height = 21
    MaxLength = 1
    TabOrder = 5
    Text = '0'
  end
  object colorpanel: TPanel
    Left = 360
    Top = 456
    Width = 41
    Height = 41
    Color = clWhite
    TabOrder = 6
  end
  object Timer1: TTimer
    Enabled = False
    Interval = 50
    OnTimer = Timer1Timer
    Left = 272
    Top = 400
  end
end
