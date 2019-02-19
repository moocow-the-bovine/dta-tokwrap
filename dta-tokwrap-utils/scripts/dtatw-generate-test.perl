#!/usr/bin/perl -w

my $niters = 1024;
my $repeat = 'foo bar baz. ';
my @chars  = split(//,$repeat);

my $want_xml_ids = 1;

print
  ('<?xml version="1.0" encoding="UTF-8"?>', "\n",
   "<doc>\n",
   " <head>\n",
   "   <c xml:id=\"headc\">ignoreme</c>\n",
   " </head>\n",
   " <text>\n",
   " <p>\n",
  );

our $ci = 1;
foreach (1..$niters) {
  print map { "  <c".($want_xml_ids ? (" xml:id=\"c_".($ci++)."\"") : '').">$_</c>\n" } @chars;
  if    (($_ % 32) == 0) { print " <pb/>\n"; }
  elsif (($_ % 16) == 0) { print " </p>\n <p>"; }
  elsif (($_ %  4) == 0) { print " <lb/>\n"; }
}

print
  (" </p>\n",
   " </text>\n",
   "</doc>\n",
  );

