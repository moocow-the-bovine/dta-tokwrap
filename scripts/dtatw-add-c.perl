#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
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
our $outfile = "-"; ##-- default: stdout

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

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'output|out|o=s' => \$outfile,
	   'profile|p!' => \$profile,
	  );


pod2usage({
	   -exitval=>0,
	   -verbose=>0,
	  }) if ($help);

##======================================================================
## Subs

##--------------------------------------------------------------
## XML::Parser handlers

## undef = cb_init($expat)
sub cb_init {
  $cnum = 0;
  $text_depth = 0;
  $c_depth = 0;
}

## undef = cb_char($expat,$string)
our ($c_block,$c_char);
sub cb_char {
  return if ($text_depth<=0);
  if ($c_depth > 0) {
    $outfh->print($_[0]->original_string());
    return;
  }
  $c_block = decode('UTF-8',$_[0]->original_string());
  while ($c_block =~ m/((?:\&[^\;]*\;)|(?: +)|(?:.))/sg) {
    $c_char = $1;
    if ($c_char =~ /^\s+$/) {
      if ($c_char =~ m/^ /) {
	$c_char = ' '; ##-- bash multiple spaces to single spaces
      } else {
	$outfh->print($c_char);
	next;
      }
    }
    $outfh->print("<c xml:id=\"c", ++$cnum, "\">", encode('UTF-8',$c_char), "</c>");
  }
}

## undef = cb_start($expat, $elt,%attrs)
our ($cs);
sub cb_start {
  if ($_[1] eq 'c') {
    ##-- pre-existing <c>: respect it
    if ($c_depth > 0) {
      $_[0]->xpcroak("$prog: cowardly refusing to process input document with nested <c> elements!\n"
		     ."$prog: in file '$infile'");
    }
    ++$c_depth;
    $cs = $_[0]->original_string();
    if ($cs !~ m/\bxml:id=/) {
      ##-- pre-existing <c> WITOUT xml:id attribute: assign one
      ++$cnum;
      $cs =~ s|(/?>)$| xml:id="c$cnum"$1|;
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
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
$outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- initialize: profiling info
$tv_started = [gettimeofday] if ($profile);

##-- parse file(s)
foreach $infile (@ARGV) {
  $xp->parsefile($infile);
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
  -profile, -noprofile   # output profiling information? (default=no)

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

Now respects pre-existing "c" elements, assigning them C<xml:id>s to these if required.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
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
