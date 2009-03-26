#!/usr/bin/perl -w

use Fcntl qw(SEEK_SET);

if (@ARGV < 2) {
  print STDERR "Usage: $0 FILE OFFSET [LENGTH=1]";
  exit 1;
}

our $file = shift;
our $off = shift;
our $len = shift || 1;
our $buf = '';


open(FILE,"<$file")
  or die("$0: open failed for file '$file': $!");
seek(FILE, $off, SEEK_SET)
  or die("$0: seek() failed for file '$file': $!");
read(FILE, $buf, $len);
close(FILE);

print $buf;

