{$mode objfpc}
{$h+}
unit fpjsondataset;

interface

uses
  DB, typinfo, Classes, SysUtils, fpjson;

type
  // How are rows encoded in the JSON ?
  TJSONRowType = (rtJSONObject, // Each row is an object.
                  rtJSONArray   // Each row is an array.
                  );

  { TJSONFieldMapper }

  // This class is responsible for mapping the field objects of the records.
  TJSONFieldMapper = Class(TObject)
    // Return row TJSONData instance with data for field 'FieldName' or 'FieldIndex'.
    Function GetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row : TJSONData) : TJSONData; virtual; abstract;
    // Same, but now based on TField.
    Function GetJSONDataForField(F : TField; Row : TJSONData) : TJSONData; virtual;
    // Set data for field 'FieldName' or 'FieldIndex' to supplied TJSONData instance in row
    procedure SetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row,Data : TJSONData); virtual; abstract;
    // Set data for field TField to supplied TJSONData instance
    procedure SetJSONDataForField(F : TField; Row,Data : TJSONData); virtual;
    // Create a new row.
    Function CreateRow : TJSONData; virtual; abstract;
  end;

  // JSON has no date/time type, so we use a string field.
  // ExtJS provides the date/time  format in it's field config: 'dateFormat'
  // The below field classes store this in the NNNFormat field.
  { TJSONDateField }

  TJSONDateField = Class(TDateField)
  private
    FDateFormat: String;
  Published
    Property DateFormat : String Read FDateFormat Write FDateFormat;
  end;

  { TJSONTimeField }

  TJSONTimeField = Class(TTimeField)
  private
    FTimeFormat: String;
  Published
    Property TimeFormat : String Read FTimeFormat Write FTimeFormat;
  end;

  { TJSONDateTimeField }

  TJSONDateTimeField = Class(TDateTimeField)
  private
    FDateTimeFormat: String;
  Published
    Property DateTimeFormat : String Read FDateTimeFormat Write FDateTimeFormat;
  end;

  { TJSONIndex }

  TJSONIndex = Class
    FList : TFPList; // Indexes of elements in FRows. Not pointers
    FRows : TJSONArray;
    FDataset : TDataset;
  private
    function GetRecordIndex(aListIndex : Integer): NativeInt;
  protected
    Function GetCount: Integer; virtual;
    Procedure CreateIndex; Virtual; abstract;
    Property List : TFPList Read FList;
    Property Rows : TJSONArray Read FRows;
    Property Dataset : TDataset Read FDataset;
  Public
    Constructor Create(aDataset: TDataset; aRows : TJSONArray); reintroduce;
    Destructor Destroy; override;
    // Append remainder of FRows to FList.
    Procedure AppendToIndex; virtual; abstract;
    // Delete aListIndex from list, not from row. Return Recordindex of deleted record.
    Function Delete(aListIndex : Integer) : NativeInt; virtual;
    // Append aRecordIndex to list. Return ListIndex of appended record.
    Function Append(aRecordIndex : Integer) : NativeInt; virtual; abstract;
    // Insert record into list. By default, this does an append. Return ListIndex of inserted record
    Function Insert(aCurrentIndex{%H-}, aRecordIndex : Integer) : NativeInt; virtual;
    // Record at index aCurrentIndex has changed. Update index and return new listindex.
    Function Update(aCurrentIndex, aRecordIndex : Integer) : NativeInt; virtual; abstract;
    // Find list index for Record at index aCurrentIndex. Return -1 if not found.
    Function FindRecord(aRecordIndex : Integer) : NativeInt; virtual; abstract;
    // index of record in FRows based on aListIndex in List.
    Property RecordIndex[aListIndex : Integer] : NativeInt Read GetRecordIndex;default;
    // Number of records in index. This can differ from FRows, e.g. when filtering.
    Property Count : Integer Read GetCount;
  end;

  { TDefaultJSONIndex }

  TDefaultJSONIndex = Class(TJSONIndex)
  public
    Procedure CreateIndex; override;
    Procedure AppendToIndex; override;
    Function Append(aRecordIndex : Integer) : NativeInt; override;
    Function Insert(aCurrentIndex, aRecordIndex : Integer) : NativeInt; override;
    Function FindRecord(aRecordIndex : Integer) : NativeInt; override;
    Function Update(aCurrentIndex, aRecordIndex : Integer) : NativeInt; override;
  end;

  { TBaseJSONDataSet }

  // basic JSON dataset. Does nothing ExtJS specific.
  TBaseJSONDataSet = class (TDataSet)
  private
    FMUS: Boolean;
    FOwnsData : Boolean;
    FDefaultIndex : TJSONIndex; // Default index, built from array
    FCurrentIndex : TJSONIndex; // Currently active index.
    FCurrent: Integer; // Record Index in the current IndexList
    FRecordSize: Integer;
    // Possible metadata to configure fields from.
    FMetaData : TJSONObject;
    // This will contain the rows.
    FRows : TJSONArray;
    FFieldMapper : TJSONFieldMapper;
    // When editing, this object is edited.
    FEditIdx : Integer;
    FEditRow : TJSONData;
    FRowType: TJSONRowType;
    FDeletedRows: TFPList;
    procedure AddToRows(AValue: TJSONArray);
    procedure AppendToIndexes;
    procedure CreateIndexes;
    procedure SetMetaData(AValue: TJSONObject);
    procedure SetRows(AValue: TJSONArray);
    procedure SetRowType(AValue: TJSONRowType);
  protected
    // dataset virtual methods
    function AllocRecordBuffer: TRecordBuffer; override;
    procedure FreeRecordBuffer(var Buffer: TRecordBuffer); override;
    procedure InternalInitRecord(Buffer: TRecordBuffer); override;
    procedure GetBookmarkData(Buffer: TRecordBuffer; Data: Pointer); override;
    function GetBookmarkFlag(Buffer: TRecordBuffer): TBookmarkFlag; override;
    function GetRecord(Buffer: TRecordBuffer; GetMode: TGetMode; DoCheck: Boolean): TGetResult; override;
    function GetRecordSize: Word; override;
    procedure InternalClose; override;
    procedure InternalDelete; override;
    procedure InternalFirst; override;
    procedure InternalGotoBookmark(ABookmark: Pointer); override;
    procedure InternalLast; override;
    procedure InternalOpen; override;
    procedure InternalPost; override;
    procedure InternalInsert; override;
    procedure InternalEdit; override;
    procedure InternalCancel; override;
    procedure InternalInitFieldDefs; override;
    procedure InternalSetToRecord(Buffer: TRecordBuffer); override;
    function  GetFieldClass(FieldType: TFieldType): TFieldClass; override;
    function IsCursorOpen: Boolean; override;
    procedure SetBookmarkFlag(Buffer: TRecordBuffer; Value: TBookmarkFlag); override;
    procedure SetBookmarkData(Buffer: TRecordBuffer; Data: Pointer); override;
    function GetRecordCount: Integer; override;
    procedure SetRecNo(Value: Integer); override;
    function GetRecNo: Integer; override;
  Protected
    // New methods.
    // Called when dataset is closed. If OwnsData is true, metadata and rows are freed.
    Procedure FreeData; virtual;
    // Convert MetaData object to FieldDefs.
    Procedure MetaDataToFieldDefs; virtual; abstract;
    // Initialize Date/Time info in all date/time fields. Called during InternalOpen
    procedure InitDateTimeFields; virtual;
    // Convert JSON date S to DateTime for Field F
    function ConvertDateTimeField(S: String; F: TField): TDateTime; virtual;
    // Format JSON date to from DT for Field F
    function FormatDateTimeField(DT : TDateTime; F: TField): String; virtual;
    // Create fieldmapper. A descendent MUST implement this.
    Function CreateFieldMapper : TJSONFieldMapper; virtual;
    // If True, then the dataset will free MetaData and FRows when it is closed.

    Property OwnsData : Boolean Read FownsData Write FOwnsData;
    // set to true if unknown field types should be handled as string fields.
    Property MapUnknownToStringType : Boolean Read FMUS Write FMUS;
    // Metadata
    Property MetaData : TJSONObject Read FMetaData Write SetMetaData;
    // Rows
    Property Rows : TJSONArray Read FRows Write SetRows;
    // RowType
    Property RowType : TJSONRowType Read FRowType Write SetRowType;
    // FieldMapper
    Property FieldMapper : TJSONFieldMapper Read FFieldMapper;
  public
    constructor Create (AOwner: TComponent); override;
    destructor Destroy; override;
    function GetFieldData(Field: TField; Buffer: Pointer; NativeFormat : Boolean): Boolean; override;
    procedure SetFieldData(Field: TField; Buffer: Pointer; NativeFormat : Boolean); override;
    function BookmarkValid(ABookmark: TBookmark): Boolean; override;
    function CompareBookmarks(Bookmark1, Bookmark2: TBookmark): Longint; override;
  published
    Property FieldDefs;
    // redeclared data set properties
    property Active;
    property BeforeOpen;
    property AfterOpen;
    property BeforeClose;
    property AfterClose;
    property BeforeInsert;
    property AfterInsert;
    property BeforeEdit;
    property AfterEdit;
    property BeforePost;
    property AfterPost;
    property BeforeCancel;
    property AfterCancel;
    property BeforeDelete;
    property AfterDelete;
    property BeforeScroll;
    property AfterScroll;
    property OnCalcFields;
    property OnDeleteError;
    property OnEditError;
    property OnFilterRecord;
    property OnNewRecord;
    property OnPostError;
  end;

  TJSONDataSet = CLass(TBaseJSONDataSet)
  Public
    Property Rows;
    Property RowType;
    Property OwnsData;
    Property MapUnknownToStringType;
  end;

  { TJSONObjectFieldMapper }
  // Fieldmapper to be used when the data is in an object
  TJSONObjectFieldMapper = Class(TJSONFieldMapper)
    procedure SetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row,Data : TJSONData); override;
    Function GetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row : TJSONData) : TJSONData; override;
    Function CreateRow : TJSONData; override;
  end;

  { TJSONArrayFieldMapper }
  // Fieldmapper to be used when the data is in an array
  TJSONArrayFieldMapper = Class(TJSONFieldMapper)
    procedure SetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row,Data : TJSONData); override;
    Function GetJSONDataForField(Const FieldName : String; FieldIndex : Integer; Row : TJSONData) : TJSONData; override;
    Function CreateRow : TJSONData; override;
  end;

  EJSONDataset = Class(EDatabaseError);
  
