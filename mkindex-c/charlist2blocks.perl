#!/usr/bin/perl -w

##======================================================================
## Globals

##-- %key2blk : $blkKey => \%blkData
## + $blkKey    ##-- unique identifier for logical text block
## + %blkData   ##-- HASH ref
##   {
##    key => $blkKey,       ##-- block key
##    typ => $blkTyp,       ##-- block type (???)
##    xranges => \@xranges, ##-- byte ranges [$min,$max] in source XML document for this logical block
##    lranges => \@lranges, ##-- line ranges [$min,$max] in input charlist file for this logical block
##   }
## + the range [$min,$max] indicates all positions $i with ($min <= $i < $max)
our $rootBlk = { key=>'ROOT', typ=>'root', xranges=>[ [0,0] ], lranges=>[ [0,0] ] };
our %key2blk = ( $rootBlk->{key} => $rootBlk );

##-- @eltstack = (\%rootEltAttrs, ..., \%currentEltAttrs)
##  + each \%attrs element has an additional '__name__' attribute
our $rootElt = { __name__ => 'ROOT' };
our @eltstack = ( $rootElt );

##-- @blkstack = ($rootBlk, ..., $currentBlk)
## + mirrors @eltstack
our @blkstack = ( $rootBlk );

##-- $blk : current block
our $blk = $rootBlk;

##-- @implicit_block_elts
## + create new blocks for these elements, unless they occur as a daughter of a 'seg' element
our @implicit_block_elts = qw(note table row cell list item ref fw figure);
our %implicit_block_elts = map {$_=>undef} @implicit_block_elts;

##======================================================================
## MAIN
our ($id,$off,$len,$txt);
our ($aid,$aoff,$alen,$atxt);

our ($eltname,$elt,@attrs);

$_ = <>;
while (defined($_)) {
  chomp;
  if (/^%%/) { $_=<>; next; }; ##-- ignore comments

  ##-- parse input
  ($id,$off,$len,$txt) = split(/\t/,$_);

  ##--------------------------------------------
  if ($id eq '$START$') {
    ##-- start-tag: slurp attributes
    $eltname        = $txt;
    $elt_start_line = $.;
    @attrs = qw();
    while (<>) {
      chomp;
      ($aid,$aoff,$alen,$atxt) = split(/\t/,$_);
      last if ($aid ne '$ATTR$');
      push(@attrs,$atxt);
    }
    $elt = { @attrs, __name__=>$eltname };

    ##-- start-tag: push to stack
    push(@eltstack, $elt);

    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if ($eltname eq 'seg') {
      ##-- start-tag: <seg> element

      ##-- start-tag: <seg>: close current range of previously open block
      $blk->{xranges}[$#{$blk->{xranges}}][1] = $off;
      $blk->{lranges}[$#{$blk->{lranges}}][1] = $elt_start_line;

      if ( ($elt->{part} && $elt->{part} eq 'I') || !($elt->{part}) )
	{
	  ##-- start-tag: <seg>: initial
	  $key = "seg.$off";
	  $blk = {
		  key=>$key,
		  typ=>'seg',
		  xranges=>[ [$off, $off+$len] ],
		  lranges=>[ [$elt_start_line, $.] ],
		 };
	  $lastblk{'seg'} = $blk if ($elt->{part});
	  $key2blk{$key} = $blk;
	  push(@blkstack,$blk);
	}
      elsif ( $elt->{part} ) ## ($elt->{part} eq 'M' || $elt->{part} eq 'F')
	{
	  ##-- start-tag: <seg>: non-initial
	  $blk = $lastblk{'seg'}; ##-- get last opened seg[@part="I"]
	  push(@{$blk->{xranges}}, [$off, $off+$len]);
	  push(@{$blk->{lranges}}, [$elt_start_line, $.]);
	  push(@blkstack,$blk);
	}
    }
    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    elsif (exists($implicit_block_elts{$eltname})) {
      ##-- start-tag: <note> etc.: implicit block
      if ($blk->{typ} ne 'seg') {
	##-- start-tag: <note> etc.: no parent <seg>: allocate a new block
	$key = "${eltname}.${off}";
	$blk = {
		key=>$key,
		typ=>$eltname,
		xranges=>[ [$off, $off+$len] ],
		lranges=>[ [$elt_start_line, $.] ],
	       };
	$key2blk{$key} = $blk;
      }
      push(@blkstack,$blk);
    }
    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    else { # ($eltname =~ m/./)
      ##-- start-tag: default: just inherit current block, keep range running
      push(@blkstack, $blk);
    }
    #$_=<>; ##-- DON'T slurp more (we got the next line when reading $ATTRS)
  }
  ##--------------------------------------------
  elsif ($id eq '$END$') {
    ##-- end-tag event: update ranges & pop stacks
    $pblk = pop(@blkstack);
    $pblk->{xranges}[$#{$pblk->{xranges}}][1] = $off+$len;
    $pblk->{lranges}[$#{$pblk->{lranges}}][1] = $.+1;

    $blk = $blkstack[$#blkstack];
    if ($blk ne $pblk) {
      ##-- block switch: open a new range in the re-opened block popped from the stack
      push(@{$blk->{xranges}}, [$off+$len, $off+$len]);
      push(@{$blk->{lranges}}, [$.+1, $.+1]);
    }

    $_=<>; ##-- slurp more
  }
  ##--------------------------------------------
  else {
    ##-- other event (e.g. char): keep current block open
    $_=<>; ##-- slurp more
  }
}

##-- output block-ranges
our @blocks = sort { $a->{xranges}[0][0] <=> $b->{xranges}[0][0] } values(%key2blk);
foreach $blk (@blocks) {
  my $key = $blk->{key};
  my $typ = $blk->{typ};
  foreach $xr (@{$blk->{xranges}}) {
    print "XRANGE\t$typ\t$key\t$xr->[0]\t$xr->[1]\n";
  }
#  foreach $lr (@{$blk->{lranges}}) {
#    print "LRANGE\t$typ\t$key\t$lr->[0]\t$lr->[1]\n";
#  }
}
