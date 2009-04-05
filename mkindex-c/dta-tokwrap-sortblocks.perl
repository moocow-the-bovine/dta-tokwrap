#!/usr/bin/perl -w

##======================================================================
## Globals

##--------------------------------------------------------------
## Globals: Flags & Options

our $warn_on_default_sortkey = 1;

##--------------------------------------------------------------
## Globals: Central data structures

##-- $blks : { $blockKey => \%blk, ... }
our $blks = {};

##--------------------------------------------------------------
## Globals: Block-Sorting

##-- %typ2sortkey : ( $blockType => $blockSortKey, ... )
## + maps block types to block-sorting string keys
## + block types are returned by the key2type() function
our $SK_TITLE = '00_TITLE';
our $SK_MAIN  = '10_MAIN';
our $SK_MISC  = '20_MISC';
our $SK_IGNORE = '99_IGNORE';
our %typ2sortkey =
  (
   ##-- title page
   (map {$_=>$SK_TITLE} qw(titlePage titlePart docTitle byline docAuthor docImprint publisher pubPlace docDate)),

   ##-- main text
   (map {$_=>$SK_MAIN} qw(p div head text front back body __ROOT__)),

   ##-- main text: lists
   (map {$_=>$SK_MAIN} qw(list item)),

   ##-- main text: verse
   (map {$_=>$SK_MAIN} qw(lg l)),

   ##-- main text: quotes
   (map {$_=>$SK_MAIN} qw(cit quote q)),

   ##-- misc: : tables
   #(map {$_=>$SK_MAIN} qw(table row cell)),
   (map {$_=>$SK_MISC} qw(table row cell)),

   ##-- misc: footnotes etc.
   (map {$_=>$SK_MISC} qw(seg note argument)),

   ##-- misc: figures etc
   (map {$_=>$SK_MISC} qw(figure ref fw)),

   ##-- ignored
   #(map {$_=>$SK_IGNORE} qw(ref fw)),
   (map {$_=>$SK_IGNORE} qw(TEI teiHeader fileDesc title titleStmt publicationStmt sourceDesc)),
   'ref' => $SK_IGNORE,
   'fw'  => $SK_IGNORE,
  );

##-- $SORTKEY_DEFAULT : default sort key if not specified in %typ2sortkey
our $DEFAULT_SORTKEY = $SK_MAIN;


##--------------------------------------------------------------
## Globals: Implicit Inter-Block Breaks

##-- %breakText : ( $breakName => $breakText, ... )
##  + text to splice in for implicit breaks
our %breakText =
  (
   'l' => "\n",         ##-- line break
   'w' => "\n\$TB\$\n", ##-- token (word) break
   's' => "\n\$SB\$\n", ##-- sentence break (should imply a token break too)
  );

##-- useful aliases
our $SB = [['s'], ['s']]; ##-- $SB : sentence break on block begin and end; see %typ2breaks
our $TB = [['w'], ['w']]; ##-- $TB : token break on block begin and end; see %typ2breaks
our $LB = [[], ['l']];    ##-- $LB : line break on block end

##-- %typ2breaks : ( $blockType => [ \@breaksOnBlockStart, \@breaksOnBlockEnd ], ... )
## + maps block types to implicit breaks
our %typ2breaks =
  (
   ##-- title page
   titlePage => $SB,
   (map {$_=>$TB} qw(byline titlePart docAuthor docImprint pubPlace publisher docDate)),

   ##-- main text: common
   (map {$_=>$SB} qw(div p text front back body)),
   head => $TB,

   ##-- main text: citations (TODO: check real examples)
   (map {$_=>$TB} qw(cit q quote)),

   ##-- main text: drama (TODO: check real examples)
   (map {$_=>$SB} qw(speaker sp stage castList castItem role roleDesc set)),

   ##-- main text: letters (TODO: check real examples)
   (map {$_=>$TB} qw(salute dateline opener closer signed)),

   ##-- tables (TODO: check real examples)
   (map {$_=>$SB} qw(table)),
   (map {$_=>$TB} qw(row cell)),

   ##-- lists (TODO: check real examples)
   (map {$_=>$SB} qw(list)),
   (map {$_=>$TB} qw(item)),

   ##-- notes etc
   (map {$_=>$SB} qw(seg note argument)),

   ##-- misc
   (map {$_=>$SB} qw(figure ref fw)),
  );

##======================================================================
## Subs

##--------------------------------------------------------------
## Subs: I/O

## \@blocks = read_blockfile($blkfile)
##  + blocks are returned in the same order they occur read from $filename
sub read_blockfile {
  my ($filename) = shift;
  open(BLOCKS,"<$filename")
    or die("$0: open failed for block-file '$filename': $!");
  my $blks = [];
  my ($blk, $id, $xoff,$xlen, $toff,$tlen, $key);
  while (<BLOCKS>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    ($id, $xoff,$xlen, $toff,$tlen, $key) = split(/\t/,$_);
    $blk = { key=>$key, xoff=>$xoff, xlen=>$xlen, toff=>$toff,tlen=>$tlen };
    push(@$blks, $blk);
  }
  close(BLOCKS);
  return $blks;
}

##--------------------------------------------------------------
## Subs: block typing

## $blockType = key2type($blockKey)
##  + default just truncates trailing any trailing dots (.) and digits from $blockKey
sub key2type {
  my $key = shift;
  $key =~ s/[\.\d]*$//;
  return $key;
}

##--------------------------------------------------------------
## Subs: block list manipulation

## \@sorted = sortblocks(\@blocks)
sub sortblocks {
  my $blks = shift;
  return [
	  sort {
	    (($a->{sortkey} cmp $b->{sortkey})
	     ||
	     ($a->{xoff} <=> $b->{xoff})
	     ||
	     ($a->{key} cmp $b->{key})
	    )
	  } @$blks
	 ];
}