implementation

uses dateutils, jsonparser;

{ TDefaultJSONIndex }


procedure TDefaultJSONIndex.CreateIndex;


begin
  FList.Clear;
  FList.Capacity:=FRows.Count;
  AppendToIndex;
end;

procedure TDefaultJSONIndex.AppendToIndex;

Var
  I,L : Integer;

begin
  L:=List.Count;
  For I:=L to FRows.Count-1 do
    FList.Add(Pointer(PtrUInt(I)));
end;

function TDefaultJSONIndex.Append(aRecordIndex: Integer): NativeInt;
begin
  Result:=FList.Add(PNativeInt(aRecordIndex));
end;

function TDefaultJSONIndex.Insert(aCurrentIndex, aRecordIndex: Integer): NativeInt;
begin
  FList.Insert(aCurrentIndex,PNativeInt(aRecordIndex));
  Result:=aCurrentIndex;
end;

function TDefaultJSONIndex.FindRecord(aRecordIndex: Integer): NativeInt;
begin
  Result:=FList.indexOf(PNativeInt(aRecordIndex));
end;

function TDefaultJSONIndex.Update(aCurrentIndex, aRecordIndex: Integer ): NativeInt;
begin
  Result:=0;
  If RecordIndex[aCurrentIndex]<>aRecordIndex then
    DatabaseErrorFmt('Inconsistent record index in default index, expected %d, got %d.',[aCurrentIndex,RecordIndex[aCurrentIndex]],Dataset);
