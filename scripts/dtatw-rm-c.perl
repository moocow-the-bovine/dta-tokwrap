#!/usr/bin/perl -wp

s|</?c\b[^>]*>||g;       ##-- remove all <c> tags
s|<lb\b[^\>]*/>|<lb/>|g; ##-- remove <lb> attributes too
