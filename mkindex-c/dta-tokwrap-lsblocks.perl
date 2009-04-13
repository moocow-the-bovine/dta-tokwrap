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
our $DEBUG_TXT = 0;

##-- prog
our $prog = File::Basename::basename($0);

##-- $rootBlk : root block
## + block structure:
##   {
##    key    =>$sortkey, ##-- inherited sort key
##    elt    =>$eltname, ##-- element name which created this block
##    xbegin =>$xoff,    ##-- XML byte offset where this block run begins
##    xend   =>$xoff1,   ##-- XML byte offset where this block run ends
##    tbegin =>$toff0,   ##-- text byte offset where this block run begins
##    tend   =>$toff1,   ##-- text byte offset where this block run ends
##   }
our $rootBlk = {key=>'__ROOT__',elt=>'__ROOT__',xbegin=>0,tbegin=>0, xend=>undef, tend=>undef};

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

our ($_xp,$eltname,%attrs,$item,$iblk);

##-- $xoff,$toff: global: current XML-, text-byte offset
our ($xoff,$toff) = (0,0);

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
    ($xoff,$toff) = split(/ /,$attrs{n}) if (exists($attrs{n}));
    push(@blocks, $blk={ key=>$key, elt=>$eltname, xbegin=>$xoff, tbegin=>$toff });
  }
}

## undef = cb_end($expat, $elt)
sub cb_end {
  pop(@keystack);
  $key = $keystack[$#keystack];
}

##--------------------------------------------------------------
## Subs: assign block '*end', '*len' keys

##-- undef = compute_block_lengths(\@blocks)
sub compute_block_lengths {
  my $blocks = shift;
  my ($prv,$nxt);
  foreach $nxt (@$blocks) {
    ##-- defaults
    @$nxt{qw(xend tend)} = @$nxt{qw(xbegin tbegin)};
    @$nxt{qw(xlen tlen ttlen)} = (0,0,0);

    ##-- specials
    if    ($nxt->{elt} eq 'w') { $nxt->{ttext}=$WB; $nxt->{ttlen}=length($WB); }
    elsif ($nxt->{elt} eq 's') { $nxt->{ttext}=$SB; $nxt->{ttlen}=length($SB); }

    if (!defined($prv)) { $prv=$nxt; next; }
    elsif ($prv->{elt} ne 'c') { $prv=$nxt; next; }
    elsif ($nxt->{elt} ne 'c') { next; }

    @$prv{qw(xend tend)} = @$nxt{qw(xbegin tbegin)};
    $prv->{xlen} = $prv->{xend} - $prv->{xbegin};
    $prv->{tlen} = $prv->{tend} - $prv->{tbegin};
    $prv = $nxt;
  }
}

##-- undef = prune_empty_blocks(\@blocks)
## + removes empty 'c'-type blocks
sub prune_empty_blocks {
  my $blocks = shift;
  @$blocks = grep { $_->{elt} ne 'c' || $_->{tlen} > 0 } @$blocks;
}

##-- \@sorted = sort_blocks(\@blocks)
sub sort_blocks {
  my $blocks = shift;
  return [
	  sort {
	    ($key2i{$a->{key}} <=> $key2i{$b->{key}}
	     || $a->{key} cmp $b->{key}
	     || $a->{xbegin} <=> $b->{xbegin})
	   } @$blocks
	  ];
}

##-- undef = compute_output_lengths(\@sorted_blocks)
##  + sets $blk->{ttbegin}, $blk->{ttlen} for each block
sub compute_output_lengths {
  my $blocks = shift;
  my $off = 0;
  my ($blk);
  foreach $blk (@$blocks) {
    $blk->{ttlen}   = $blk->{tlen} if (!defined($blk->{ttlen}));
    $blk->{ttbegin} = $off;
    $off += $blk->{ttlen};
  }
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

##-- parse file(s): annotated structure index
$xp->parsefile($sxfile);

##-- compute (raw) block lengths & sort
compute_block_lengths(\@blocks);
prune_empty_blocks(\@blocks);

$sblocks = sort_blocks(\@blocks);
compute_output_lengths($sblocks);

##-- extract text
$txbuf = '';
slurp_file($txfile,\$txbuf);
open(TXT,">$txtfile") or die("$0: open failed for output .txt file '$txtfile': $!");
foreach $blk (@$sblocks) {
  print TXT
    (
     ($DEBUG_TXT ? "[$blk->{key}:$blk->{elt}]\n" : qw()),
     (defined($blk->{ttext}) ? $blk->{ttext} : substr($txbuf,$blk->{tbegin},$blk->{tlen})),
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
   "%% \$KEY\$\t\$ELT\$\t\$XML_OFFSET\$\t\$XML_LENGTH\$\t\$TXT_OFFSET\$\t\$TXT_LEN\$\n",
   (map {join("\t", @$_{qw(key elt xbegin xlen tbegin tlen)})."\n"} @$sblocks),
  );
close(BX);
