program concurrencyds;

{$Mode ObjFpc}
{$H+}
{$define DEBUGHEAP}

uses
{$ifdef DEBUGHEAP}
  Heaptrc,
{$endif}
{$ifdef Linux}
  cmem,
{$endif}
  sysutils,sqlite3ds, inifiles;
  
const
  SQLITEDS_TESTS_INI_FILE = 'sqlitedstests.ini';
  DEFAULT_TABLENAME = 'tabletest';
  DEFAULT_FILENAME = 'test.db';

  FieldNames: array [0..10] of String =
  (
  'Integer',
  'String',
  'Boolean',
  'Float',
  'Word',
  'Date',
  'DateTime',
  'Time',
  'LargeInt',
  'AutoInc',
  'Currency'  
  );

var
  dsArray: array [0..10] of TSqlite3Dataset;
  ini:TIniFile;
  i: Integer;

begin
  {$ifdef DEBUGHEAP}
  SetHeapTraceOutput(ExtractFileName(ParamStr(0))+'.heap.log');
  {$endif}
  ini:=TIniFile.Create(SQLITEDS_TESTS_INI_FILE);
  for i:= 0 to 10 do
  begin
    dsArray[i] := TSqlite3Dataset.Create(nil);
    with dsArray[i] do
    begin
      FileName:=ini.ReadString('testinfo','filename',DEFAULT_FILENAME);
      TableName:=ini.ReadString('testinfo','tablename',DEFAULT_TABLENAME);
      //Each dataset will retrieve only one field of the same table
      Sql:='Select '+FieldNames[i]+ ' from '+ TableName;
      Open;
      WriteLn('Value of Field ',FieldNames[i],' : ',FieldByName(FieldNames[i]).AsString);
    end;
  end;
  ini.Destroy;
  for i:= 0 to 10 do
    dsArray[i].Destroy;
end.
