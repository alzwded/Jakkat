#!/bin/sh

[ -f jakkat ] && rm -f jakkat.xz
[ -f jakkat.exe ] && rm -f jakkat-win32.zip
xz -9 -k jakkat
zip -9 jakkat-win32.zip jakkat.exe
