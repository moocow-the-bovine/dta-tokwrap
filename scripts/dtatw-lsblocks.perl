#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
#use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

##======================================================================
## Globals

##-- $WB : token-break text
our $WB = "\n\$WB\$\n";

##-- $SB : sentence-break text
our $SB = "\n\$SB\$\n";

##-- $DEBUG_TXT: include debugging output in .txt file?
our ($DEBUG_TXT);
#$DEBUG_TXT = 1;

##-- prog
our $prog = File::Basename::basename($0);

##-- $rootBlk : root block
## + block structure:
##   {
##    key    =>$sortkey, ##-- inherited sort key
##    elt    =>$eltname, ##-- element name which created this block
##    xoff   =>$xoff,    ##-- XML byte offset where this block run begins
##    xlen   =>$xlen,    ##-- XML byte offset where this block run ends
##    toff   =>$toff,    ##-- raw-text byte offset where this block run begins
##    tlen   =>$tlen,    ##-- raw-text byte offset where this block run ends
##   }
our $rootBlk = {key=>'__ROOT__',elt=>'__ROOT__',xoff=>0,xlen=>0, toff=>0,tlen=>0};

##-- @blocks: all parsed blocks
our @blocks = ( $rootBlk );

##-- @keystack: stack of (inherited) sort keys
our @keystack = ( $rootBlk->{key} );

##-- %key2i : maps keys to the block-index of their first occurrence, for block-sorting
our %key2i = ($rootBlk->{key} => 0);

##-- $blk: global: currently running block
our $blk = $rootBlk;

##-- $key: global: currently active sort key
our $key = $keystack[$#keystack];

##-- $keyAttr : attribute name for sort keys
our $keyAttr = 'dta.tw.key';

##-- @target_elts : block-like elements
our @target_elts = qw(c s w);
our %target_elts = map {$_=>undef} @target_elts;


##======================================================================
## Subs

##--------------------------------------------------------------
## XML::Parser temporary globals

our ($_xp,$eltname,%attrs);

##-- $xoff,$toff: global: current XML-, text-byte offset
##-- $xlen,$tlen: global: current XML-, text-byte length
our ($xoff,$xlen, $toff,$tlen) = (0,0,0,0);

##--------------------------------------------------------------
## XML::Parser handlers: build %key2obj

## undef = cb_start($expat, $elt,%attrs)
sub cb_start {
  ($_xp,$eltname,%attrs) = @_;

  ##-- check for sort key
  if (exists($attrs{$keyAttr})) {
    $key = $attrs{$keyAttr};
    $key2i{$key} = scalar(@blocks);
  }

  ##-- update key stack
  push(@keystack,$key);

  ##-- check for target elements
  if (exists($target_elts{$eltname})) {
    ($xoff,$xlen, $toff,$tlen) = split(/ /,$attrs{n}) if (exists($attrs{n}));
    push(@blocks, $blk={ key=>$key, elt=>$eltname, xoff=>$xoff,xlen=>$xlen, toff=>$toff,tlen=>$tlen });
  }
}

## undef = cb_end($expat, $elt)
sub cb_end {
  pop(@keystack);
  $key = $keystack[$#keystack];
}

##--------------------------------------------------------------
## Subs: assign block '*end', '*len' keys

##-- \@blocks = prune_empty_blocks(\@blocks)
## + removes empty 'c'-type blocks
sub prune_empty_blocks {
  my $blocks = shift;
  @$blocks = grep { $_->{elt} ne 'c' || $_->{tlen} > 0 } @$blocks;
  return $blocks;
}

##-- \@blocks = sort_blocks(\@blocks)
##  + sorts \@blocks
sub sort_blocks {
  my $blocks = shift;
  @$blocks = (
	      sort {
		($key2i{$a->{key}} <=> $key2i{$b->{key}}
		 || $a->{key}  cmp $b->{key}
		 || $a->{xoff} <=> $b->{xoff})
	      } @$blocks
	     );
  return $blocks;
}

##-- \@blocks = compute_block_text(\@blocks, \$txtbuf)
##  + \@blocks should already have been sorted
##  + sets $blk->{otoff}, $blk->{otlen}, $blk->{otext} for each block
sub compute_block_text {
  my ($blocks,$txtbufr) = @_;
  my $otoff = 0;
  my ($blk);
  foreach $blk (@$blocks) {
    ##-- specials
    if    ($blk->{elt} eq 'w') { $blk->{otext}=$WB; }
    elsif ($blk->{elt} eq 's') { $blk->{otext}=$SB; }
    else {
      $blk->{otext} = substr($$txtbufr, $blk->{toff}, $blk->{tlen});
    }
    $blk->{otoff} = $otoff;
    $blk->{otlen} = length($blk->{otext});
    $otoff += $blk->{otlen};
  }
  return $blocks;
}

##--------------------------------------------------------------
## File slurp

## \$txtbuf = slurp_file($filename,\$txtbuf);
sub slurp_file {
  my ($file,$bufr) = @_;
  if (!defined($bufr)) {
    my $buf = '';
    $bufr = \$buf;
  }
  open(SLURP,"<$file") or die("$0: open failed for slurp from file '$file': $!");
  local $/=undef;
  $$bufr = <SLURP>;
  close(SLURP);
  return $bufr;
}


##======================================================================
## MAIN

##-- initialize XML::Parser
$xp = XML::Parser->new(
		       ErrorContext => 1,
		       ProtocolEncoding => 'UTF-8',
		       #ParseParamEnt => '???',
		       Handlers => {
				    #Init  => \&cb_init,
				    Start => \&cb_start,
				    End   => \&cb_end,
				    #Char  => \&cb_char,
				    #Final => \&cb_final,
				   },
		      )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
if (@ARGV < 2) {
  print STDERR "Usage: $0 SXFILE TXFILE [BXFILE [TXTFILE]]\n";
  exit 1;
}
our ($sxfile, $txfile, $bxfile, $txtfile) = @ARGV;
$bxfile = '-' if (!defined($bxfile));
$txtfile = '-' if (!defined($txtfile));

##-- slurp raw-text into buffer $txbuf
$txbuf = '';
slurp_file($txfile,\$txbuf);

##-- parse structure file(s): annotated structure index
$xp->parsefile($sxfile);

##-- prune empty blocks & serialize (sort)
prune_empty_blocks(\@blocks);
sort_blocks(\@blocks);
compute_block_text(\@blocks,\$txbuf);

##-- output: txt
open(TXT,">$txtfile") or die("$0: open failed for output .txt file '$txtfile': $!");
foreach $blk (@blocks) {
  print TXT
    (
     ($DEBUG_TXT ? "[$blk->{key}:$blk->{elt}]\n" : qw()),
     $blk->{otext},
     ($DEBUG_TXT ? "\n[/$blk->{key}:$blk->{elt}]\n" : qw()),
    );
}
close(TXT);

##-- list blocks
open(BX,">$bxfile") or die("$0: open failed for output .bx file '$bxfile': $!");
print BX
  (
   "%% XML block list file generated by $0\n",
   "%% Command-line: $0 ", join(' ', map {"'$_'"} @ARGV), "\n",
   "%%======================================================================\n",
   "%% \$KEY\$\t\$ELT\$\t\$XML_OFFSET\$\t\$XML_LENGTH\$\t\$TX_OFFSET\$\t\$TX_LEN\$\t\$TXT_OFFSET\$\t\$TXT_LEN\$\n",
   (map {join("\t", @$_{qw(key elt xoff xlen toff tlen otoff otlen)})."\n"} @blocks),
  );
close(BX);
