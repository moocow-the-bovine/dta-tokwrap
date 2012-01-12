#!/bin/bash

if test $# -lt 1 -o "$1" = "-h" -o "$1" = "-help" -o "$1" = "--help" ; then
  echo "Usage: $0 TEIFILE(s)..." >&2
  exit 1
fi

dir0=$(dirname "$0")
for f in "$@"; do
  b=$(basename "$f")
  b=${b%%.*}
  #dtaid=$("$dir0"/dtatw-get-header.perl -e='idno' -a type=DTAID "$f" | perl -pe 's|^[^\>]*>\s*||; s|\s*\<.*$||;')
  dtaid=$(perl -ne 'if (m(\<\s*idno\b[^\>]*?\btype=\"DTAID\"[^\>]*?\>\s*([^\<\s]*?)\s*\</idno\>)i) { print $1; exit 0; }' "$f")
  test -z "$dtaid" && dtaid=-
  echo -e "$f\t$b\t$dtaid"
done
