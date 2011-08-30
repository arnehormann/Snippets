#!/bin/bash
rm *.csv
charset=`file -bi "$1"|cut -d= -f2`
iconv -f "$charset" -t utf8 "$1" |\
  sed 's:[\r\n][\r\n]*:\n:g;s:\([#;\t ]\)D\([0-9][0-9][0-9][0-9]\)\([0-1][0-9]\)\([0-3][0-9]\):\1\2-\3-\4:g' |\
  awk -f smf_converter.awk
