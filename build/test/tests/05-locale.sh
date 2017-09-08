#! /bin/bash

unset $(locale | cut -f 1 -d =)
LC_ALL="en_US.UTF-8"
export LC_ALL
