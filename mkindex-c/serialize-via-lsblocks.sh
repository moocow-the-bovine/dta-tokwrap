#!/bin/sh

sx1="$1"

./dta-tokwrap-lsblocks.perl $sx1 | ./dta-tokwrap-sortblocks.perl -

#  >$sx1.sb
