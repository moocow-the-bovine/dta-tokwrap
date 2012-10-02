#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode_utf8 decode_utf8);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;


##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);

##-- debugging
our $DEBUG = 0;

##-- vars: I/O
our $xmlns = ''; #'xmlns:';  ##-- 'xml:' namespace prefix+colon for output id attributes (empty for none)
our $outfile = "-";          ##-- default: stdout


##-- profiling
our $profile = 0;
our $nchrs = 0;   ##-- total number of <c> tags generated
our $nxbytes = 0; ##-- total number of XML source bytes processed
our ($tv_started,$elapsed) = (undef,undef);

##-- XML::Parser stuff
our ($xp); ##-- underlying XML::Parser object

our $cnum = 0;           ##-- $cnum: global index of <c> element (number of elts read so far)
our $text_depth = 0;     ##-- number of open <text> elements
our $c_depth = 0;        ##-- number of open <c> elements (should never be >1)

our $guess_thresh = undef;   ##-- minimum percent of total input data bytes occurring in //c elements
                             ##   in order to return input document as-is (0: always process)
our $guess_default = 50;


##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'id-namespace|xmlns|idns|ns!' => sub { $xmlns=$_[1] ? "xml:" : ''; },
	   'guess|g!' => sub { $guess_thresh=($_[1] ? $guess_default : 0); },
	   'guess-min|gm=f' => \$guess_thresh,
	   'output|out|o=s' => \$outfile,
	   'profile|p!' => \$profile,
	  );


pod2usage({-exitval=>0,-verbose=>0}) if ($help);
$guess_thresh = $guess_default if (!defined($guess_thresh));

##======================================================================
## Subs

##--------------------------------------------------------------
## XML::Parser handlers

## undef = cb_init($expat)
sub cb_init {
  #$cnum = 0;
  $text_depth = 0;
  $c_depth = 0;
}

## undef = cb_char($expat,$string)
our ($c_block,$c_char,$c_rest);
sub cb_char {
  if ($text_depth <= 0 || $c_depth > 0) {
    $outfh->print($_[0]->original_string());
    return;
  }
  $c_block = decode_utf8( $_[0]->original_string() );
  while ($c_block =~ m/((?:\&[^\;]*\;)|(?:\s+)|(?:\X))/sg) {
    $c_char = $1;
    ##-- tricks for handling whitespace and newlines e.g. in:
    ##     http://kaskade.dwds.de/dtae/book/view/brandes_naturlehre02_1831?p=70
    if ($c_char =~ m/^\s+$/s) {
      ##-- whitespace (including newlines)
      $c_rest = encode_utf8($c_char);
      $c_char = ' ';
    } else {
      $c_rest = '';
    }
    $outfh->print("<c", ($c_rest ? ' type="dtatw:ws"' : qw()), " ${xmlns}id=\"c", ++$cnum, "\">",
		  encode_utf8($c_char),
		  "</c>",
		  $c_rest,
		 );
  }
}

## undef = cb_start($expat, $elt,%attrs)
our ($cs);
sub cb_start {
  if ($_[1] eq 'c') {
    ##-- pre-existing <c>: respect it
    if ($c_depth > 0) {
      $_[0]->xpcroak("$prog: ERROR: cowardly refusing to process input document with nested <c> elements!\n"
		     ."$prog: in file '$infile'");
    }
    ++$c_depth;
    $cs = $_[0]->original_string();
    if ($cs !~ m/\s(?:xml\:)?id=\"[^\"]+\"/io) {
      ##-- pre-existing <c> WITHOUT xml:id attribute: assign one
      ++$cnum;
      $cs =~ s|(/?>)$| ${xmlns}id="c$cnum"$1|o;
    }
    ##-- ... and print
    $outfh->print($cs);
    return;
  }
  ++$text_depth if ($_[1] eq 'text');
  $outfh->print($_[0]->original_string);
}

