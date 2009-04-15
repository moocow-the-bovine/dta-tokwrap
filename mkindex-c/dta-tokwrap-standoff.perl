#!/usr/bin/perl -w

use Getopt::Long (':config' => 'no_ignore_case');
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes ('gettimeofday','tv_interval');
use IO::File;
use Pod::Usage;
use XML::LibXML;
use bytes;
no bytes;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $wfile  = undef;  ##-- default: "$xmlbase.w.xml"
our $sfile  = undef;  ##-- default: "$xmlbase.s.xml"
our $xmlbase = undef; ##-- default: basename($ttxmlfile,'.tt.xml').".xml"
our $format  = 0; ##-- output formatting?

our $expand_ents = 0; ##-- for .tt.xml input file
our $keep_blanks = 1; ##-- for .tt.xml input file

##-- profiling
our $profile = 1;
our ($ntoks,$nchrs) = (0,0);
our ($tv_started,$elapsed) = (undef,undef);

##-- output elements
our $sDocElt = 'sentences';
our $wDocElt = 'tokens';

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- xml input
	   'entities|ent|e!' => sub { $expand_ents=!$_[1]; },
	   'blanks|b!'       => sub { $keep_blanks=$_[1]; },

	   ##-- I/O
	   'xml-base|xb=s' => \$xmlbase,
	   'output-word-file|word-file|owf|wf|w|output-token-file|otf|tf|t=s' => \$wfile,
	   'output-sentence-file|sentence-file|osf|sf|s=s' => \$sfile,
	   'output|o=s'=>sub { $wfile="$_[1].w.xml"; $sfile="$_[1].s.xml"; },
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },
	   'profile|p!' =>\$profile,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({
	   -message => 'No tokenizer data XML (.t.xml) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 1);


##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- command-line
($ttxmlfile) = @ARGV;

##-- profiling
$tv_started = [gettimeofday] if ($profile);

##-- parse input document
our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks);     ##-- do we want blanks kept?
$parser->expand_entities($expand_ents); ##-- do we want entities expanded?
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);

our $tdoc = $parser->parse_file($ttxmlfile)
  or die("$prog: could not parse tokenized XML file '$ttxmlfile': $!");

##-- command-line sanity checks
if (!defined($xmlbase)) {
  $xmlbase = $tdoc->documentElement->getAttribute('xml:base');
}
if (!defined($xmlbase)) {
  $xmlbase = basename($ttxmlfile);
  $xmlbase =~ s/[\.\-\_]xml$//i;
  $xmlbase =~ s/[\.\-\_]tt$//i;
  $xmlbase .= '.xml' if ($xmlbase !~ /\.xml$/i);
}
if (!defined($wfile)) {
  ($wfile=$xmlbase) =~ s/\.xml$//i;
  $wfile .= ".w.xml";
}
if (!defined($sfile)) {
  ($sfile=$xmlbase) =~ s/\.xml$//i;
  $sfile .= ".s.xml";
}
##-- report
print STDERR
  ("$prog: standoff output file / tokens   : $wfile\n",
   "$prog: standoff output file / sentences: $sfile\n",
  );

##-- create output documents
our ($wdoc,$wroot);
$wdoc = XML::LibXML::Document->new("1.0","UTF-8");
$wdoc->setDocumentElement($wroot=$wdoc->createElement($wDocElt));
$wroot->setAttribute('xml:base', $xmlbase);

our ($sdoc,$sroot);
$sdoc = XML::LibXML::Document->new("1.0","UTF-8");
$sdoc->setDocumentElement($sroot=$sdoc->createElement($sDocElt));
$sroot->setAttribute('xml:base',
		     #$xmlbase,
		     basename($wfile)
		    );

##-- ye olde guttes
our ($wi,$si) = (0,0);
foreach $tsnod (@{$tdoc->findnodes("//s")}) {
  $osnod = $sroot->addNewChild(undef,"s");
  $osnod->setAttribute('xml:id', "s_".(++$si));

  foreach $twnod (@{$tsnod->findnodes('./w')}) {
    $wid = "w_".(++$wi);

    ##-- add node to 'w' standoff file
    $ownod = $wroot->addNewChild(undef,"w");
    $ownod->setAttribute('xml:id', $wid);

    ##-- add 'w' pointer element to 's' standoff file
    $oswnod = $osnod->addNewChild(undef,'w');
    $oswnod->setAttribute('ref', "#$wid");

    ##-- add 'c' pointer elements to 'w' standoff file
    foreach (grep {defined($_) && $_ ne ''} split(/\s+/,$twnod->getAttribute('ref'))) {
      $owcnod = $ownod->addNewChild(undef,'c');
      $owcnod->setAttribute('ref',$_);
      ++$nchrs;
    }
  }
}

##-- profiling data
$ntoks = $wi;

##-- output
$wdoc->toFile($wfile,$format);
$sdoc->toFile($sfile,$format);


##-- profiling
sub sistr {
  my $x = shift;
  return sprintf("%.2f K", $x/10**3)  if ($x >= 10**3);
  return sprintf("%.2f M", $x/10**6)  if ($x >= 10**6);
  return sprintf("%.2f G", $x/10**9)  if ($x >= 10**9);
  return sprintf("%.2f T", $x/10**12) if ($x >= 10**12);
  return sprintf("%.2f ", $x);
}
if ($profile) {
  $elapsed = tv_interval($tv_started,[gettimeofday]);
  $toksPerSec = sistr($elapsed > 0 ? ($ntoks/$elapsed) : -1);
  $chrsPerSec = sistr($elapsed > 0 ? ($nchrs/$elapsed) : -1);

  print STDERR
    (sprintf("%s: %d tok, %d chr in %.2f sec: %stok/sec ~ %schr/sec\n",
	     $prog, $ntoks,$nchrs, $elapsed, $toksPerSec, $chrsPerSec));
}


=pod

=head1 NAME

dta-tokwrap-standoff.perl - generate standoff annotation from unified tokenizer XML output

=head1 SYNOPSIS

 dta-tokwrap-standoff.perl [OPTIONS] TTXMLFILE

 General Options:
  -help                  # this help message

 Other Options:
  -ent    , -noent       # do/don't keep entities from input (default=don't)
  -blanks , -noblanks    # do/don't keep "ignorable" space from input (default=do)
  -profile, -noprofile   # do/don't output profiling information (default=do)
  -xml-base XMLBASE      # @xml:base for stand-off files (default=from .cx file)
  -token-file WFILE      # output token stand-off file
  -sentence-file SFILE   # output sentence stand-off file
  -output OUTBASE        # like -token-file=OUTBASE.w.xml -sentence-file=OUTBASE.s.xml

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

perl(1),
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=cut