end;

{ TJSONIndex }

constructor TJSONIndex.Create(aDataset: TDataset; aRows: TJSONArray);
begin
  FRows:=aRows;
  FList:=TFPList.Create;
  FDataset:=aDataset;
  CreateIndex;
end;

destructor TJSONIndex.Destroy;
begin
  FreeAndNil(FList);
  inherited Destroy;
end;

function TJSONIndex.Delete(aListIndex: Integer): NativeInt;


begin
  Result:=NativeInt(FList[aListIndex]);
  FList.Delete(aListindex);
end;

function TJSONIndex.Insert(aCurrentIndex, aRecordIndex: Integer): NativeInt;
begin
  Result:=Append(aRecordIndex);
end;

function TJSONIndex.GetCount: Integer;
begin
  Result:=FList.Count;
end;

function TJSONIndex.GetRecordIndex(aListIndex : Integer): NativeInt;
begin
  // Can be -1
  Result:=NativeInt(FList[aListIndex]);
end;

type
  PRecInfo = ^TRecInfo;
  TRecInfo = record
    IndexIndex : Integer;
    RowIndex: NativeInt;
    BookmarkFlag: TBookmarkFlag;
  end;


{ TJSONFieldMapper }

function TJSONFieldMapper.GetJSONDataForField(F: TField; Row: TJSONData
  ): TJSONData;
