#!/bin/bash

test -z "$*" && args=("config=release.mak") || args=("$@")

echo "$0: make ${args[@]} all extra" 1>&2
exec make "${args[@]}" all extra
