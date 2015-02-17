unit Parser;

{$mode objfpc}
{$H+}

interface

uses contnrs, regexpr, fpexprpars, classes, SysUtils;

type
  TDefReplaceHelper = class
    s: string;
    procedure it(Item: string; const Key: string; var Continue: Boolean);
  end;
  TParserDefinitions = class
  private
    m_table : TFPStringHashTable;

    procedure CopyIterateFn(Item: String; const Key: String; var Continue: Boolean);
    function GetItem(Id: string): string;
    procedure SetItem(Id: string; Val: string);
  protected
  public
    constructor New;
    constructor Inherit(env : TParserDefinitions);
    destructor Destroy; override;

    procedure Substitute(var s: string);

    property Definition[Id: string] : string read GetItem write SetItem;
  end;

  TParser = class
  private
    m_env : TParserDefinitions;
    m_buffer : TStringStream;

    procedure AddLine(s: string);
    procedure ParseIncludeDefs(s: string; var env: TParserDefinitions);
    procedure ParseAssignation(captured: string; var env: TParserDefinitions);
    function GetBufferAsString: string;
  protected
  public
    constructor New(env : TParserDefinitions);
    destructor Destroy; override;

    procedure Enter(path : string);

    property Buffer : string read GetBufferAsString;
  end;

procedure mytest;

implementation

(* TDefReplaceHelper *)

procedure TDefReplaceHelper.it(Item: String; const Key: String; var Continue: Boolean);
begin
  ReplaceRegExpr('\<' + Key + '\>', s, Item, False);
end;

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

procedure TParserDefinitions.SetItem(Id: string; Val: string);
begin
  if m_table.Find(Id) <> Nil then
    m_table.Items[Id] := Val
  else
    m_table.Add(Id, Val);
end;

procedure TParserDefinitions.Substitute(var s: string);
var
  obj: TDefReplaceHelper;
begin
  obj := tDefReplaceHelper.Create;
  obj.s := s;
  m_table.Iterate(@obj.it);
  obj.Free;
  s := obj.s;
end;

(* TParser *)

constructor TParser.New(env : TParserDefinitions);
begin
  m_env := TParserDefinitions.Inherit(env);
  m_buffer := TStringStream.Create('');
end;

destructor TParser.Destroy;
begin
  m_buffer.Free;
  m_env.Free;

  Inherited;
end;

function TParser.GetBufferAsString: string;
begin
  Result := m_buffer.DataString;
end;

procedure TParser.AddLine(s: string);
begin
  m_buffer.WriteString(s + LineEnding);
end;

procedure TParser.ParseAssignation(captured: string; var env: TParserDefinitions);
var
  sleft, sexpr: string;
  exprParser: TFPExpressionParser;
  exprResult: TFPExpressionResult;
begin
  if pos(':=', captured) > 0 then begin
    sleft := copy(captured, 1, pos(':=', captured));
    sexpr := copy(captured, pos(':=', captured) + 2, length(captured));

    (* replace variables with values *)
    env.Substitute(sexpr);

    exprParser := TFPExpressionParser.Create(nil);
    try
      exprParser.Expression := sexpr;
      exprResult := exprParser.Evaluate;
      m_env.Definition[sleft] := exprResult.ResString;
    finally
      exprParser.Free;
    end;
  end else begin
    sleft := copy(captured, 1, pos('=', captured));
    sexpr := copy(captured, pos('=', captured) + 1, length(captured));

    m_env.Definition[sleft] := sexpr;
  end;
end;

procedure TParser.ParseIncludeDefs(s: string; var env: TParserDefinitions);
var
  endPos: integer;
  beginPos: integer;
  expr: string;
begin
  endPos := length(s);
  beginPos := 1;

  while pos('$', s) > 0 do begin
    beginPos := pos('$', s);
    if pos('$', copy(s, beginPos + 1, length(s))) > 0 then
      endPos := pos('$', copy(s, beginPos + 1, length(s)));
    expr := copy(s, beginPos, endPos);
    s := copy(s, endPos + 1, length(s));
  end;
end;

procedure TParser.Enter(path: string);
var
  f: TextFile;
  line: string;
  captured: string;
  r_angular, r_square, r_curly: TRegExpr;
  r_any: TRegExpr;
  r: TRegExpr;
  sleft, sexpr: string;

  r_parseSquare: TRegExpr;
  r_count, r_file, s: string;
  r_aggregate: string;
  nbOfInserts: integer;

  newEnv: TParserDefinitions;
  newParser: TParser;
  newFile: string;
begin
  (* open file
     for each line
       regex <.*>, [.*], {.*} non greedy
       update env                       if [] or {}
       call reentrant parser            if {}
       inject new text                  if <> or {}
  *)

  AssignFile(f, path);

  r_angular:= TRegExpr.Create;
  r_square := TRegExpr.Create;
  r_curly  := TRegExpr.Create;
  r_any    := TRegExpr.Create;
  r_parseSquare := TRegExpr.Create;
  r_Square.Expression := '\[([^\]]*)\]';
  r_angular.Expression := '<([^>]*)>';
  r_curly.Expression := '{([^}]*)}';
  r_any.Expression := '([\[{<])';
  r_parseSquare.Expression := '^([0-9]+x)?([^\$]*)(\$.*)$';

  try
    Reset(f);
    repeat
      readln(f, line);
      if pos('#', line) > 0 then
        line := copy(line, 1, pos('#', line));
      while r_any.Exec(line) do begin
        case r_any.Match[1][1] of
        '[': begin
               r_square.Exec(line);
               captured := r_square.Match[1];
               if pos('=', captured) <= 0 then begin
                 writeln('Error: invalid assignation');
                 halt(1);
               end;
               ParseAssignation(captured, m_env);

               ReplaceRegExpr(r_square.Expression,
                              line,
                              '',
                              False);
             end;
        '<': begin
               r_angular.Exec(line);
               ReplaceRegExpr(r_angular.Expression,
                              line,
                              m_Env.Definition[r_angular.Match[1]],
                              False);
             end;
        '{': begin
               newEnv := TParserDefinitions.Inherit(m_env);
               (* parse string => count, filename, def's *)
               r_square.Exec(line);
               r_parseSquare.Exec(r_square.Match[1]);
               r_count := r_parseSquare.Match[1];
               r_file := r_parseSquare.Match[2];
               s := r_parseSquare.Match[3];

               if length(r_count) > 0 then
                 nbOfInserts := StrToInt(copy(r_count, 1, length(r_count) - 1))
               else
                 nbOfInserts := 1;

               ParseIncludeDefs(s, newEnv);

               (* launch a new parser *)
               newParser := TParser.New(newEnv);
               newEnv.Free;
               newParser.Enter(newFile);
               (* replace include with the parser's buffer *)
               r_aggregate := '';
               while nbOfInserts > 0 do begin
                 r_aggregate := r_aggregate + newParser.Buffer;
                 dec(nbOfInserts);
               end;
               ReplaceRegExpr(r_curly.Expression,
                              line,
                              newParser.Buffer,
                              False);
               newParser.Free;
             end;
        end;
      end;
      AddLine(line);
    until(EOF(f));
  finally
    CloseFile(f);
  end;

  r_angular.Free;
  r_square.Free;
  r_curly.Free;
  r_parseSquare.Free;
end;

(* mytest *)

procedure mytest;
begin
  writeln('hello!');
end;

end.

