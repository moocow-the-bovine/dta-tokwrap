#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

##======================================================================
## Globals
our $prog = basename($0);

##======================================================================
## Command-line

##======================================================================
## Subs: file buffering

## \$str = bufferFile($filename)
## \$str = bufferFile($filename,\$str)
##   + buffers $filename contents to $str
sub bufferFile {
  my ($file,$bufr) = @_;
  if (!$bufr) {
    my $buf = '';
    $bufr = \$buf;
  }
  open(SRC,"<$file")
    or die("$prog: open failed for input file '$file': $!");
  binmode(SRC);
  local $/=undef;
  $$bufr = <SRC>;
  close(SRC);
  return $bufr;
}

##======================================================================
## Subs: xml: tree-building

##--------------------------------------------------------------
## XML::Parser handlers (for tree-building)

our ($_xp, $_elt, %_attrs);

## $eltPackAs
##  + pack-format for packing element records
##  + args: ($eltName, $eltId, $startOff,$startLen, $endOffset,$endLen, $momId, $nDtrs,@dtrIds)
our $eltPackAs   = '(Z*)(L)(LL)(LL)(L)(L/L*)';
#our $eltUnpackAs = '(Z*)(L)(LL)(LL)(L)(LX[4]/L*)';

## @eltPackArgs
##  + argument names for $eltPackAs
our @eltPackArgs = qw(name id startOff startLen endOff endLen momId); #nDtrs dtrIds

## @epacked = ($e0_packed, ..., $eN_packed)
our @epacked  = qw();

## @estack = (\%rootData, ..., \%eltIData)
our @estack = qw();

## $id
##  + next node id (0 indicates missing node)
our ($id);

##-- temps
our ($e);

## undef = cb_init($expat)
sub cb_init {
  #($_xp) = @_;
  $id = 1;
  my $root = { name=>'__ROOT__', id=>$id++, startOff=>0,startLen=>0, momId=>0,dtrIds=>[] };
  # endOff,endLen,nDtrs: later
  @estack = ($root);
  @epacked = qw();
}

## undef = cb_start($expat, $elt,%attrs)
sub cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  push(@{$estack[$#estack]{dtrIds}}, $id++);
  push(@estack, {
		 name=>$_[1],
		 id=>$id,
		 startOff=>$_[0]->current_byte,
		 startLen=>length($_[0]->original_string),
		 momId=>$estack[$#estack]{id},
		});
}

## undef = cb_end($expat,$elt)
sub cb_end {
  $e = pop(@estack);
  @$e{qw(endOff endLen)} = ($_[0]->current_byte, length($_[0]->original_string));
  push(@epacked, pack($eltPackAs, @$e{@eltPackArgs}, ($e->{dtrs} ? @{$e->{dtrs}} : qw())));
}

##======================================================================
## MAIN

##-- initialize XML::Parser (for .w.xml file)
our $xp = XML::Parser->new(
			   ErrorContext => 1,
			   ProtocolEncoding => 'UTF-8',
			   #ParseParamEnt => '???',
			   Handlers => {
					Init  => \&cb_init,
					#Char  => \&cb_char,
					Start => \&cb_start,
					End   => \&cb_end,
					#Default => \&cb_default,
					#Final => \&cb_final,
				       },
			   )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- buffer input file
our $xmlfile = shift(@ARGV);
our $xmldata = '';
bufferFile($xmlfile,\$xmldata);

##-- build tree
$xp->parse($xmldata);

##-- show some stats
print STDERR
  ("$prog: parsed ", 0+@epacked, " elements from ", length($xmldata), " XML bytes\n",
  );

##-- output ?

