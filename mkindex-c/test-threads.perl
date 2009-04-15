#!/usr/bin/perl -w

use threads;
use threads::shared;
use IO::File;
use POSIX qw(mkfifo);

##-- shared data
our $buf1 :shared='';
our $buf2 :shared='';
our $thr2_can_run :shared=0;

#our $N :shared=65535;
our $N :shared=32767;
#our $N :shared=42;

##-- thread callback #1
sub cb1 {
  {
    print STDERR "t1: preparing\n";
    lock($thr2_can_run);
    unlink('f1.txt') if (-e 'f1.txt');
    unlink('f2.txt') if (-e 'f2.txt');
    #mkfifo('f1.txt', 0700) or die("$0: mkfifo failed for 'f1.txt': $!");
    #mkfifo('f2.txt', 0700) or die("$0: mkfifo failed for 'f2.txt': $!");
    $thr2_can_run=1;
  }
  print STDERR "t1: running\n";
  my $f1 = IO::File->new('>f1.txt') or die("$0: open failed for write to 'f1.txt': $!");
  my $f2 = IO::File->new('>f2.txt') or die("$0: open failed for write to 'f2.txt': $!");
  my ($i);
  foreach $i (0..$N) {
    if ($i%2==1) { $f1->print($i,"\n"); }
    else         { $f2->print($i,"\n"); }
  }
  $f1->close;
  $f2->close;
}

##-- thread callback #2
sub cb2 {
  while (1) {
    print STDERR "t2: waiting for thr2_can_run\n";
    lock($thr2_can_run);
    last if ($thr2_can_run);
  }
  print STDERR "t2: running\n";
  my $f1 = IO::File->new('<f1.txt') or die("$0: open failed for read from 'f1.txt': $!");
  my $f2 = IO::File->new('<f2.txt') or die("$0: open failed for read from 'f2.txt': $!");
  our ($buf1,$buf2);
  $buf1 .= $_ while (<$f1>);
  $buf2 .= $_ while (<$f2>);
  $f1->close;
  $f2->close;
}

##-- main
my $thr1 = threads->new(\&cb1);
$thr1->detach();                 ##-- don't care about return values
#$thr1->join();                   ##-- wait for thread to exit

my $thr2 = threads->new(\&cb2);
#$thr2->detach();                 ##-- don't care about return values
$thr2->join();                   ##-- wait for thread to exit

##-- output
print "--BUF1--\n", $buf1, "\n";
print "--BUF2--\n", $buf2, "\n";
