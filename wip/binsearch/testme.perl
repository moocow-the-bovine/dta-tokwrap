#!/usr/bin/perl -w

use PDL;
use Benchmark qw(cmpthese timethese);


##==============================================================
## bench: load: list
sub load_list {
  no warnings 'numeric';
  my ($file,$n) = @_;
  $n = 1 if (!$n);
  open(my $fh,"<$file") or die("$0: open failed for '$file': $!");
  my (@l);
  if ($n>1) {
    @l = sort {$a->[0]<=>$b->[0]} map {chomp; $n>1 ? [map {$_+0} split(/ /,$_,$n)] : ($_+0)} <$fh>;
  } else {
    @l = sort {$a<=>$b}           map {chomp; $_+0} <$fh>;
  }
  close $fh;
  return \@l;
}

sub load_vec {
  my ($file,$n) = @_;
  my $l = load_list($file,$n);
  return pack('N*', map {ref($_) ? @$_ : $_} @$l);
}

##==============================================================
## bench: load: pdl
sub load_pdl {
  return pdl(long,load_list(@_));
}
sub load_pdl0 {
  my ($file,$n) = @_;
  $n = 1 if (!$n);
  my @pdls = rcols($file);
  if ($n==1) {
    $pdls[0]->inplace->qsort;
    return $pdls[0];
  } else {
    my $p = cat(@pdls[0..($n-1)])->xchg(0,1);
    $p->inplace->qsortvec;
    return $p;
  }
}

##==============================================================
## bench: lookup: pdl
sub lookup_pdl {
  #my ($p,\@co) = @_;
  #return [pdl(long,$_[1])->vsearch($_[0])->list];
  my $co = pdl(long,$_[1]);
  my $bi = $co->vsearch($_[0]);
  (my $tmp=$bi->where($_[0]->index($bi)!=$co)) -= 1;
  return [$bi->list];
}

##==============================================================
## bench: lookup: native
sub lookup_list {
  my ($l,$co) = @_;
  return [map {binsearch_l($l,$_)} @$co];
}

sub binsearch_l {
  my ($l,$key)=@_[0,1];
  my $ilo = @_>2 ? $_[2] : 0;
  my $ihi = @_>3 ? $_[3] : $#$l;
  my ($imid);

  while ($ihi-$ilo > 1) {
    $imid = ($ihi+$ilo) >> 1;
    #print "ITER: $ilo:$l->[$ilo] .. ($imid:$l->[$imid]) .. $ihi:$l->[$ihi]\n";
    if ($l->[$imid] < $key) {
      $ilo = $imid;
    } else {
      $ihi = $imid;
    }
  }
  #print "FINAL: $ilo:$l->[$ilo] .. ($imid:$l->[$imid]) .. $ihi:$l->[$ihi]\n";
  return $ilo if ($l->[$ilo]==$key);
  return $l->[$ihi]<=$key ? $ihi : $ilo;
}

##-- TEST
if (0) {
  $l = [qw(1 2 4 8 16 32 64 128 256)];
  $i = binsearch_l($l, 8);
  $i = binsearch_l($l, 7);
  $i = binsearch_l($l, 0);
  $i = binsearch_l($l, 512);
}

##==============================================================
## bench: lookup: vector
sub lookup_vec {
  my ($vr,$co) = @_;
  return [map {binsearch_v($vr,$_)} @$co];
}

sub binsearch_v {
  use bytes;
  my ($vr,$key)=@_[0,1];
  my $ilo = @_>2 ? $_[2] : 0;
  my $ihi = @_>3 ? $_[3] : ((length($$vr)>>2)-1);
  my ($imid);

  while ($ihi-$ilo > 1) {
    $imid = ($ihi+$ilo) >> 1;
    #print "ITER: $ilo:".vec($$vr,$ilo,32)." .. ($imid:".vec($$vr,$imid,32).") .. $ihi:".vec($$vr,$ihi,32)."\n";
    if (vec($$vr,$imid,32) < $key) {
      $ilo = $imid;
    } else {
      $ihi = $imid;
    }
  }
  #print "FINAL: $ilo:".vec($$vr,$ilo,32)." .. ($imid:".vec($$vr,$imid,32).") .. $ihi:".vec($$vr,$ihi,32)."\n";
  return $ilo if (vec($$vr,$ilo,32)==$key);
  return vec($$vr,$ihi,32)<=$key ? $ihi : $ilo;
}

##-- TEST
if (0) {
  $v = pack('N*',qw(1 2 4 8 16 32 64 128 256));
  $i = binsearch_v(\$v, 8);
  $i = binsearch_v(\$v, 7);
  $i = binsearch_v(\$v, 0);
  $i = binsearch_v(\$v, 512);
}


##==============================================================
## MAIN
my ($sxfile,$cofile) = @ARGV;
$sxfile = 'sj01.sxc' if (!$sxfile);
$cofile = 'sj01.cxo' if (!$cofile);

##-- load
my $l = load_list($sxfile,1);
my $p = load_pdl($sxfile,1);
my $v = load_vec($sxfile,1);

##-- bench: load
if (0) {
  print STDERR "compare: load_sx_*()\n";
  cmpthese(10,{
	       'load_sx_l'=>sub {load_list($sxfile,1)},
	       'load_sx_v'=>sub {load_vec($sxfile,1)},
	       'load_sx_p'=>sub {load_pdl($sxfile,1)},
	      });
}

##-- bench: lookup
my $col = load_list($cofile,1);
my $cov = pack('N*',@$col);
my $cop = pdl(long,$col);

##-- random c indices
my $cqpi = (random(99)*($cop->nelem))->long->qsort;
my $cqp  = $cop->index($cqpi);
my @cql  = $cqp->list;

##-- TEST
if (1) {
  my $ip = lookup_pdl($p,\@cql);
  my $il = lookup_list($l,\@cql);
  my $iv = lookup_vec(\$v,\@cql);

  $ip = lookup_pdl($cop,\@cql);
  $il = lookup_list($col,\@cql);
  $iv = lookup_vec(\$cov,\@cql);
}

print STDERR "\ncompare: lookup_sx_*()\n";
cmpthese(-1,{
	     'lookup_sx_p'=>sub {lookup_pdl($p,\@cql)},
	     'lookup_sx_l'=>sub {lookup_list($l,\@cql)},
	     'lookup_sx_v'=>sub {lookup_vec(\$v,\@cql)},
	    });

print STDERR "\ncompare: lookup_cx_*()\n";
cmpthese(-1,{
	     'lookup_cx_p'=>sub {lookup_pdl($cop,\@cql)},
	     'lookup_cx_l'=>sub {lookup_list($col,\@cql)},
	     'lookup_cx_v'=>sub {lookup_vec(\$cov,\@cql)},
	    });
