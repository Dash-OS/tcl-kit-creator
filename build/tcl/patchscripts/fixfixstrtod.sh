#! /usr/bin/env bash

echo '#undef strtod' > 'compat/strtod.c.new'
cat 'compat/strtod.c' >> 'compat/strtod.c.new'
cat 'compat/strtod.c.new' > 'compat/strtod.c'
rm -f 'compat/strtod.c.new'
