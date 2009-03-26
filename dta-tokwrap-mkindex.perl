#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use XML::LibXML;
use Unicode::Normalize qw();
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;


##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);

##-- vars: I/O
our $txtfile = undef; ##-- default: none
our $idxfile = undef; ##-- default: none (or stdout if no --output arg is specified)

##-- profiling
our $profile = 1;
our $nchrs = 0;
our $nxbytes = 0; ##-- total number of XML source bytes processed
our ($tv_started,$elapsed) = (undef,undef);

##-- XML::Parser stuff
our ($xp); ##-- underlying XML::Parser object

our $docname = undef;    ##-- name for document (=basename($infilename))
our $c_id = undef;        ##-- $c_id: xml:id of currently open <c> element, if any
our $txtfh = undef;      ##-- $txtfh: output filehandle for text stream
our $idxfh = undef;      ##-- $idxfh: output filehandle for index stream
our $txtpos = 0;         ##-- $txtpos: byte position in $txtfh
our $cbuf = '';          ##-- buffer for contents of current <c> element
our $clen = 0;           ##-- length of $cbuf (in bytes)
our $cxbyte = 0;         ##-- byte offset (in XML stream) of start of current <c> element
our $cnum = 0;           ##-- $cnum: global index of <c> element (number of elts read so far)

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'index-output|output|io|o=s' => \$idxfile,
	   'text-output|to=s' => \$txtfile,
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
  $c_id = undef;       ##-- $c_id : xml:id of currently open <c> element, if any
  $cbuf = '';          ##-- buffer for contents of current <c> element
  $clen = 0;           ##-- length of $cbuf (in bytes)
  $cxbyte = 0;         ##-- byte offset (in XML stream) of start of current <c> element
  $cnum = 0;           ##-- $cnum: global index of <c> element (number of elts read so far)
  $txtpos = 0 if (!$txtpos);   ##-- $txtpos: byte position in $txtfh

  ##-- write header information
  $idxfh->print('%% BEGIN FILE ', basename($infile), "\n",
		'%% ', join("\t", qw(XML_ID XML_BYTE_OFFSET XML_BYTE_LEN TXT_BYTE_OFFSET TXT_BYTE_LEN)), "\n",
	       )
    if (defined($idxfh));
}

## undef = cb_final($expat)
sub cb_final_NOPE {
  $nxbytes += $_[0]->current_byte; ##-- always returns 0 here?
}

## undef = cb_char($expat,$string)
sub cb_char {
  $cbuf .= $_[0]->original_string() if (defined($c_id));
}

## undef = cb_start($expat, $elt,%attrs)
our (%c_attrs);
sub cb_start {
  if ($_[1] eq 'c')  {
    ##-- reset buffers
    %c_attrs = @_[2..$#_];
    $c_id = $c_attrs{'xml:id'} || "(none)";
    $cbuf = '';
    $cxbyte = $_[0]->current_byte(); ##-- use current_byte()+1 for emacs (which counts from 1)
  }
}

## $escaped = escape_cbuf()
sub escape_cbuf {
  my $e = $cbuf;
  $e =~ s/\n/\\n/g;
  $e =~ s/\r/\\r/g;
  $e =~ s/\t/\\t/g;
  return "\"$e\"";
}

## undef = cb_end($expat, $elt)
our ($cxlen);
sub cb_end {
  if ($_[1] eq 'c') {
    ##-- update text fh
    $txtfh->print($cbuf) if (defined($txtfh));

    ##-- update index fh
    $clen = length($cbuf); ##-- bytes::length($cbuf); but $cbuf should already be expressed in bytes
    $cxlen = $_[0]->current_byte()-$cxbyte + length($_[0]->original_string);

    $idxfh->print(join("\t",
		       $c_id,
		       $cxbyte,$cxlen,
		       $txtpos,$clen,
		       escape_cbuf()
		      ),
		  "\n")
      if (defined($idxfh));

    $txtpos += $clen;
    ++$cnum;
    $c_id = undef;
  }
  elsif ($_[1] eq 'lb') {
    ##-- line break: convert to newline
    $txtfh->print("\n") if (defined($txtfh));
    $txtpos++;
  }
}


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
				    #Final => \&cb_final,
				   },
		      )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$idxfile = '-' if (!defined($txtfile) && !defined($idxfile));