begin
  // This supposes that Index is correct, i.e. the field positions have not been changed.
  Result:=GetJSONDataForField(F.FieldName,F.Index,Row);
end;

procedure TJSONFieldMapper.SetJSONDataForField(F: TField; Row,Data: TJSONData);
begin
  SetJSONDataForField(F.FieldName,F.Index,Row,Data);
end;


{ TJSONArrayFieldMapper }

procedure TJSONArrayFieldMapper.SetJSONDataForField(const FieldName: String;
  FieldIndex: Integer; Row, Data: TJSONData);
begin
  (Row as TJSONArray).Items[FieldIndex]:=Data;
end;

function TJSONArrayFieldMapper.GetJSONDataForField(Const FieldName: String;
  FieldIndex: Integer; Row: TJSONData): TJSONData;
begin
  Result:=(Row as TJSONArray).Items[FieldIndex];
end;

function TJSONArrayFieldMapper.CreateRow: TJSONData;
begin
  Result:=TJSONArray.Create;
end;

{ TJSONObjectFieldMapper }

procedure TJSONObjectFieldMapper.SetJSONDataForField(const FieldName: String;
  FieldIndex: Integer; Row, Data: TJSONData);
begin
  (Row as TJSONObject).Elements[FieldName]:=Data;
end;

function TJSONObjectFieldMapper.GetJSONDataForField(const FieldName: String;
  FieldIndex: Integer; Row: TJSONData): TJSONData;
begin
  Result:=(Row as TJSONObject).Find(FieldName);
end;

function TJSONObjectFieldMapper.CreateRow: TJSONData;
begin
  Result:=TJSONObject.Create;
end;

procedure TBaseJSONDataSet.SetMetaData(AValue: TJSONObject);
begin
  CheckInActive;
  if FMetaData=AValue then
    Exit;
  If OwnsData then
    FreeAndNil(FMetaData);
  FMetaData:=AValue;
end;

procedure TBaseJSONDataSet.AppendToIndexes;

begin
  FDefaultIndex.AppendToIndex;
end;

procedure TBaseJSONDataSet.CreateIndexes;

begin
  FDefaultIndex:=TDefaultJSONIndex.Create(Self,FRows);
  AppendToIndexes;
  FCurrentIndex:=FDefaultIndex;
end;

procedure TBaseJSONDataSet.AddToRows(AValue: TJSONArray);

Var
  D : TJSONEnum;

begin
  if FRows=Nil then
    FRows:=AValue
  else
    begin
    for D in AValue do
      FRows.Add(D.Value.Clone);
    AppendToIndexes;
    end;
end;

procedure TBaseJSONDataSet.SetRows(AValue: TJSONArray);
begin
  CheckInActive;
  if FRows=AValue then Exit;
  If OwnsData then
    FreeAndNil(FRows);
  AddToRows(AValue);
end;

procedure TBaseJSONDataSet.SetRowType(AValue: TJSONRowType);
begin
  if FRowType=AValue then Exit;
  CheckInactive;
  FRowType:=AValue;
end;

