unit Parser;

{$mode objfpc}
{$H+}

interface

uses contnrs;

type
  TParserDefinitions = class
  private
    m_table : TFPStringHashTable;

    procedure CopyIterateFn(Item: String; const Key: String; var Continue: Boolean);
    function GetItem(Id: string): string;
  protected
  public
    constructor New;
    constructor Inherit(env : TParserDefinitions);
    destructor Destroy; override;

    property Definition[Id: string] : string read GetItem;
  end;

  TParser = class
  private
    m_env : TParserDefinitions;
  protected
  public
    constructor New(env : TParserDefinitions);
    destructor Destroy; override;

    procedure Enter(path : string);
  end;

procedure mytest;

implementation

(* TParserDefinitions *)

constructor TParserDefinitions.New;
begin
  m_table := TFPStringHashTable.Create;
end;

constructor TParserDefinitions.Inherit(env : TParserDefinitions);
var
  table: TFPStringHashTable;
begin
  table := env.m_table;
  m_table := TFPStringHashTable.Create;

  table.Iterate(@CopyIterateFn);
end;

destructor TParserDefinitions.Destroy;
begin
  m_table.Free;

  Inherited;
end;

procedure TParserDefinitions.CopyIterateFn(Item: string; const Key: string; var Continue: Boolean);
begin
  m_table.Add(Key, Item);
end;

function TParserDefinitions.GetItem(Id: string): string;
begin
  Result := m_table.Items[Id];
end;

(* TParser *)

constructor TParser.New(env : TParserDefinitions);
begin
  m_env := TParserDefinitions.Inherit(env);
end;

destructor TParser.Destroy;
begin
  m_env.Free;

  Inherited;
end;

procedure TParser.Enter(path: string);
begin
  (* open file
     for each line
       regex <.*>, [.*], {.*} non greedy
       update env                       if [] or {}
       call reentrant parser            if {}
       inject new text                  if <> or {}
  *)
end;

(* mytest *)

procedure mytest;
begin
  writeln('hello!');
end;

end.