if (defined($idxfile)) {
  $idxfh = IO::File->new(">$idxfile")
    or die("$prog: open failed for output index file '$idxfile': $!");
}
if (defined($txtfile)) {
  $txtfh = IO::File->new(">$txtfile")
    or die("$prog: open failed for output text file '$txtfile': $!");
}

##-- initialize: profiling info
$tv_started = [gettimeofday] if ($profile);

##-- parse file(s)
foreach $infile (@ARGV) {
  my $txtpos0 = $txtpos;
  $xp->parsefile($infile);
  $nchrs += $cnum;
  $nxbytes += (-s $infile) if ($infile ne '-');
  $txtfh->print("\n") if (defined($txtfh)); ##-- always terminate text file with a newline
  $idxfh->print(
		"%% NCHARS ", $cnum, "\n",
		"%% NBYTES ", $txtpos-$txtpos0, "\n",
		"%% END FILE ", basename($infile), "\n",
	       )
    if (defined($idxfh));
}

##-- profiling / output
sub sistr {
  my $x = shift;
  return sprintf("%.2fK", $x/10**3)  if ($x >= 10**3);
  return sprintf("%.2fM", $x/10**6)  if ($x >= 10**6);
  return sprintf("%.2fG", $x/10**9)  if ($x >= 10**9);
  return sprintf("%.2fT", $x/10**12) if ($x >= 10**12);
  return sprintf("%.2f", $x);
}

if ($profile) {
  $elapsed = tv_interval($tv_started,[gettimeofday]);
  $chrsPerSec  = sistr($elapsed > 0 ? ($nchrs/$elapsed) : -1);
  $bytesPerSec = sistr($elapsed > 0 ? ($nxbytes/$elapsed) : -1);

  print STDERR
    (sprintf("%s: %d chars ~ %d XML-bytes in %.2f sec: %s chr/sec ~ %s bytes/sec\n",
	     $prog, $nchrs,$nxbytes, $elapsed, $chrsPerSec, $bytesPerSec));
}


=pod

=head1 NAME

dta-tokwrap-mkindex.perl - make character index in preparation for tokenization of DTA XML documents

=head1 SYNOPSIS

 dta-tokwrap-mkindex.perl [OPTIONS] [XMLFILE(s)...]

 General Options:
  -help                  # this help message

 Psuedo-Text Node Options:
  -text-element ELT      # tag name of pseudo-text nodes (default='text')

 Location Element Options:
  -location-element ELT  # tag name of (empty) location elements (default='loc')
  -loc-byte ATTR         # global byte offset attribute for location elements (default='b')
  -loc-line ATTR         # source line attribute for location elements (default='l')
  -loc-col  ATTR         # source column attribute for location elements (default='c')

 Output Token Element Options:
  -token-element ELT     # tag name for output token elements (default='w')
  -tok-norm WHICH        # which normalization form to use (Unicode TR-15, default='KC')
  -tok-text ATTR         # normalized text attribute for token elements (default='u')
  -tok-byte ATTR         # global byte offset attribute for token elements (default='b')
  -tok-line ATTR         # source line attribute for token elements (default='l')
  -tok-col  ATTR         # source column attribute for token elements (default='c')


 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))
  -input-encoding ENC    # specify input encoding (default='UTF-8')
  -output-encoding ENC   # specify output encoding (default='UTF-8')
  -profile, -noprofile   # output profiling information? (default=no)
  -format , -noformat    # pretty-print output? (default=yes)

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

Not yet written.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

dta-cook-text.perl,
dta-cook-paths.perl,
dta-cook-structure.perl,
(dta-tokenize.perl),
dta-eosdetect.perl,
dta-assign-sids.xsl,
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=cut