function TBaseJSONDataSet.AllocRecordBuffer: TRecordBuffer;
begin
  Result := TRecordBuffer(StrAlloc(fRecordSize));
end;

// the next two are particularly ugly.
procedure TBaseJSONDataSet.InternalInitRecord(Buffer: TRecordBuffer);
begin
  FillChar(Buffer^, FRecordSize, 0);
  PRecInfo(Buffer)^.IndexIndex:=-1;
  PRecInfo(Buffer)^.RowIndex:=-1;
end;

procedure TBaseJSONDataSet.FreeRecordBuffer (var Buffer: TRecordBuffer);
begin
  StrDispose(pansichar(Buffer));
end;

procedure TBaseJSONDataSet.GetBookmarkData(Buffer: TRecordBuffer; Data: Pointer);
begin
  PNativeInt(Data)^ := PRecInfo(Buffer)^.RowIndex;
end;

function TBaseJSONDataSet.GetBookmarkFlag(Buffer: TRecordBuffer): TBookmarkFlag;
begin
  Result := PRecInfo(Buffer)^.BookmarkFlag;
end;

function TBaseJSONDataSet.GetRecNo: Integer;
begin
  Result := FCurrent + 1;
end;

procedure TBaseJSONDataSet.InternalInitFieldDefs;
begin
  If Assigned(FMetaData) then
    MetaDataToFieldDefs;
  if (FieldDefs.Count=0) then
    Raise EJSONDataset.Create('No fields found');
end;

procedure TBaseJSONDataSet.FreeData;

Var
  I : Integer;

begin
  If FOwnsData then
    begin
    FreeAndNil(FRows);
    FreeAndNil(FMetaData);
    if Assigned(FDeletedRows) then
      For I:=0 to FDeletedRows.Count-1 do
        TJSONData(FDeletedRows[i]).Free;
    end;
  if (FCurrentIndex<>FDefaultIndex) then
    FreeAndNil(FCurrentIndex)
  else
    FCurrentIndex:=Nil;
  FreeAndNil(FDefaultIndex);
  FreeAndNil(FFieldMapper);
  FCurrentIndex:=Nil;
  FreeAndNil(FDeletedRows);
end;


function TBaseJSONDataSet.GetRecord(Buffer: TRecordBuffer; GetMode: TGetMode;
  DoCheck: Boolean): TGetResult;
begin
  Result := grOK; // default
  case GetMode of
    gmNext: // move on
      if fCurrent < FCurrentIndex.Count - 1 then
        Inc (fCurrent)
      else
        Result := grEOF; // end of file
    gmPrior: // move back
      if fCurrent > 0 then
        Dec (fCurrent)
      else
        Result := grBOF; // begin of file
    gmCurrent: // check if empty
      if fCurrent >= FCurrentIndex.Count then
        Result := grEOF;
  end;
  if Result = grOK then // read the data
    with PRecInfo(Buffer)^ do
      begin
      IndexIndex:=FCurrent;
      RowIndex:= FCurrentIndex.RecordIndex[FCurrent];
      BookmarkFlag := bfCurrent;
      CalculateFields(Buffer);
      end;
end;

function TBaseJSONDataSet.GetRecordCount: Integer;
begin
  Result := FCurrentIndex.Count;
end;

function TBaseJSONDataSet.GetRecordSize: Word;
begin
  Result := SizeOf(Integer); // actual data without house-keeping
end;


procedure TBaseJSONDataSet.InternalClose;
begin
  // disconnet and destroy field objects
  BindFields (False);
  if DefaultFields then
    DestroyFields;
  FreeData;
end;

procedure TBaseJSONDataSet.InternalDelete;

Var
  Idx : Integer;

begin
  Idx:=FCurrentIndex.Delete(FCurrent);
  if (Idx<>-1) then
    begin
    // Add code here to Delete from other indexes as well.
    // ...
    // Extract from rows and  to array of deleted records.
    if Not Assigned(FDeletedRows) then
      FDeletedRows:=TFPList.Create;
    FDeletedRows.Add(FRows.Extract(Idx));
    FRows.Insert(Idx);  // insert null
    end;
end;

