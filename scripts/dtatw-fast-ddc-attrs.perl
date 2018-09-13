#!/usr/bin/perl -w

use XML::Parser;
use File::Basename qw(basename);
use Getopt::Long qw(:config no_ignore_case);
use strict;

##------------------------------------------------------------------------------
## Command-line
our $prog = basename($0);
our $outfile = '-';
our ($help);
GetOptions(##-- General
	   'help|h' => \$help,
	   'o|out|output=s' => \$outfile,
	  );
if ($help) {
  print STDERR <<EOF;

Usage: $prog \[OPTIONS] T_XML_FILE

Options:
  -h, -help          # this help message
  -o, -out OUTFILE   # output file (t-xml with //w/\@ws)

EOF
  exit ($help ? 0 : 1);
}

##======================================================================
## Subs

##--------------------------------------------------------------
## XML::Parser handlers

our ($cur);   ##-- current (text) byte-offset
our ($outfh); ##-- output filehandle

## undef = cb_init($expat)
sub cb_init {
  $cur = -1;
}

## undef = cb_start($expat, $elt,%attrs)
my ($that,$elt,%attrs,$off,$len,$ws,$str);
sub cb_start {
  ($that,$elt,%attrs) = @_;
  if ($elt eq 'w' && $attrs{b}) {
    ($off,$len) = split(' ',$attrs{b},3);
    $ws = (($off//0) == $cur ? 0 : 1);
    $cur = $off+$len;
    $str = $_[0]->original_string;
    $str =~ s{(\/?>)\z}{ ws="$ws"$1};
    $str =~ s{\sx?b=\"[^\"]*\"}{}g;
    print $str;
  }
  else {
    print $that->original_string;
  }
}

## undef = cb_catchall($expat, ...)
##  + catch-all
sub cb_catchall {
  $outfh->print($_[0]->original_string);
}

## undef = cb_default($expat, $str)
*cb_default = \&cb_catchall;


##======================================================================
## MAIN

##-- initialize XML::Parser
my $xp = XML::Parser->new(
			  ErrorContext => 1,
			  ProtocolEncoding => 'UTF-8',
			  #ParseParamEnt => '???',
			  Handlers => {
				       Init  => \&cb_init,
				       Start => \&cb_start,
				       End => \&cb_default,
				       Char => \&cb_default,
				       Default => \&cb_default,
				       #Final => \&cb_final,
				      },
			 )
  or die("$prog: ERROR: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
open($outfh, ">$outfile")
  or die("$prog: ERROR: open failed for output file '$outfile': $!");

##-- tweak input file(s)
my ($buf);
foreach my $infile (@ARGV) {
  $prog = basename($0).": $infile";

  ##-- slurp input file (for file-based heuristics)
  open(XML,"<$infile") or die("$prog: ERROR: open failed for input file '$infile': $!");
  $xp->parse(\*XML);
  close XML;
}
close($outfh)
  or die("$prog: close failed for '$outfile': $!");

