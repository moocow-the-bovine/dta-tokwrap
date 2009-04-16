#!/usr/bin/perl -w

use File::Basename qw(basename);
our $prog = basename($0);

if (@ARGV < 2) {
  print STDERR
    ("Usage(s):\n",
     "  $prog FILE [=?]OFFSET \"+\"[LENGTH=1]\n",
     "  $prog FILE [=?]OFFSET \"-\"[OFFSET_FROM_FILE_END]\n",
     "  $prog FILE [=?]OFFSET    [END_OFFSET] ##-- not inclusive\n",
    );
  exit 1;
}

while (@ARGV) {
  ($file,$off,$lenarg) = splice(@ARGV,0,3);
  if    ($lenarg =~ /^\+(.*)$/) { $len = $1; }
  elsif ($lenarg =~ /^\-(.*)$/) { $len = (-s $file) - $1 - $off; }
  else                          { $len = $lenarg - $off; }

  if ($off =~ s/^\=//) {
    $want_newlines=0;
  } else {
    $want_newlines=1;
  }

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