procedure TBaseJSONDataSet.InternalFirst;
begin
  FCurrent := -1;
end;

procedure TBaseJSONDataSet.InternalGotoBookmark(ABookmark: Pointer);

Var
  Idx : Integer;

begin
  if (ABookmark <> nil) then
    begin
    idx:=FCurrentIndex.FindRecord(PNativeInt(ABookmark)^);
    if (idx<>-1) then
      FCurrent:=idx;
    end;
end;

procedure TBaseJSONDataSet.InternalInsert;

Var
  I : Integer;
  D : TFieldDef;

begin
  FEditIdx:=-1;
  FEditRow:=FFieldMapper.CreateRow;
  For I:=0 to FieldDefs.Count-1 do
    begin
    D:=FieldDefs[i];
    FFieldMapper.SetJSONDataForField(D.Name,D.Index,FEditRow,TJSONNull.Create);
    end;
end;

procedure TBaseJSONDataSet.InternalEdit;
begin
  FEditIdx:=FCurrentIndex.RecordIndex[FCurrent];
  if (Rows[FEditIdx]<>Nil) and Not (Rows[FEditIdx] is TJSONNull) then
    FEditRow:=Rows[FEditIdx].Clone
  else
    FEditRow:=TJSONObject.Create;
end;

procedure TBaseJSONDataSet.InternalCancel;
begin
  FEditIdx:=-1;
  FreeAndNil(FEditRow);
end;

procedure TBaseJSONDataSet.InternalLast;
begin
  FCurrent:=FCurrentIndex.Count;
end;

procedure TBaseJSONDataSet.InitDateTimeFields;

begin
  // Do nothing
end;

procedure TBaseJSONDataSet.InternalOpen;
begin
  FreeAndNil(FFieldMapper);
  FFieldMapper:=CreateFieldMapper;
  IF (FRows=Nil) then // opening from fielddefs ?
    begin
    FRows:=TJSONArray.Create;
    OwnsData:=True;
    end;
  CreateIndexes;
  InternalInitFieldDefs;
  if DefaultFields then
    CreateFields;
  BindFields (True);
  InitDateTimeFields;
  FCurrent := -1;
  FRecordSize := sizeof (TRecInfo);
  BookmarkSize := sizeOf (NativeInt);
end;

procedure TBaseJSONDataSet.InternalPost;

Var
  Idx : NativeInt;

begin
  GetBookMarkData(ActiveBuffer,@Idx);
  if (State=dsInsert) then
    begin // Insert or Append
    Idx:=FRows.Add(FEditRow);
    if GetBookMarkFlag(ActiveBuffer)=bfEOF then
      begin // Append
      FDefaultIndex.Append(Idx);
      // Must replace this by updating all indexes
      if (FCurrentIndex<>FDefaultIndex) then
        FCurrentIndex.Append(Idx);
      end
    else  // insert
      begin
      FCurrent:=FDefaultIndex.Insert(FCurrent,Idx);
      // Must replace this by updating all indexes.
      // Note that this will change current index.
      if (FCurrentIndex<>FDefaultIndex) then
        FCurrent:=FCurrentIndex.Insert(FCurrent,Idx);
      end;
    end
  else
    begin // Edit
    if (FEditIdx=-1) then
      DatabaseErrorFmt('Failed to retrieve record index for record %d',[FCurrent]);
    // Update source record
    Idx:=FEditIdx;
    FRows[Idx]:=FEditRow;
    FDefaultIndex.Update(FCurrent,Idx);
    // Must replace this by updating all indexes.
    // Note that this will change current index.
    if (FCurrentIndex<>FDefaultIndex) then
      FCurrentIndex.Update(FCurrent,Idx);
    end;
  FEditIdx:=-1;
  FEditRow:=Nil;
end;

procedure TBaseJSONDataSet.InternalSetToRecord(Buffer: TRecordBuffer);
begin
  FCurrent:=FCurrentIndex.FindRecord(PRecInfo(Buffer)^.RowIndex);
end;

