Jakkat
======

Jak's cat tool.

This is essentially a cross platform tool inspired by cpp (the C preprocessor)
which is used to assemble a text document from smaller templates (e.g.
for assembling songs for [this guy](https://github.com/alzwded/JakMuse))

Syntax
------

### Plain definitions

```
[x=value]
```

### Arithmetics

```
[x:=2+3]        # the 'x' symbol will be '5'
[y:=2*3]
[z:=x+y]        # 'z' will be '11'
[z=x+y]         # 'z' will be 'x+y'
```

### Substitutions

```
[x=y]
<x> is 10.      # '<x>' will be replaced by 'y'
```

### Inclusions

```
{file.inc}      # the file 'file.inc' will have its contents inserted
{10xfile.inc}   # the file will be included 10 times
{file.inc$x=V$y:=2+3} # pass symbol definitions to the reentrant parser
                      # the symbol definitions passed this way will not
                      # be visible to the rest of the file; they apply
                      # only to the parser reading 'file.inc'
{3xfile.inc$x=V} # etc
```

### Command line arguments

```sh
jakkat [-w output_file] [-DConstant=Definition...] inputfile1 inputfile2...
```

The constant definitions passed through `-D` are redefined on each
entry (i.e. for each input file).
