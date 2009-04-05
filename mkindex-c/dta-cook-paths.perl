#!/usr/bin/perl -w

use XML::LibXML;
#use XML::LibXSLT;
use Getopt::Long (':config'=>'no_ignore_case');
use Encode qw(encode decode);
use File::Basename qw(basename);
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $progname = basename($0);

our $encoding = 'UTF-8';
our $format   = undef; ##-- setting this to anything other than "0" might break output line numbers
our $outfile  = '-';

our $xpath     = '//*';
our $pathAttr  = 'p';     ##-- mnemonic: "path" (to selected node)
our $lineAttr  = 'l';     ##-- mnemonic: "line" (of selected node)

our $expand_ents = 0; ##-- expand entities when parsing input file?
our $keep_blanks = 0; ##-- keep blanks in input file?

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- path expansion
	   'xpath|xp|x|select=s'  => \$xpath,
	   'path-attribute|path|pa|p=s' => \$pathAttr,
	   'line-attribute|line|la|l=s' => \$lineAttr,
	   'nopath|nop' => sub { undef($pathAttr); },
	   'noline|nol' => sub { undef($lineAttr); },

	   ##-- I/O
	   'entities|ent|e!' => sub { $expand_ents=!$_[1]; },
	   'blanks|b!'       => sub { $keep_blanks=$_[1]; },
	   'output|o=s' =>\$outfile,
	   'format|f:i' => sub { $format=($_[1] ? $_[1] : 1); },
	   'noformat'   => sub { $format=0; },
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

##--------------------------------------------------------------
## Document cooking

## $cooked = dtaCookDoc($doc)
## $cooked = dtaCookDoc($doc,$filename)
sub dtaCookDoc {
  my ($doc,$file) = @_;
  $file = '?' if (!defined($file)); ##-- for error reporting

  my ($node,$path,$line);
  foreach $node (@{$doc->documentElement->findnodes($xpath)}) {
    $path = $node->nodePath();
    $line = $node->line_number();
    $node->setAttribute($pathAttr,$path) if (defined($pathAttr));
    $node->setAttribute($lineAttr,$line) if (defined($lineAttr));
  }

  return $doc;
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
push(@ARGV,'-') if (!@ARGV);
our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks);
$parser->expand_entities($expand_ents);
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);

foreach $f (@ARGV) {
  #print STDERR "$progname: parsing file '$f'...";

  $doc = $parser->parse_file($f)
    or die("$progname: could not parse file '$f': $!");

  $doc = dtaCookDoc($doc,$f);
  $doc->toFile($outfile,$format);

  #print STDERR " done.\n";
}


=pod

=head1 NAME

mark-canonical-xpath.perl - add 'path' attributes to selected elements in XML files

=head1 SYNOPSIS

 mark-canonical-xpath.perl [OPTIONS] [XMLFILE...]

 General Options:
  -help                  # this help message

 Extraction Options:
  -xpath XPATH           # xpath of elements to be marked  (default='//*')
  -path-attribute ATTR   # specify path attribute for selected elements (default='p')
  -line-attribute ATTR   # specify line attribute for selected elements (default='l')
  -nopath                # do not mark canonical xpaths
  -noline                # do not mark input line numbers

 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))
  -blanks , -noblanks    # do/don't keep ignorable whitespace (default=don't (-noblanks))
  -ent    , -noent       # don't/do expand entities (default=don't (-ent))
  -format , -noformat    # pretty-print output? (default=no)


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
(dta-cook-paths.perl),
dta-cook-structure.perl,
dta-tokenize.perl,
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

