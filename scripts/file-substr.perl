#!/usr/bin/perl -w

use File::Basename qw(basename);
our $prog = basename($0);

if (@ARGV < 2 || grep {/^\-h/} @ARGV) {
  print STDERR <<EOF;

Usage(s):
 $prog FILE [=]OFFSET \"+\"[LENGTH=1]
 $prog FILE [=]OFFSET \"-\"[OFFSET_FROM_FILE_END]
 $prog FILE [=]OFFSET    [END_OFFSET] ##-- not inclusive

Notes:
 + if OFFSET begins with '=', formatting newlines and "---" separator(s) are suppressed.

EOF
  exit 1;
}

while (@ARGV) {
  ($file,$off,$lenarg) = splice(@ARGV,0,3);

  if ($off =~ s/^\=//) {
    $want_newlines=0;
  } else {
    $want_newlines=1;
  }

  if    ($lenarg =~ /^\+(.*)$/) { $len = $1; }
  elsif ($lenarg =~ /^\-(.*)$/) { $len = (-s $file) - $1 - $off; }
  else                          { $len = $lenarg - $off; }

  open(FILE,"<$file") or die("$0: open failed for '$file': $!");
  seek(FILE, $off, 0);
  $buf='';
  read(FILE, $buf, $len);
  print
    (($want_newlines ? "---\n" : qw()),
     $buf,
     ($want_newlines ? "\n---\n" : qw()),
    );
  close(FILE);
}
