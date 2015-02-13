{
  *******************************************************************
  AUTHOR : Flakron Shkodra 2011
  *******************************************************************
}

unit SqlExecThread;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, DB, sqldb, mssqlconn, SQLDBLaz, AsDbType, strutils,ZDataset,syncobjs;

type

  { TSqlExecThread }

  TOnSqlExecThreadFinish = procedure(Sender: TObject; IsTableData:boolean) of object;

  TSqlExecThread = class(TThread)
  private
    FLock:TCriticalSection;
    FExecutionTime: TTime;
    FExecuteAsThread: boolean;
    FLastError: string;
    FMessage: string;
    FOnFinish: TOnSqlExecThreadFinish;
    FQuery: TAsQuery;
    FRecordCount: word;
    FSchema: string;
    FActive: boolean;
    FCommand: string;
    FTablenameAssigned:Boolean;
    FIsSelect:Boolean;
    function GetIsTerminated: Boolean;
    function GetOriginalQuery: string;
    procedure SetDurationTime(AValue: TTime);
    procedure SetExecuteAsThread(AValue: boolean);
    procedure SetLastError(AValue: string);
    procedure SetMessage(AValue: string);
    procedure SetOnFinish(AValue: TOnSqlExecThreadFinish);
    procedure SetRecordCount(AValue: word);
  protected
    procedure Execute; override;
    procedure SqlExecute;
  public


    constructor Create(Schema: string; const sqlQuery: TAsQuery; OnFinish: TOnSqlExecThreadFinish);
    property Active: boolean read FActive;
    property LastError: string read FLastError write SetLastError;
    procedure ExecuteSQL(sqlCommand: string; TableData:Boolean);
    property ExecuteAsThread: boolean read FExecuteAsThread write SetExecuteAsThread;
    property ExecutionTime: TTime read FExecutionTime;
    property RecordCount: word read FRecordCount;
    property OnFinish: TOnSqlExecThreadFinish read FOnFinish write SetOnFinish;
    property Message: string read FMessage write SetMessage;
    property IsSelect:Boolean read FIsSelect;
    property IsTerminated:Boolean read GetIsTerminated;
    destructor Destroy; override;

  end;

implementation

uses AsSqlParser;

{ TSqlExecThread }

function IsUTF8String(S: string): boolean;
var
  WS: WideString;
begin
  WS := UTF8Decode(S);
  Result := (WS <> S) and (WS <> '');
end;


procedure TSqlExecThread.SetMessage(AValue: string);
begin
  if FMessage = AValue then
    Exit;
  FMessage := AValue;
end;

procedure TSqlExecThread.SetLastError(AValue: string);
begin
  if FLastError = AValue then
    Exit;
  FLastError := AValue;
end;

function TSqlExecThread.GetOriginalQuery: string;
begin
  Result := FCommand;
end;

function TSqlExecThread.GetIsTerminated: Boolean;
begin
 Result := Terminated;
end;


procedure TSqlExecThread.SetDurationTime(AValue: TTime);
begin
  if FExecutionTime = AValue then
    Exit;
  FExecutionTime := AValue;
end;

procedure TSqlExecThread.SetExecuteAsThread(AValue: boolean);
begin
  if FExecuteAsThread = AValue then
    Exit;
  FExecuteAsThread := AValue;
end;


procedure TSqlExecThread.SetOnFinish(AValue: TOnSqlExecThreadFinish);
begin
  if FOnFinish = AValue then
    Exit;
  FOnFinish := AValue;
end;


procedure TSqlExecThread.SetRecordCount(AValue: word);
begin
  if FRecordCount = AValue then
    Exit;
  FRecordCount := AValue;
end;

procedure TSqlExecThread.Execute;
begin
  FLastError := EmptyStr;
  FActive := True;
  try
    try
      SqlExecute;
    except
      on e: Exception do
      begin
        FLastError := e.Message;
      end;
    end;

    if Assigned(FOnFinish) then
      FOnFinish(Self, FTablenameAssigned);
  finally
    FActive := False;
  end;
end;

procedure TSqlExecThread.SqlExecute;
var
  I: integer;
  tmpCommand: string;
  t1: TTime;
  Handled: boolean;
  c:Boolean;
  affected:Integer;
begin
  //FLock.Acquire; //fails with zeos components
  try
   FIsSelect:=AnsiContainsText(Lowercase(FCommand),'select');
   try
     FLastError := '';
     c := (FQuery<>nil);

     if not c then
     begin
       FLastError:='Internal FQuery not assigned';
       FOnFinish(Self,FTablenameAssigned);
       Exit;
     end;

     Sleep(300);

     t1 := Time;

     if not FIsSelect then
     begin
       if Assigned(FQuery) then
       begin
        FQuery.Close;
        FQuery.SQL.Text := FCommand;
        FQuery.ExecSQL;
        affected:=FQuery.RowsAffected;
       end;
       FExecutionTime := Time - t1;
       FMessage := 'Command successfully executed. Rows affected (' +IntToStr(affected) + ')';
     end
     else
     begin
       if Assigned(FQuery) then
       begin
         FQuery.Close;
         FQuery.SQL.Text:=FCommand;
         FQuery.PacketRecords:=-1;
         FQuery.Open;
         FRecordCount := FQuery.RecordCount;
       end;
       FExecutionTime:= Time-t1;
       FMessage := 'Execution time [' + TimeToStr(Time-t1) + '] Records [' +
         IntToStr(FRecordCount) + ']';
     end;
   except
     on e: Exception do
     begin
       FLastError := e.Message;
     end;
   end;

  finally
  //  FLock.Release;
  end;

end;

constructor TSqlExecThread.Create(Schema: string; const sqlQuery: TAsQuery;
 OnFinish: TOnSqlExecThreadFinish);
begin
  FLock := TCriticalSection.Create;
  FSchema := Schema;
  FQuery := sqlQuery;
  FExecuteAsThread := True;
  FOnFinish := OnFinish;
  inherited Create(True);
  inherited FreeOnTerminate:=True;
end;

procedure TSqlExecThread.ExecuteSQL(sqlCommand: string; TableData: Boolean);
begin
  FtableNameAssigned:=TableData;
  if Trim(sqlCommand) <> EmptyStr then
    FCommand := sqlCommand
  else
  begin
    raise Exception.Create('No SqlCommand');
  end;

  if FExecuteAsThread then
  begin
    inherited Start;
  end
  else
  begin
    SqlExecute;
  end;

end;

destructor TSqlExecThread.Destroy;
begin
  FLock.Free;
  inherited Destroy;
end;

end.
