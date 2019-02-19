#!/bin/sh

#AM_MAKEFLAGS=-j2
yes | make DISTCHECK=y DISTCHECK_CONFIGURE_FLAGS="" "$@" distcheck
