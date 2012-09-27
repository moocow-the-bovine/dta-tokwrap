#!/usr/bin/perl -w

local $/=undef;
$_=<>;
s|(<[^>]*)\sxmlns=|$1 XMLNS=|g;  ##-- remove default namespaces
print;
