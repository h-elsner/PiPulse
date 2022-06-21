{
HW-PWM auf GPIO18:
   dtoverlay=pwm,pin=18,func=2
in /boot/config.txt eintragen und reboot.
}

unit pipulse_main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ComCtrls, StdCtrls,
  ExtCtrls, LedNumber, MKnob, SR24_ctrl;

type

  { TForm1 }

  TForm1 = class(TForm)
    Button1: TButton;
    cbRevers: TCheckBox;
    lblFreq: TLabel;
    lblPulse: TLabel;
    lblProz: TLabel;
    ledFreq: TLEDNumber;
    ledPuls: TLEDNumber;
    knFreq: TmKnob;
    knPulse: TmKnob;
    rgPstep: TRadioGroup;
    rgFstep: TRadioGroup;
    rgFreq: TRadioGroup;
    stepFreq: TUpDown;
    stepPulse: TUpDown;
    procedure Button1Click(Sender: TObject);
    procedure cbReversChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure knFreqChange(Sender: TObject; AValue: Longint);
    procedure knPulseChange(Sender: TObject; AValue: Longint);
    procedure rgFreqClick(Sender: TObject);
    procedure rgFstepClick(Sender: TObject);
    procedure rgPstepClick(Sender: TObject);
    procedure stepFreqClick(Sender: TObject; Button: TUDBtnType);
    procedure stepPulseClick(Sender: TObject; Button: TUDBtnType);
  private

  public
    function  InitPWM: integer;                          {PWM0 erzeugen und freigeben}
    procedure SetFreq(const fi: int64);                  {Anzeige und Ausgabe Frequenz}
    procedure SetPuls(const fi: int64);                  {Puls/Pause Verhältnis einstellen}
    function  GetFreq: int64;                            {Frequenz in Hz aus den Reglern lesen}
  end;

var
  Form1: TForm1;

const
  capForm='Pi Pulsgenerator';
  capFreq='Frequenz';
  capPulse='Pulse';
  khz='kHz';
  hz='Hz';
  mhz='MHz';
  ms='ms';
  ns='ns';
  mys='µs';
  mysled='mys';
  tab1=' ';

  Fmax=30;                                               {maximum Frequency in Mhz}

implementation

{$R *.lfm}

{ TForm1 }

function fill(len: integer; s: string): string;          {Text Rechtsbündig für die LED-Ziffern}
var
  i, z: integer;

begin
  result:=s;
  z:=0;
  for i:=1 to length(s) do
    if s[i]<>DefaultFormatSettings.DecimalSeparator then
      inc(z);
  for i:=1 to len-z do
    result:=tab1+result;
end;

function TForm1.InitPWM: integer;                        {PWM0 erzeugen und freigeben}
begin
  result:=ActivatePWMChannel(false);                     {Enable PWM0}
  Application.ProcessMessages;
  SetPWMChannel(0, 1000, 500000, false);
end;

procedure TForm1.FormCreate(Sender: TObject);            {Start mit 1kHz, 1:1}
begin
  Caption:=capForm;
  InitPWM;
  knPulse.Position:=500;                                 {Puls/Pause 1:1}
  knFreq.Position:=1;
end;

function TForm1.GetFreq: int64;                          {Frequenz in Hz aus den Reglern lesen}
var
  kn, st: integer;

begin
  kn:=1;
  st:=1;
  case rgFreq.ItemIndex of
    1: kn:=1000;
    2: begin kn:=1000000; st:=1000; end;
  end;
  result:=knFreq.Position*kn+stepFreq.Position*st;
  if result>Fmax*1000000 then                            {Maximum Fmax in MHz}
    result:=Fmax*1000000;
  if result<1 then
    result:=1;                                           {Minimum 1Hz}
end;

procedure TForm1.SetPuls(const fi: int64);               {Puls/Pause Verhältnis einstellen}
var
  d: double;

begin
  d:=(1000000/fi)*knPulse.Position;                      {Pulslänge in ns aus Frequenz berechen}