## \@blocks = mark_block_boundaries(\@blocks);
##  + marks initial and final block elements for each block key
##  + \@blocks is assumed to be properly sorted
##  + initial blocks are marked with $blk->{initial}=1
##  + final blocks are marked with $blk->{final}=1
##  + returns modified \@blocks
sub mark_block_boundaries {
  my $blks = shift;
  my %known = qw();
  foreach (@$blks) {
    $_->{initial}=1 if (!exists($known{$_->{key}}));
    $known{$_->{key}} = undef;
  }
  %known = qw();
  foreach (reverse(@$blks)) {
    $_->{final}=1 if (!exists($known{$_->{key}}));
    $known{$_->{key}} = undef;
  }
  return $blks;
}

## \@blocksWithBreaks = insert_implicit_breaks(\@blocksWithoutBreaks)
##  + inserts pseudo-blocks for breaks
##  + adds block key(s):
##    $blk->{tboff}=$adjusted_text_offset
##  + returns new array-ref
sub insert_implicit_breaks {
  use bytes;
  my $blks = shift;
  my $tboff = 0;  ##-- total number of break-bytes we've "written"
  my $oblks = [];
  my ($breaks,$brkname,$brktext, $brkblk);
  foreach $blk (@$blks) {
    ##-- check for ignored blocks: just copy (ignore them later)
    if ($blk->{sortkey} eq $SK_IGNORE) {
      push(@$oblks,$blk);
      next;
    }

    ##-- get implicit breaks
    $breaks=$typ2breaks{$blk->{typ}};

    ##-- implicit breaks: initial
    foreach $brkname ($blk->{initial} && $breaks && $breaks->[0] ? @{$breaks->[0]} : qw()) {
      $brktext = $breakText{$brkname};
      $brkblk = { typ=>"BREAK.${brkname}",
		  key=>"BREAK.$blk->{key}.pre.${brkname}",
		  sortkey=>$blk->{sortkey},
		  text=>$brktext,
		  tboff=>$tboff,
		  tblen=>length($brktext),
		  xoff=>$blk->{xoff},xlen=>0,toff=>0,tlen=>0, ##-- for consistency
		};
      push(@$oblks, $brkblk);
      $tboff += length($brktext);
    }

    ##-- mark adjusted text offset for target block
    $blk->{tboff} = $tboff;
    push(@$oblks, $blk);
    $tboff += $blk->{tlen};

    ##-- insert final breaks
    foreach $brkname ($blk->{final} && $breaks && $breaks->[1] ? @{$breaks->[1]} : qw()) {
      $brktext = $breakText{$brkname};
      $brkblk = { typ=>"BREAK.${brkname}",
		  key=>"BREAK.$blk->{key}.post.${brkname}",
		  sortkey=>$blk->{sortkey},
		  text=>$brktext,
		  tboff=>$tboff,
		  tblen=>length($brktext),
		  xoff=>$blk->{xoff}+$blk->{xlen},xlen=>0,toff=>0,tlen=>0, ##-- for consistency
		};
      push(@$oblks, $brkblk);
      $tboff += length($brktext);
    }
  }

  return $oblks;
}

##======================================================================
## MAIN

##-- command-line
if (@ARGV < 1) {
  print STDERR "Usage: $0 BXFILE > SBXFILE\n";
  exit(1);
}
our $bxfile = shift;

##-- slurp text file
#our $txbuf = '';
#our $slurped = slurp_textfile($txfile,\$txbuf);
#print STDERR "$0: read $slurped bytes from text file '$txfile'\n";

##-- read block-file into index
$blks = read_blockfile($bxfile);
print STDERR "$0: read ", scalar(@$blks), " blocks from block file '$bxfile'\n";

##-- compute block types & sort-keys
foreach $blk (@$blks) {
  $blk->{typ} = key2type($blk->{key}) if (!defined($blk->{typ}));
  if (!defined($blk->{sortkey})) {
    if (!defined($blk->{sortkey}=$typ2sortkey{$blk->{typ}})) {
      warn("$0: using default sort key '$DEFAULT_SORTKEY' for block type '$blk->{typ}'\n") if ($warn_on_default_sortkey);
      $blk->{sortkey} = $typ2sortkey{$blk->{typ}} = $DEFAULT_SORTKEY; ##-- only warn once
    }
  }
}

##-- sort blocks
our $sblks = sortblocks($blks);

##-- mark initial and final blocks for each block-key
mark_block_boundaries($sblks);

##-- splice in pseudo-blocks for breaks
$bblks = insert_implicit_breaks($sblks);

##-- print output file
our $nout=0;
print
  ("%% XML serial block list file, generated by $0\n",
   "%% Command-line: $0 ", join(' ', map {"'$_'"} @ARGV), "\n",
   "%%======================================================================\n",
   "%% ", join("\t", map {"\$$_\$"} qw(KEY TYP SORTKEY XML_OFFSET XML_LENGTH TX_OFFSET TX_LENGTH)), "\n",
   (
    map { ++$nout; join("\t", map {defined($_) ? $_ : '?'} @$_{qw(key typ sortkey xoff xlen toff tlen)})."\n" }
    #grep {$_->{sortkey} ne $SK_IGNORE}
    @$bblks
   ),
  );
print STDERR "$0: wrote $nout blocks and breaks to stdout\n";

##-- dump text
#  print
#    (map { defined($_->{text}) ? $_->{text} : substr($txbuf, $_->{toff},$_->{tlen}) }
#     grep { $_->{sortkey} ne $SK_IGNORE }
#     @$bblks
#    );