function TBaseJSONDataSet.GetFieldClass(FieldType: TFieldType): TFieldClass;
begin
  case FieldType of
    ftDate : Result:=TJSONDateField;
    ftDateTime : Result:=TJSONDateTimeField;
    ftTime : Result:=TJSONTimeField;
  else
    Result:=inherited GetFieldClass(FieldType);
  end;
end;

function TBaseJSONDataSet.IsCursorOpen: Boolean;
begin
  Result := Assigned(FDefaultIndex);
end;

procedure TBaseJSONDataSet.SetBookmarkData(Buffer: TRecordBuffer; Data: Pointer);
begin
  PRecInfo(Buffer)^.RowIndex := PNativeInt(Data)^;
end;

function TBaseJSONDataSet.ConvertDateTimeField(S : String; F : TField) : TDateTime;

Var
  Ptrn : string;

begin
  Result:=0;
  Case F.DataType of
    ftDate : Ptrn:=TJSONDateField(F).DateFormat;
    ftTime : Ptrn:=TJSONTimeField(F).TimeFormat;
    ftDateTime : Ptrn:=TJSONDateTimeField(F).DateTimeFormat;
  end;
  If (Ptrn='') then
    Case F.DataType of
      ftDate : Result:=StrToDate(S);
      ftTime : Result:=StrToTime(S);
      ftDateTime : Result:=StrToDateTime(S);
    end
  else
    begin
    Result:=ScanDateTime(ptrn,S,1);
    end;
end;

function TBaseJSONDataSet.FormatDateTimeField(DT: TDateTime; F: TField
  ): String;

Var
  Ptrn : string;
begin
  Result:='';
  Case F.DataType of
    ftDate : Ptrn:=TJSONDateField(F).DateFormat;
    ftTime : Ptrn:=TJSONTimeField(F).TimeFormat;
    ftDateTime : Ptrn:=TJSONDateTimeField(F).DateTimeFormat;
  end;
  If (Ptrn='') then
    Case F.DataType of
      ftDate : Result:=DateToStr(DT);
      ftTime : Result:=TimeToStr(DT);
      ftDateTime : Result:=DateTimeToStr(DT);
    end
  else
    Result:=FormatDateTime(ptrn,DT);
end;

function TBaseJSONDataSet.CreateFieldMapper: TJSONFieldMapper;
begin
  Case RowType of
    rtJSONObject : Result:=TJSONObjectFieldMapper.Create;
    rtJSONArray : Result:=TJSONArrayFieldMapper.Create;
  end;
end;

function TBaseJSONDataSet.BookmarkValid(ABookmark: TBookmark): Boolean;

Var
  I : NativeInt;

begin
  I:=NativeInt(ABookMark);
  Result:=(I>=0) and (I<FRows.Count);

end;

function TBaseJSONDataSet.CompareBookmarks(Bookmark1, Bookmark2: TBookmark): Longint;

Var
  I1,I2 : NativeInt;

begin
  I1:=NativeInt(Bookmark1);
  I2:=NativeInt(Bookmark2);
  Result:=I2-I1;
end;

function TBaseJSONDataSet.GetFieldData(Field: TField; Buffer: Pointer
  ; NativeFormat : Boolean): Boolean;
var
  R,F : TJSONData;
  B : WordBool;
  s: string;
  w : widestring;
  D : TDateTime;
  FV : Double;
  I : Longint;
  li : int64;

