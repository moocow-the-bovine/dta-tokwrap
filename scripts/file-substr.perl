#!/usr/bin/perl -w

use File::Basename qw(basename);
use Getopt::Long ':config'=>'no_ignore_case';
our $prog = basename($0);

our $rawmode = 0;
our ($help);
GetOptions(
	   'help|h' => \$help,
	   'raw|r!' => \$rawmode,
	  );

if (@ARGV < 2 || $help) {
  print STDERR <<EOF;

Usage(s):
 $prog [OPTIONS] FILE [=?]OFFSET \"+\"[LENGTH=1]
 $prog [OPTIONS] FILE [=?]OFFSET \"-\"[OFFSET_FROM_FILE_END]
 $prog [OPTIONS] FILE [=?]OFFSET    [END_OFFSET] ##-- not inclusive

Options:
 -help              ##-- this help message
 -raw , -noraw      ##-- don't/do format output messages (-raw works like '=' as OFFSET prefix)

EOF
  exit 1;
}

while (@ARGV) {
  ($file,$off,$lenarg) = splice(@ARGV,0,3);
  if    ($lenarg =~ /^\+(.*)$/) { $len = $1; }
  elsif ($lenarg =~ /^\-(.*)$/) { $len = (-s $file) - $1 - $off; }
  else                          { $len = $lenarg - $off; }

  my $want_newlines = !$rawmode;
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
