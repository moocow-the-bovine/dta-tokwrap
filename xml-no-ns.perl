#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
#use Encode qw(encode decode);
use File::Basename qw(basename);
#use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;


##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);

##-- debugging
our $DEBUG = 0;

##-- vars: I/O
our $outfile = "-"; ##-- default: stdout

##-- XML::Parser stuff
our ($xp); ##-- underlying XML::Parser object

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'output|out|o=s' => \$outfile,
	  );


pod2usage({
	   -exitval=>0,
	   -verbose=>0,
	  }) if ($help);

##======================================================================
## Subs

##--------------------------------------------------------------
## XML::Parser handlers

## undef = cb_default($expat, $str)
sub cb_default {
  $ostr = $_[0]->original_string;
  $outfh->print($_[0]->original_string);
}

## undef = cb_start($expat, $elt,%attrs)
sub cb_start {
  ($elt,@attrs) = @_[1..$#_];
  $elt =~ s/:/_/g;
  foreach $i (0..$#attrs) {
    $a = $attrs[$i];
    if ($i % 2 == 0) {
      $a =~ s/^xmlns/no_xmlns/;
      $a =~ s/:/_/g;
    }
    $a =~ s/&lt;/</g;
    $a =~ s/&gt;/>/g;
    $a =~ s/&quot;/\"/g;
    $a =~ s/&apos;/\'/g;
    $a =~ s/&amp;/&/g;
    $attrs[$i] = $a;
  }
  $ostr = $_[0]->original_string;
  $outfh->print("<$elt",
		(map {
		  ($_ % 2 == 0 ? " $attrs[$_]" : "=\"$attrs[$_]\"")
		} (0..$#attrs)),
		($ostr =~ /\/>$/ ? "/>" : ">"),
	       );
}

## undef = cb_end($expat, $elt)
sub cb_end {
  $ostr = $_[0]->original_string;
  $ostr =~ s/:/_/g;
  $outfh->print($ostr);
}

##======================================================================
## MAIN

##-- initialize XML::Parser
$xp = XML::Parser->new(
		       ErrorContext => 1,
		       #ProtocolEncoding => 'UTF-8',
		       #ParseParamEnt => '???',
		       Handlers => {
				    Start => \&cb_start,
				    End   => \&cb_end,
				    Default => \&cb_default,
				   },
		      )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
$outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- parse file(s)
foreach $infile (@ARGV) {
  $xp->parsefile($infile);
}
$outfh->close();
