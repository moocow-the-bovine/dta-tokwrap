#!/bin/sh

sx2="$1"
shift

./xml-no-namespaces $sx2 \
  | xsltpipe.perl insert-implicit-breaks.xsl mark-sortkeys.xsl apply-sortkeys.xsl -

#  | xmllint --format - > ex2.sx2.sk

#  | xsltpipe.perl "$@" mark-sortkeys.xsl apply-sortkeys.xsl -

#  | ./dta-cook-paths.perl - \
#  | xsltproc inherit-offsets.xsl - \
#  | xsltproc mark-sortkeys.xsl - \
#  | xsltproc apply-sortkeys.xsl -

#  >$sx2.sk
