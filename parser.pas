unit Parser;

{$mode objfpc}
{$H+}

interface

uses contnrs, regexpr, fpexprpars;

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

    property Definition[Id: string] : string read GetItem write SetItem;
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

procedure TParserDefinitions.SetItem(Id: string; Val: string);
begin
  if m_table.Find(Id) <> Nil then
    m_table.Items[Id] := Val
  else
    m_table.Add(Id, Val);
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
var
  f: TextFile;
  line: string;
  captured: string;
  r_angular, r_square, r_curly: TRegExpr;
  r_any: TRegExpr;
  r: TRegExpr;
  sleft, sexpr: string;
  exprParser: TFPExpressionParser;
  exprResult: TFPExpressionResult;
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
  r_Square.Expression := '\[([^\]]*)\]';
  r_angular.Expression := '<([^>]*)>';
  r_curly.Expression := '{([^}]*)}';
  r_any.Expression := '([\[{<])';

  try
    Reset(f);
    repeat
      readln(f, line);
      while r_any.Exec(line) do begin
        case r_any.Match[1][1] of
        '[': begin
               r_square.Exec(line);
               captured := r_square.Match[1];
               if pos('=', captured) <= 0 then begin
                 writeln('Error: invalid assignation');
                 halt(1);
               end;
               if pos(':=', captured) > 0 then begin
                 sleft := copy(captured, 1, pos(':=', captured));
                 sexpr := copy(captured, pos(':=', captured) + 2, length(captured));

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
               (* TODO *)
             end;
        end;
      end;
    until(EOF(f));
  finally
    CloseFile(f);
  end;
end;

(* mytest *)

procedure mytest;
begin
  writeln('hello!');
end;

end.

