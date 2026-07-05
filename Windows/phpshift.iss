[Setup]
AppName=PHPShift
AppVersion=1.0.0
AppPublisher=PHPShift
AppPublisherURL=https://github.com/phpshift/PHPShift
WizardStyle=modern
DefaultDirName={autopf}\PHPShift
DisableProgramGroupPage=yes
DisableDirPage=yes
OutputBaseFilename=phpshift-v1.0.0
SetupIconFile=phpshift.ico
Uninstallable=no
PrivilegesRequired=admin
LicenseFile=terms.txt

[Files]
Source: "installer.ps1"; DestDir: "{tmp}"; Flags: ignoreversion
Source: "vsetup.code-profile"; DestDir: "{tmp}"; Flags: ignoreversion

[Code]
var
  LogMemo: TNewMemo;

{ 1. Create the integrated terminal UI }
procedure InitializeWizard;
begin
  LogMemo := TNewMemo.Create(WizardForm);
  LogMemo.Parent := WizardForm.InstallingPage;
  { Position it right beneath the progress bar }
  LogMemo.SetBounds(0, WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + 15, 
                    WizardForm.InstallingPage.ClientWidth, 
                    WizardForm.InstallingPage.ClientHeight - (WizardForm.ProgressGauge.Top + WizardForm.ProgressGauge.Height + 15));
  LogMemo.ScrollBars := ssVertical;
  LogMemo.ReadOnly := True;
  LogMemo.Color := clBlack;
  LogMemo.Font.Color := clWhite;
  LogMemo.Font.Name := 'Consolas';
  LogMemo.WordWrap := True;
end;

{ 2. The engine that catches PowerShell output and feeds it to the UI }
procedure RunPowerShellStep(StepName: String; StatusText: String);
var
  WshShell, WshExec: Variant;
  OutputLine: String;
  Cmd: String;
begin
  WizardForm.StatusLabel.Caption := StatusText;
  LogMemo.Lines.Add('');
  LogMemo.Lines.Add('==================================================');
  LogMemo.Lines.Add('>>> ' + StatusText);
  LogMemo.Lines.Add('==================================================');

  { Command forces standard error (2) into standard output (1) to catch all logs }
  Cmd := 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + ExpandConstant('{tmp}\installer.ps1') + '" -Step "' + StepName + '" -ProfilePath "' + ExpandConstant('{tmp}\vsetup.code-profile') + '"';

  try
    WshShell := CreateOleObject('WScript.Shell');
    WshExec := WshShell.Exec('cmd.exe /c "' + Cmd + ' 2>&1"');

    { Read stream while the process is actively running }
    while WshExec.Status = 0 do
    begin
      while not WshExec.StdOut.AtEndOfStream do
      begin
        OutputLine := WshExec.StdOut.ReadLine;
        LogMemo.Lines.Add(OutputLine);
        { Auto-scroll to the bottom of the log box }
        SendMessage(LogMemo.Handle, 277, 7, 0); 
      end;
      { Keep the main setup window from freezing }
      Sleep(50);
      WizardForm.Refresh;
    end;

    { Catch any leftover output after process terminates }
    while not WshExec.StdOut.AtEndOfStream do
    begin
      OutputLine := WshExec.StdOut.ReadLine;
      LogMemo.Lines.Add(OutputLine);
      SendMessage(LogMemo.Handle, 277, 7, 0);
    end;

  except
    LogMemo.Lines.Add('CRITICAL ERROR: Failed to execute ' + StepName);
  end;
end;

{ 3. The Orchestrator - Triggers during the actual installation phase }
procedure CurStepChanged(CurStep: TSetupStep);
var
  ProgressIncr: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    { Reset progress bar and set to increment in 8 chunks }
    WizardForm.ProgressGauge.Position := 0;
    WizardForm.ProgressGauge.Max := 100;
    ProgressIncr := 12; 

    RunPowerShellStep('choco-init', 'Initializing Package Manager...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('python', 'Installing Python 3.11...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('xampp', 'Installing XAMPP (PHP 8.1.25)...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('git', 'Installing Git...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('vscode', 'Installing Visual Studio Code...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('composer', 'Installing Composer...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('pip', 'Installing PHPShift Framework Modules...');
    WizardForm.ProgressGauge.Position := WizardForm.ProgressGauge.Position + ProgressIncr;

    RunPowerShellStep('profile', 'Applying Custom Development Profile...');
    WizardForm.ProgressGauge.Position := 100;

    LogMemo.Lines.Add('');
    LogMemo.Lines.Add('==================================================');
    LogMemo.Lines.Add('SUCCESS: PHPShift is ready to use!');
    LogMemo.Lines.Add('==================================================');
    WizardForm.StatusLabel.Caption := 'Installation Complete!';
    
    { Give the user 1.5 seconds to see 100% completion before moving to finish screen }
    Sleep(1500); 
  end;
end;