#!/usr/bin/perl -wp

s|\<\/?|\b[^\>]*>||g;
s|\<lb\b[^\>]*/>|<lb/>|g;
