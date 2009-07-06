#!/bin/bash

config="release.mak"

echo "$0: make config='$config' $@ all extra" 1>&2
exec make config="$config" "$@" all extra