begin
  if State in dsEditModes then
    I:=-1
  else if State in [dsCalcFields,dsInternalCalc] then
    I:=PRecInfo(CalcBuffer)^.RowIndex
  else if State = dsOldValue then
    begin
    if FEditIdx=-1 then
      Exit(False)
    else
      I:=PRecInfo(ActiveBuffer)^.RowIndex;
    end
  else
    I:=PRecInfo(ActiveBuffer)^.RowIndex;
  if (I<>-1) then
    R:=TJSONData(FRows[I])
  else
    R:=FEditRow;
  F:=FFieldMapper.GetJSONDataForField(Field,R);
  Result:=(F<>Nil) and not (F.JSONType in [jtUnknown,jtNull]);
  if (not Result) or (Buffer=Nil) then
    exit;
  case Field.DataType of
    ftfixedwidechar,
    ftwideString:
    begin
    W:=UTF8ToString(F.AsString);
    if (length(W)>0) then
      Move(W[1],Buffer^,Length(W)*SizeOf(Widechar)+1)
    else
      PChar(Buffer)^:=#0;
    end;
    ftfixedchar,
    ftString:
      begin
      S:=F.AsString;
      if (length(s)>0) then
        Move(S[1],Buffer^,Length(S)+1)
      else
        PChar(Buffer)^:=#0;
      end;
    ftBoolean:
      begin
      B:=F.AsBoolean;
      Move(B,Buffer^,sizeof(WordBool));
      end;
    ftDate,
    ftTime,
    ftDateTime:
      begin
      D:=ConvertDateTimeField(F.AsString,Field);
      Move(D,Buffer^,sizeof(TDateTime));
      end;
    ftFloat:
      begin
      Fv:=F.asFloat;
      Move(FV,Buffer^,sizeof(Double));
      end;
    ftSmallint,
    ftInteger,
    ftAutoInc,
    ftword:
      begin
      I:=F.AsInteger;
      Move(I,Buffer^,SizeOf(I));
      end;
    ftLargeint:
      begin
      LI:=F.AsInt64;
      Move(LI,Buffer^,SizeOf(LI));
      end;
  else
    Raise EJSONDataset.CreateFmt('Unsupported field type : %s',[GetEnumName(TypeInfo(TFieldType),Ord(Field.DataType))]);
  end; // case
end;

procedure TBaseJSONDataSet.SetFieldData(Field: TField; Buffer: Pointer; NativeFormat : Boolean);
var
  F : TJSONData;
  s: string;
  w : widestring;

begin
  W:='';
  s:='';
  F:=Nil;
  if (Buffer<>nil) then
  case Field.DataType of
    ftfixedwidechar,
    ftwideString:
    begin
    SetLength(W,Field.Size);
    if (length(W)>0) then
      Move(Buffer^,W[1],Field.Size*SizeOf(Widechar));
    F:=TJSONString.Create(W);
    end;
    ftfixedchar,
    ftString:
      begin
      s:=StrPas(Buffer);
      F:=TJSONString.Create(S);
      end;
    ftBoolean:
      F:=TJSONBoolean.Create(PWordBool(Buffer)^);
    ftDate,
    ftTime,
    ftDateTime:
      begin
      S:=FormatDateTimeField(PDateTime(Buffer)^,Field);
      F:=TJSONString.Create(S);
      end;
    ftFloat:
      F:=TJSONFloatNumber.Create(PDouble(Buffer)^);
    ftSmallint,
    ftInteger,
    ftAutoInc,
    ftword:
      F:=TJSONIntegerNumber.Create(PLongint(Buffer)^);
    ftLargeint:
      begin
      F:=TJSONInt64Number.Create(PInt64(Buffer)^);
      end;
  else
    Raise EJSONDataset.CreateFmt('Unsupported field type : %s',[GetEnumName(TypeInfo(TFieldType),Ord(Field.DataType))]);
  end; // case
  if (F=Nil) then
    F:=TJSONNull.Create;
  if State in [dsCalcFields,dsInternalCalc] then
    FFieldMapper.SetJSONDataForField(Field,FRows[FCurrentIndex[FCurrent]],F)
  else
    FFieldMapper.SetJSONDataForField(Field,FEditRow,F);
end;

procedure TBaseJSONDataSet.SetBookmarkFlag(Buffer: TRecordBuffer;
  Value: TBookmarkFlag);
begin
  PRecInfo(Buffer)^.BookmarkFlag := Value;
end;

procedure TBaseJSONDataSet.SetRecNo(Value: Integer);
begin
  if (Value < 0) or (Value > FCurrentIndex.Count) then
    raise EJSONDataset.CreateFmt('SetRecNo: index %d out of range',[Value]);
  FCurrent := Value - 1;
  Resync([]); 
  DoAfterScroll;
end;

constructor TBaseJSONDataSet.Create(AOwner: TComponent);
begin
  inherited;
  FownsData:=True;
end;

destructor TBaseJSONDataSet.Destroy;
begin
  FreeData;
  inherited;
end;

end.
