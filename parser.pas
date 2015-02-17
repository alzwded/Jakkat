unit Parser;

{$mode objfpc}
{$H+}

interface

uses contnrs, regexpr, fpexprpars, classes, SysUtils;

type
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

    procedure Substitute(s: string; var expr: TFPExpressionParser);

    property Definition[Id: string] : string read GetItem write SetItem;
  end;

  TDefReplaceHelper = class
    s: string;
    expr: TFPExpressionParser;
    env: TParserDefinitions;
    procedure it(Item: string; const Key: string; var Continue: Boolean);
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

function SuperReplace(who, first, last, s: string): string;
procedure mytest;

implementation

(* TDefReplaceHelper *)

procedure TDefReplaceHelper.it(Item: String; const Key: String; var Continue: Boolean);
begin
  if pos(key, s) > 0 then
    try
      expr.Identifiers.AddIntegerVariable(key, StrToInt(Item));
    except
      on Exception do
        expr.Identifiers.AddStringVariable(key, Item);
    end;

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

  table.Iterate(@Self.CopyIterateFn);
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

procedure TParserDefinitions.Substitute(s: string; var expr: TFPExpressionParser);
var
  obj: TDefReplaceHelper;
begin
  obj := tDefReplaceHelper.Create;
  obj.s := s;
  obj.expr := expr;
  obj.env := Self;
  m_table.Iterate(@obj.it);
  obj.Free;
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
    sleft := copy(captured, 1, pos(':=', captured) - 1);
    sexpr := copy(captured, pos(':=', captured) + 2, length(captured));

    exprParser := TFPExpressionParser.Create(nil);
    exprParser.Builtins := [bcMath, bcConversion, bcStrings];

    (* replace variables with values *)
    env.Substitute(sexpr, exprParser);

    try
      exprParser.Expression := sexpr;
      exprResult := exprParser.Evaluate;
      case exprResult.ResultType of
      rtInteger: env.Definition[sleft] := IntToStr(exprResult.ResInteger);
      rtString: env.Definition[sleft] := exprResult.ResString;
      end;
    finally
      exprParser.Free;
    end;
  end else begin
    sleft := copy(captured, 1, pos('=', captured) - 1);
    sexpr := copy(captured, pos('=', captured) + 1, length(captured));

    env.Definition[sleft] := sexpr;
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
      endPos := pos('$', copy(s, beginPos + 1, length(s))) - 1;
    expr := copy(s, beginPos + 1, endPos - beginPos + 1);
    s := copy(s, endPos + 1, length(s));

    ParseAssignation(expr, env);
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
  comment: string;
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
  r_curly.Expression := '\{([^\}]*)\}';
  r_any.Expression := '([\[{<])';
  //r_parseSquare.Expression := '^([0-9]+x)?([^\$]*)(\$.*)$';
  r_parseSquare.Expression := '^([0-9]+x)?([^\$]*)(\$.*)?$';

  try
    Reset(f);
    repeat
      readln(f, line);
      if pos('#', line) > 0 then begin
        comment := copy(line, pos('#', line), length(line));
        line := copy(line, 1, pos('#', line) - 1);
      end else
        comment := '';
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

               line := SuperReplace(line, '[', ']', '');
             end;
        '<': begin
               r_angular.Exec(line);
               line := SuperReplace(line, '<', '>', m_env.Definition[r_angular.Match[1]]);
             end;
        '{': begin
               newEnv := TParserDefinitions.Inherit(m_env);
               (* parse string => count, filename, def's *)
               if not r_curly.Exec(line) then
                 writeln('regex failed???');
               if not r_parseSquare.Exec(r_curly.Match[1]) then
                 writeln('other regex failed???');
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
               newParser.Enter(r_file);
               (* replace include with the parser's buffer *)
               r_aggregate := '';
               while nbOfInserts > 0 do begin
                 r_aggregate := r_aggregate + newParser.Buffer;
                 dec(nbOfInserts);
               end;
               line := SuperReplace(line, '{', '}', r_aggregate);
               newParser.Free;
             end;
        end;
      end;
      AddLine(line + comment);
    until(EOF(f));
  finally
    CloseFile(f);
  end;

  r_angular.Free;
  r_square.Free;
  r_curly.Free;
  r_parseSquare.Free;
end;

(* SuperReplace *)

function SuperReplace(who, first, last, s: string): string;
var
  intermed, rema: string;
begin
  intermed := copy(who, 1, pos(first, who) - 1);
  rema := copy(who, pos(first, who) + 1, length(who));
  Result := intermed + s + copy(rema, pos(last, rema) + 1, length(rema))
end;

(* mytest *)

procedure mytest;
begin
  writeln('hello!');
end;

end.

