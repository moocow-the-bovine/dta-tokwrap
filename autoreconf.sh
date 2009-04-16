#!/bin/sh

#ar_args="--install --verbose --force --symlink"
ar_args="--install --verbose --force"
#ar_args="--install --verbose"

exec autoreconf $ar_args "."
