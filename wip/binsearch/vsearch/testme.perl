#!/usr/bin/perl -w
#-*- Mode: CPerl; coding: utf-8 -*-

use lib qw(./blib/lib ./blib/arch);
use Algorithm::BinarySearch::Vec::XS ':all';

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
  if (0) {
    checkvec($v1,1);
    checkvec($v2,2);
    checkvec($v4,4);
    checkvec($v8,8);
    checkvec($v16,16);
    checkvec($v32,32);
    exit 0;
  }

  ##-- random
  my $ok = 1;
  foreach my $nbits (qw(1 2 4 8 16 32)) {
    my $nelem = 100;
    my $l     = [map {int(rand(2**$nbits))} (1..$nelem)];
    my $v     = makevec($nbits, $l);
    $ok       = checkvec($v,$nbits,undef,0);
    if (!$ok) {
      die "NOT ok: get:random(nbits=$nbits,l=[",join(' ',@$l),"])\n";
    } else {
      print "ok: get:random(nbits=$nbits,nelem=$nelem)\n";
    }
  }
  print "\n";
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

  ##-- debug
  if (0) {
    check_set(1,[qw(0 1 1 0 1 1 0 1)],3=>1);
    check_set(1,[qw(1 1 1 0 0 1 1 1 0 0 0 0 0 0 0 0)],7=>0);
    check_set(2,[qw(0 1 2 3 3 2 1 0)], 6=>2);
    check_set(4,[qw(0 1 2 4 8 15)],5=>7);
    check_set(8,[qw(0 1 2 4 8 16 32 64 128 255)],1=>255);
    check_set(16,[qw(100 500 1000 65000)], 3=>12345);
    check_set(32,[qw(100 500 1000 100000)], 2=>98765);
    exit 0;
  }

  ##-- random
  foreach my $nbits (qw(1 1 1 1 1)) { #qw(1 2 4 8 16 32)) {
    my $nelem = 10;
    my $v     = makevec($nbits,[map {int(rand(2**$nbits))} (1..$nelem)]);
    my $i     = int(rand($nelem));
    foreach $i (0..($nelem-1)) {
      my $val = int(rand(2**$nbits));
      $l      = vec2list($v,$nbits); ##-- save
      my $ok  = check_set($nbits,$v,$i,$val, 0);
      if (!$ok) {
	die "NOT ok: set:random(nbits=$nbits,l=[".join(' ',@$l)."],i=$i,val=$val)\n";
      } else {
	print "ok: set:random(nbits=$nbits,nelem=$nelem,i=$i,val=$val)\n";
      }
    }
  }
  print "\n";
}
#test_vset();


##--------------------------------------------------------------
## test: bsearch (raw)

sub check_bsearch {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_bsearch(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = vbsearch($v,$key,$nbits); #, 0,$#$l);
  my $istr = defined($i) ? ($i+0) : 'undef';
  my $wstr = defined($want) ? ($want+0) : 'undef';
  my $rc = ($istr eq $wstr);
  print STDERR ($rc ? "ok (=$wstr)" : "NOT ok (want=$wstr != got=$istr)"), "\n";
  return $rc;
}

sub test_bsearch {
  my ($l,$i);
  my $rc = 1;
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  $rc &&= check_bsearch(32,$l,8, 3);
  $rc &&= check_bsearch(32,$l,7, undef);
  $rc &&= check_bsearch(32,$l,0, undef);
  $rc &&= check_bsearch(32,$l,512, undef);
  $rc &&= check_bsearch(32,[qw(0 1 1 1 2)],1,1);
  die("test_bsearch() failed!\n") if (!$rc);
  print "\n";
}
test_bsearch();


##--------------------------------------------------------------
## test: lower_bound

sub check_lb {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_lb(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = vbsearch_lb($v,$key,$nbits, 0,$#$l);
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
  print "\n";
}
#test_lb();

##--------------------------------------------------------------
## test: upper_bound

sub check_ub {
  my ($nbits,$l,$key,$want) = @_;
  print STDERR "check_ub(nbits=$nbits,key=$key,l=[",join(' ',@$l),"]): ";
  my $v = makevec($nbits,$l);
  my $i = vbsearch_ub($v,$key,$nbits, 0,$#$l);
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
  print "\n";
}
#test_ub();


##--------------------------------------------------------------
## test: bsearch: array

## $str = nl2str(\@list)
sub nl2str {
  return join(' ', map {defined($_) ? ($_+0) : 'undef'} @{$_[0]});
}

sub check_asearch {
  my ($method, $nbits,$l,$keys,$want, $label,$verbose) = @_;
  $label   = "check_asearch:${method}(nbits=$nbits,keys=[".nl2str($keys)."])" if (!defined($label));
  $method  = UNIVERSAL::can('main',$method) if (!ref($method));
  $verbose = 1 if (!defined($verbose));
  print STDERR "$label: " if ($verbose);
  my $v    = ref($l) ? makevec($nbits,$l) : $l;
  my $got  = $method->($v,$keys,$nbits);
  my $gstr = nl2str($got);
  my $wstr = nl2str($want);
  my $ok   = ($gstr eq $wstr);
  print STDERR ($ok ? "ok (=[$wstr])" : "NOT ok (want=[$wstr] != got=[$gstr])"), "\n" if ($verbose);
  return $ok;
}

sub test_absearch {
  my ($l,$i);
  my $rc = 1;
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  my $keys = [qw(8 7 0 1 512 32 256)];
  $rc &&= check_asearch('vabsearch',    32,$l,$keys,[3,undef,undef,0,undef,5,8]);
  $rc &&= check_asearch('vabsearch_lb', 32,$l,$keys,[3,   2,     0,0,    8,5,8]);
  $rc &&= check_asearch('vabsearch_ub', 32,$l,$keys,[3,   3,     0,0,    9,5,8]);
  die("test_absearch() failed!\n") if (!$rc);
  print "\n";
}
#test_absearch();


##--------------------------------------------------------------
## MAIN

sub main_dummy {
  foreach $i (1..3) {
    print "--dummy($i)--\n";
  }
}
main_dummy();

