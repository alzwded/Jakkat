program Jakkat;

{$mode objfpc}

uses GetOpts, Parser, SysUtils;

var
  defs: TParserDefinitions;
  parsr: TParser;
  path: string;
  paths: array of string;
  outfilename: string;
  f: TextFile;

procedure Usage;
begin
  writeln('TODO: usage');
  halt(255);
end;

procedure ParseCommandLineOptions;
const
  optString = 'D:w::h';
var
  c : char;
begin
  c := #0;
  repeat
    c := GetOpt(optString);
    case c of
    EndOfOptions: break;
    'D': begin
           if pos('=', optArg) > 0 then
             defs.Definition[copy(optArg, 1, pos('=', optArg) - 1)] :=
                 copy(optArg, pos('=', optArg) + 1, length(optArg));
         end;
    'w': begin
           outfilename := optarg;
         end;
    'h': Usage;
    '?': Usage;
    end;
  until c = EndOfOptions;
  while optind <= paramcount do begin
    SetLength(paths, length(paths) + 1);
    paths[length(paths) - 1] := paramstr(optind);
    inc(optind);
  end;
end;

BEGIN
  defs := TParserDefinitions.New;
  outfilename := '';

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
  if length(outfilename) > 0 then
    AssignFile(f, outfilename)
  else
    AssignFile(f, '');

  Rewrite(f);
  write(f, parsr.Buffer);
  CloseFile(f);

  parsr.Free;
END.