## undef = cb_end($expat, $elt)
sub cb_end {
  if ($_[1] eq 'c') { --$c_depth; }
  elsif ($_[1] eq 'text') { --$text_depth; }
  $outfh->print($_[0]->original_string);
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
$xp = XML::Parser->new(
		       ErrorContext => 1,
		       ProtocolEncoding => 'UTF-8',
		       #ParseParamEnt => '???',
		       Handlers => {
				    Init  => \&cb_init,
				    Char  => \&cb_char,
				    Start => \&cb_start,
				    End   => \&cb_end,
				    Default => \&cb_default,
				    #Final => \&cb_final,
				   },
		      )
  or die("$prog: ERROR: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
$outfh = IO::File->new(">$outfile")
  or die("$prog: ERROR: open failed for output file '$outfile': $!");

##-- initialize: profiling info
$tv_started = [gettimeofday] if ($profile);

##-- parse file(s)
foreach $infile (@ARGV) {
  ##-- slurp input file
  local $/=undef;
  open(XML,"<$infile") or die("$prog: ERROR: open failed for input file '$infile': $!");
  $buf = <XML>;
  close XML;

  ##-- optionally guess whether we need to add //c elements at all
  if ($guess_thresh > 0) {
    use bytes;
    my $inbytes = length($buf);
    my $cbytes  = 0;
    my $nc = 0;
    while ($buf =~ m|<c\b[^>]*>(?:[^<]{0,8})</c>|isgp) {
      $cbytes += length(${^MATCH});
      ++$nc;
    }
    my $cpct = $inbytes ? (100*$cbytes/$inbytes) : 'nan';
    #printf STDERR "$prog: found $cbytes bytes for <c> elements in $inbytes total bytes (%.1f%%)\n", $cpct;

    if ($cpct >= $guess_thresh) {
      ##-- enough <c>s already: just dump the buffer
      #printf STDERR "$prog: $infile contains %.1f%% //c data > threshhold=%s%% : dumping as-is\n", $cpct, $guess_thresh;
      $outfh->print($buf);
      $nxbytes += length($buf);
      $nchrs   += $nc;
      next;
    }
  }

  ##-- initialize $cnum counter by checking any pre-assigned //c/@id values (fast regex hack)
  $cnum = 0;
  while ($buf =~ m/\<c\b[^\>]*\s(?:xml\:)?id=\"c([0-9]+)\"/isg) {
    $cnum = $1 if ($1 > $cnum);
  }
  #print STDERR "$prog: initialized \$cnum=$cnum\n"; ##-- DEBUG

  ##-- assign new //c/@ids
  $xp->parse($buf);

  ##-- profile
  $nchrs   += $cnum;
  $nxbytes += (-s $infile) if ($infile ne '-');
}
$outfh->close();

##-- profiling / output
sub sistr {
  my $x = shift;
  return sprintf("%.1f T", $x/10**12) if ($x >= 10**12);
  return sprintf("%.1f G", $x/10**9)  if ($x >= 10**9);
  return sprintf("%.1f M", $x/10**6)  if ($x >= 10**6);
  return sprintf("%.1f K", $x/10**3)  if ($x >= 10**3);
  return sprintf("%.1f  ", $x)        if ($x >= 1);
  return sprintf("%.1f m", $x*10**3)  if ($x >= 10**-3);
  return sprintf("%.1f u", $x*10**6)  if ($x >= 10**-6);
}

if ($profile) {
  $elapsed = tv_interval($tv_started,[gettimeofday]);
  $chrsPerSec  = sistr($elapsed > 0 ? ($nchrs/$elapsed) : -1);
  $bytesPerSec = sistr($elapsed > 0 ? ($nxbytes/$elapsed) : -1);

  print STDERR
    (sprintf("%s: %.1f chars ~ %d XML-bytes in %.2f sec: %schr/sec ~ %sbyte/sec\n",
	     $prog, $nchrs,$nxbytes, $elapsed, $chrsPerSec, $bytesPerSec));
}


=pod

=head1 NAME

dtatw-add-c.perl - add <c> elements to DTA XML documents

=head1 SYNOPSIS

 dtatw-add-c.perl [OPTIONS] [XMLFILE(s)...]

 General Options:
  -help                  # this help message

 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))
  -guess-min PERCENT     # in -guess mode, minimum percentage of data in <c> elements which is 'enough' (default=50)
  -guess  , -noguess     # do/don't attempt to guess whether 'enough' <c> elements are already present (default='-guess')
  -profile, -noprofile   # output profiling information? (default=no)
  -xmlns  , -noxmlns     # do/don't use 'xml:' namespace prefix on id attributes (default=don't)

=cut

##------------------------------------------------------------------------------
## Options and Arguments
##------------------------------------------------------------------------------
=pod

=head1 OPTIONS AND ARGUMENTS

Not yet written.

=cut

##------------------------------------------------------------------------------
## Description
##------------------------------------------------------------------------------
=pod

=head1 DESCRIPTION

Adds E<lt>cE<gt> elements to DTA XML files and/or assigns C<xml:id>s to existing elements.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-cids2local.perl(1)|dtatw-cids2local.perl(1)>,
L<dtatw-rm-c.perl(1)|dtatw-rm-c.perl>,
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