// Anzeigekram
  lblProz.Caption:=FormatFloat('0.0', knPulse.Position/10)+'%';
  if d>=5000000 then begin
    ledPuls.Caption:=fill(ledPuls.Columns, FormatFloat('0.000', d/1000000)+ms);
    lblPulse.Caption:=capPulse+tab1+'['+ms+']';
  end else begin
    if d>50000 then begin
      ledPuls.Caption:=fill(ledPuls.Columns, FormatFloat('0.000', d/1000)+mysled);
      lblPulse.Caption:=capPulse+tab1+'['+mys+']';
    end else begin
      if round(d)=0 then
        d:=1;
      ledPuls.Caption:=fill(ledPuls.Columns, IntToStr(round(d))+ns);
      lblPulse.Caption:=capPulse+tab1+'['+ns+']';
    end;
  end;

// Gpio Werte setzen
  SetPWMCycle(0, round(d));                              {Pulslänge duty_cycle an GPIO senden}
  if cbRevers.Checked then                               {Revers an GPIO senden}
    WriteSysFile(pathPWM+PWMchan0+frevers, keyrevers)
  else
    WriteSysFile(pathPWM+PWMchan0+frevers, keyNoRevers);
end;

procedure TForm1.SetFreq(const fi: int64);               {Anzeige und Ausgabe Frequenz}
var
  s: string;

begin
// Anzeigekram
  s:=IntToStr(fi)+'Hz';
  lblFreq.Caption:=capFreq+tab1+'['+hz+']';
  if fi>=1000 then begin
    s:=FormatFloat('0.000', fi/1000) +khz;
    lblFreq.Caption:=capFreq+tab1+'['+khz+']';
  end;
  if fi>=1000000 then begin
    s:=FormatFloat('0.000', fi/1000000) +mhz;
    lblFreq.Caption:=capFreq+tab1+'['+mhz+']';
  end;
  Caption:=capForm+tab1+s;
  ledFreq.Caption:=fill(ledFreq.Columns, s);

// GPIO Werte setzen
  SetPuls(fi);                                           {Erst Pulslänge berechnen und senden, damit sie nicht zu lang ist}
  SetPWMPeriod(0, 1000000000 div fi);                    {Frequenz --> Periode und an GPIO senden}
end;

procedure TForm1.knFreqChange(Sender: TObject; AValue: Longint);
begin                                                    {Frequenz Poti}
  if knFreq.Position=knFreq.Min then
    stepFreq.Position:=0;
  SetFreq(GetFreq);
end;

procedure TForm1.knPulseChange(Sender: TObject; AValue: Longint);
begin                                                    {Tastverhältnis Poti}
  stepPulse.Position:=knPulse.Position;
  SetPuls(GetFreq);
end;

procedure TForm1.rgFreqClick(Sender: TObject);           {Frequenzbereiche}
begin
  if rgFreq.ItemIndex=2 then
    knFreq.Max:=Fmax
  else
    knFreq.Max:=999;
  SetFreq(GetFreq);
end;

procedure TForm1.rgFstepClick(Sender: TObject);          {Schrittauswahl Frequenz}
begin
  case rgFstep.Itemindex of
    0: stepFreq.Increment:=1;
    1: stepFreq.Increment:=10;
    2: stepFreq.Increment:=100;
  end;
end;

procedure TForm1.rgPstepClick(Sender: TObject);          {Schrittauswahl Tastverhältnis}
begin
  case rgPstep.Itemindex of
    0: stepPulse.Increment:=1;
    1: stepPulse.Increment:=10;
    2: stepPulse.Increment:=100;
  end;
end;

procedure TForm1.stepFreqClick(Sender: TObject; Button: TUDBtnType);
var                                                       {Frequenz Up/Down}
  f: int64;
begin
  f:=GetFreq;
  if f<=1 then
    stepFreq.Position:=0;
  SetFreq(f);
end;

procedure TForm1.stepPulseClick(Sender: TObject; Button: TUDBtnType);
begin                                                    {Tastverhältnis Up/Down}
  knPulse.Position:=stepPulse.Position;
  SetPuls(GetFreq);
end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin                                                    {PWM0 ausschalten}
  DeactivatePWM;
end;

procedure TForm1.cbReversChange(Sender: TObject);        {Reversed PWM}
begin
  SetPuls(GetFreq);
end;

procedure TForm1.Button1Click(Sender: TObject);          {Tastverhältnis 1:1}
begin
  stepPulse.Position:=500;
  knPulse.Position:=stepPulse.Position;
end;

end.

