#! /bin/bash

# The "fix" for strtod:
#    1. Only applies to Solaris 2.4 (which noone should use)
#    2. Does not actually link against the file (which is
#       not even in Tk 8.6.1) that would supply such a symbol

grep -v '#define strtod fixstrtod' unix/configure > unix/configure.new
cat unix/configure.new > unix/configure
rm -f unix/configure.new

grep -v '#define strtod fixstrtod' macosx/configure > macosx/configure.new
cat macosx/configure.new > macosx/configure
rm -f macosx/configure.new

