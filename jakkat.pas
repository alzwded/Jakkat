program Jakkat;

uses GetOpts, TestUnit;

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
  ParseCommandLineOptions;

  mytest;
  (* reentrant parser *)
END.

