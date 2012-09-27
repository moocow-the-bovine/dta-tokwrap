#!/usr/bin/perl -w

local $/=undef;
$_=<>;
s|(<[^>]*)\sXMLNS=|$1 xmlns=|g;  ##-- restore default namespaces
print;
