#!/bin/sh

sx2="$1"

../xml-no-ns.perl $sx2 \
  | ./dta-cook-paths.perl - \
  | xsltproc inherit-offsets.xsl - \
  | xsltproc mark-sortkeys.xsl - \
  | xsltproc apply-sortkeys.xsl -

#  >$sx2.sk
