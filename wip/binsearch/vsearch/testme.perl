#!/usr/bin/perl -w
#-*- Mode: CPerl; coding: utf-8 -*-

use lib qw(./blib/lib ./blib/arch);
use Algorithm::BinarySearch::Vec ':all';

BEGIN {
  #binmode(\*STDOUT,':utf8');
}

##--------------------------------------------------------------
## utils: vector creation

## $vec = makevec($nbits,\@vals)
sub makevec {
  my ($nbits,$vals) = @_;
  my $vec   = '';
  vec($vec,$_,$nbits)=$vals->[$_] foreach (0..$#$vals);
  return $vec;
}

## \@l = vec2list($vec,$nbits)
sub vec2list {
  use bytes;
  my ($vec,$nbits) = @_;
  return [map {vec($vec,$_,$nbits)} (0..(length($vec)*8/$nbits-1))];
}

##--------------------------------------------------------------
## test: vget

sub checkvec {
  use bytes;
  my ($v,$nbits,$label,$verbose) = @_;
  $label   = "checkvec($nbits)" if (!$label);
  $verbose = 1 if (!defined($verbose));
  my $ok = 1;
  my ($i,$vval,$xval);
  foreach $i (0..(length($v) * (8.0/$nbits) - 1)) {
    $vval = vec($v,$i,$nbits);
    $xval = vget($v,$i,$nbits);
    print "$label\[$i]: ", ($vval==$xval ? "ok ($vval)" : "NOT ok (v:$vval != x:$xval)"), "\n" if ($verbose);
    $ok &&= ($vval==$xval);
  }
  print "\n" if ($verbose);
  return $ok;
}

sub test_vget {
  my $v1 = makevec(1, [qw(0 1 1 0 1 1 0 1)]);
  my $v2 = makevec(2, [qw(0 1 2 3 3 2 1 0)]);
  my $v4 = makevec(4, [qw(0 1 2 4 8 15)]);
  my $v8 = makevec(8, [qw(0 1 2 4 8 16 32 64 128 255)]);
  my $v16 = makevec(16, [qw(100 500 1000 65000)]);
  my $v32 = makevec(32, [qw(100 500 1000 100000)]);

  ##-- debug
  checkvec($v1,1);
  checkvec($v2,2);
  checkvec($v4,4);
  checkvec($v8,8);
  checkvec($v16,16);
  checkvec($v32,32);

  ##-- random
  foreach my $nbits (qw(1 2 4 8 16 32)) {
    my $nelem = 100;
    my $v     = makevec($nbits, [map {int(rand(2**$nbits))} (1..$nelem)]);
    my $ok    = checkvec($v,$nbits,undef,0);
    print "random(nbits=$nbits,nelem=$nelem): ", ($ok ? "ok" : "NOT ok"), "\n";
  }
}
#test_vget();

##--------------------------------------------------------------
## test: vset

sub check_set {
  my ($nbits,$l,$i,$val, $verbose) = @_;
  my $label = "checkset(nbits=$nbits,i=$i,val=$val)";
  $verbose  = 1 if (!defined($verbose));

  my $v0 = ref($l) ? makevec($nbits,$l) : $l;
  my $vv = $v0;
  my $vx = $v0;

  vec($vv,$i,$nbits) = $val;
  vset($vx,$i,$nbits,$val);

  my $vgot = vec($vv,$i,$nbits);
  my $xgot = vec($vx,$i,$nbits);
  my $rc  = ($vgot==$xgot);
  if ($verbose || !$rc) {
    print "$label: ", ($rc ? "ok ($vgot)" : "NOT ok (v:$vgot != x:$xgot)"), "\n";
  }
  return $rc;
}

sub test_vset {
  ##-- set some stuff
  check_set(1,[qw(0 1 1 0 1 1 0 1)],3=>1); ##-- not ok: continue here
  check_set(1,[qw(1 1 1 0 0 1 1 1 0 0 0 0 0 0 0 0)],7=>0); ##-- not ok
  die;
  #check_set(2,[qw(0 1 2 3 3 2 1 0)], 6=>2);
  #check_set(4,[qw(0 1 2 4 8 15)],5=>7);
  #check_set(8,[qw(0 1 2 4 8 16 32 64 128 255)],1=>255);
  #check_set(16,[qw(100 500 1000 65000)], 3=>12345);
  #check_set(32,[qw(100 500 1000 100000)], 2=>98765);

  ##-- random
  foreach my $nbits (qw(1 1 1 1 1)) { #qw(1 2 4 8 16 32)) {
    my $nelem = 10;
    my $v     = makevec($nbits,[map {int(rand(2**$nbits))} (1..$nelem)]);
    my $i     = int(rand($nelem));
    my $ok = 1;
    my ($val);
    foreach $i (0..($nelem-1)) {
      $val = int(rand(2**$nbits));
      $l   = vec2list($v,$nbits); ##-- save
      $ok &&= check_set($nbits,$v,$i,$val, 0);
      last if (!$ok);
    }
    print "random_set(nbits=$nbits,l=[".join(' ',@$l)."],i=$i,val=$val): ", ($ok ? "ok" : "NOT ok"), "\n";
    die if (!$ok);
  }
}
test_vset();


##--------------------------------------------------------------
## test: bsearch (raw)

sub check_bsearch {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_bsearch(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = bsearch($v,$key,$nbits, 0,$#$l);
  my $istr = defined($i) ? ($i+0) : 'undef';
  my $wstr = defined($want) ? ($want+0) : 'undef';
  my $rc = ($istr eq $wstr);
  print STDERR ($rc ? "ok (=$wstr)" : "NOT ok (want=$wstr != got=$istr)"), "\n";
  return $rc;
}

sub test_bsearch {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_bsearch(32,$l,8, 3);
  check_bsearch(32,$l,7, undef);
  check_bsearch(32,$l,0, undef);
  check_bsearch(32,$l,512, undef);
  check_bsearch(32,[qw(0 1 1 1 2)],1,1);
}
#test_bsearch();


##--------------------------------------------------------------
## test: lower_bound

sub check_lb {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_lb(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = vsearch_lb($v,$key,$nbits, 0,$#$l);
  my $rc = ($i==$want);
  print STDERR ($rc ? "ok (=$want)" : "NOT ok (want=$want != got=$i)"), "\n";
  return $rc;
}

sub test_lb {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_lb(32,$l,8, 3);
  check_lb(32,$l,7, 2);
  check_lb(32,$l,0, 0);
  check_lb(32,$l,512, $#$l);
  check_lb(32,[qw(0 1 1 1 2)],1,1);
}
#test_lb();

##--------------------------------------------------------------
## test: upper_bound

sub check_ub {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_ub(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = vsearch_ub($v,$key,$nbits, 0,$#$l);
  my $rc = ($i==$want);
  print STDERR ($rc ? "ok (=$want)" : "NOT ok (want=$want != got=$i)"), "\n";
  return $rc;
}

sub test_ub {
  my ($l,$i);
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  check_ub(32,$l,8, 3);
  check_ub(32,$l,7, 3);
  check_ub(32,$l,0, 0);
  check_ub(32,$l,512, $#$l);
  check_ub(32,[qw(0 1 1 1 2)],1,3);
}
#test_ub();


##--------------------------------------------------------------
## MAIN

sub main_dummy {
  foreach $i (1..3) {
    print "--dummy($i)--\n";
  }
}
main_dummy();

