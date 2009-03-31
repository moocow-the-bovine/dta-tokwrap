#!/usr/bin/perl -w

##======================================================================
## Globals

##-- unique identifier for ROOT block
our $rootKey = '__ROOT__';

##-- @eltstack = (\%rootEltAttrs, ..., \%currentEltAttrs)
##  + each \%attrs element has an additional '__name__' attribute
our $rootElt = { __name__ => '__ROOT__' };
our @eltstack = ( $rootElt );

##-- @blkstack = ($rootKey, ..., $currentKey)
## + mirrors @eltstack
our @blkstack = ( $rootKey );

##-- $blk : key of current block
our $blk = $rootKey;

##-- @implicit_block_elts
## + create new blocks for these elements, unless they occur as a daughter of a 'seg' element
our @implicit_block_elts = (
			    ##-- title page stuff
			    qw(titlePage titlePart docTitle byline docAuthor docImprint pubPlace docDate),
			    ##
			    ##-- main text body
			    qw(p div head text front back body),
			    ##
			    ##-- genre-specific: drama
			    qw(speaker sp stage castList castItem role roleDesc set),
			    ##
			    ##-- citations
			    qw(cit q quote),
			    ##
			    ##-- genre-specific: letters
			    qw(salute dateline opener closer signed),
			    ##
			    ##-- tables
			    qw(table row cell),
			    ##
			    ##-- lists
			    qw(list item),
			    ##
			    ##-- notes etc
			    qw(note argument),
			    ##
			    ##-- misc
			    qw(figure ref fw),
			   );
our %implicit_block_elts = map {$_=>undef} @implicit_block_elts;

##======================================================================
## MAIN
our ($id,$off,$len,$txt);
our ($aid,$aoff,$alen,$atxt);

our ($eltname,$elt,@attrs);

$_ = <>;
while (defined($_)) {
  $_buf = $_;
  chomp;
  if (/^%%/) {
    ##-- (mostly) ignore comments
    print $_buf;
    $_=<>;
    next;
  };

  ##-- parse input
  ($id,$off,$len,$txt) = split(/\t/,$_);

  ##--------------------------------------------
  if ($id eq '$START$') {
    ##-- start-tag: slurp attributes
    $eltname = $txt;
    @attrs = qw();
    while (<>) {
      print $_buf;
      $_buf = $_;
      chomp;
      ($aid,$aoff,$alen,$atxt) = split(/\t/,$_);
      last if ($aid ne '$ATTR$');
      push(@attrs,$atxt);
    }
    $_ .= "\n";
    $elt = { @attrs, __name__=>$eltname };

    ##-- start-tag: push to stack
    push(@eltstack, $elt);

    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    if ($eltname eq 'seg') {
      ##-- start-tag: <seg> element

      if ( ($elt->{part} && $elt->{part} eq 'I') || !($elt->{part}) )
	{
	  ##-- start-tag: <seg>: initial
	  $blk = $key = "seg.$off";
	  $lastblk{'seg'} = $blk if ($elt->{part});
	  push(@blkstack,$blk);
	  print "\$BLOCK\$\t", ($off+$len), "\t0\t$key\n";
	}
      elsif ( $elt->{part} ) ## ($elt->{part} eq 'M' || $elt->{part} eq 'F')
	{
	  ##-- start-tag: <seg>: non-initial
	  $blk = $key = $lastblk{'seg'}; ##-- get last opened seg[@part="I"]
	  push(@blkstack,$blk);
	  print "\$BLOCK\$\t", ($off+$len), "\t0\t$key\n";
	}
    }
    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    elsif (exists($implicit_block_elts{$eltname})) {
      ##-- start-tag: <note> etc.: implicit block
      if ($blk !~ /^seg\b/) {
	##-- start-tag: <note> etc.: no parent <seg>: allocate a new block
	$blk = $key = "${eltname}.${off}";
	print "\$BLOCK\$\t", ($off+$len), "\t0\t$key\n";
      }
      push(@blkstack,$blk);
    }
    ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    else { # ($eltname =~ m/./)
      ##-- start-tag: default: just inherit current block, keep range running
      push(@blkstack, $blk);
      #print STDERR "inheriting block '$blk' for <$eltname>\n";
    }
    #$_=<>; ##-- DON'T slurp more (we got the next line when reading $ATTRS)
  }
  ##--------------------------------------------
  elsif ($id eq '$END$') {
    ##-- end-tag event: update ranges & pop stacks
    $pblk = pop(@blkstack);
    $blk  = $blkstack[$#blkstack];
    if ($blk ne $pblk) {
      ##-- block switch: re-open the block we popped from the stack
      print $_buf, "\$BLOCK\$\t", ($off+$len), "\t0\t$blk\n";
      $_buf='';
    }
    $_=<>; ##-- slurp more
  }
  ##--------------------------------------------
  else {
    ##-- other event (e.g. char): keep current block open
    $_=<>; ##-- slurp more
  }
  print $_buf; ##-- dump last event
}
