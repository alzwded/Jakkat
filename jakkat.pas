program Jakkat;

uses GetOpts, Parser;

var
  defs: TParserDefinitions;
  parsr: TParser;
  path: string;
  paths: array of string;

procedure Usage;
begin
  writeln('TODO: usage');
  halt(255);
end;

procedure ParseCommandLineOptions;
const
  optString = 'D:I:w::';
var
  c : char;
begin
  c := #0;
  repeat
    c := GetOpt(optString);
    case c of
    EndOfOptions: break;
    'D': begin
           writeln('define: ''', optarg, '''');
         end;
    'I': begin
           writeln('include dir: ''', optarg, '''');
         end;
    'w': begin
           writeln('write: ', '''', optarg, '''');
         end;
    '?': Usage;
    end;
  until c = EndOfOptions;
  while optind <= paramcount do begin
    writeln('file: ', paramstr(optind));
    inc(optind);
  end;
end;

BEGIN
  defs := TParserDefinitions.New;

  ParseCommandLineOptions;

  (* reentrant parser *)

  (*
    things to parse:
    [x=y]       define; y is a string constant
    [x:=a+b]    define with TFPExpressionParser enabled over a+b
    {file}      include file
    {3xfile}    include file 3 times
    {13xfile$x=y$a:=x+y}
                include file with defines
    <x>         expand define
  *)

  parsr := TParser.New(defs);
  defs.Free;

  for path in paths do begin
    parsr.Enter(path);
  end;

  parsr.Free;
END.

