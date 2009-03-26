#!/usr/bin/perl -w

my $niters = 1024;
my $repeat = 'foo bar baz. ';
my @chars  = split(//,$repeat);

my $want_xml_ids = 1;

print
  ('<?xml version="1.0" encoding="UTF-8"?>', "\n",
   "<doc>\n",
  );

our $ci = 1;
foreach (1..$niters) {
  print map { " <c".($want_xml_ids ? (" xml:id=\"c_".($ci++)."\"") : '').">$_</c>\n" } @chars;
}

print "</doc>\n";


