#!/usr/bin/perl -w

local $/=undef;
$_=<>;
s|\s+(?=<c\b)||g;        ##-- remove whitespace preceding <c> tags
s|</?c\b[^>]*>||g;       ##-- remove all <c> tags (and any preceding whitespace)
s|<lb\b[^\>]*/>|<lb/>|g; ##-- remove <lb> attributes too
print;
