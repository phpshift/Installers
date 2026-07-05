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
Source: "core-installer.ps1"; DestDir: "{tmp}"; Flags: ignoreversion
; Extract the profile permanently to the install directory so VS Code has time to read it
Source: "vsetup.code-profile"; DestDir: "{app}"; Flags: ignoreversion

[Code]
var
  LogMemo: TNewMemo;

procedure InitializeWizard;
begin
  LogMemo := TNewMemo.Create(WizardForm);
  LogMemo.Parent := WizardForm.InstallingPage;
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

  Cmd := 'powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File "' + ExpandConstant('{tmp}\core-installer.ps1') + '" -Step "' + StepName + '"';

  try
    WshShell := CreateOleObject('WScript.Shell');
    WshExec := WshShell.Exec('cmd.exe /c "' + Cmd + ' 2>&1"');

    while WshExec.Status = 0 do
    begin
      while not WshExec.StdOut.AtEndOfStream do
      begin
        OutputLine := WshExec.StdOut.ReadLine;
        LogMemo.Lines.Add(OutputLine);
        SendMessage(LogMemo.Handle, 277, 7, 0); 
      end;
      Sleep(50);
      WizardForm.Refresh;
    end;

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

procedure CurStepChanged(CurStep: TSetupStep);
var
  ProgressIncr: Integer;
  CodePath: String;
  ResultCode: Integer;
begin
  if CurStep = ssPostInstall then
  begin
    WizardForm.ProgressGauge.Position := 0;
    WizardForm.ProgressGauge.Max := 100;
    ProgressIncr := 14; 

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
    WizardForm.ProgressGauge.Position := 95;

    { ------------------------------------------------------------------------- }
    { VS CODE PROFILE IMPORT (RUN AS NORMAL USER TO BYPASS ADMIN RESTRICTIONS) }
    { ------------------------------------------------------------------------- }
    WizardForm.StatusLabel.Caption := 'Applying Custom Development Profile...';
    LogMemo.Lines.Add('');
    LogMemo.Lines.Add('==================================================');
    LogMemo.Lines.Add('>>> Applying Custom Development Profile...');
    LogMemo.Lines.Add('==================================================');

    { Locate the absolute path to the newly installed VS Code }
    CodePath := ExpandConstant('{pf64}\Microsoft VS Code\bin\code.cmd');
    if not FileExists(CodePath) then
      CodePath := ExpandConstant('{pf32}\Microsoft VS Code\bin\code.cmd');
    if not FileExists(CodePath) then
      CodePath := ExpandConstant('{localappdata}\Programs\Microsoft VS Code\bin\code.cmd');

    if FileExists(CodePath) then
    begin
      { ExecAsOriginalUser strips the Administrator privileges away just for this command so VS Code accepts it }
      if ExecAsOriginalUser(CodePath, '--install-profile "' + ExpandConstant('{app}\vsetup.code-profile') + '"', '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
        LogMemo.Lines.Add('VS Code profile command issued successfully.')
      else
        LogMemo.Lines.Add('WARNING: Profile import command failed to execute.');
    end
    else
    begin
      LogMemo.Lines.Add('CRITICAL ERROR: Could not locate VS Code executable.');
    end;

    WizardForm.ProgressGauge.Position := 100;

    LogMemo.Lines.Add('');
    LogMemo.Lines.Add('==================================================');
    LogMemo.Lines.Add('SUCCESS: PHPShift is ready to use!');
    LogMemo.Lines.Add('==================================================');
    WizardForm.StatusLabel.Caption := 'Installation Complete!';
    
    Sleep(1500); 
  end;
end;
