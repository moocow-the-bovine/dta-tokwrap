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
our $format   = 0; ##-- setting this to anything other than "0" might break line numbers
our $outfile  = '-';

our $pseudoXpath = '//dta.tw.b';
our $pathAttr  = 'p';     ##-- mnemonic: "path" (to psuedo-text node)

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- pseudo-text nodes
	   'xpath|xp|x=s'  => \$pseudoXpath,
	   'path-attribute|path|pa|p=s' => \$pathAttr,  ##-- path to original text node

	   ##-- output
	   'output|o=s'=>\$outfile,
	   'format|f:i' =>\$format,
	   'noformat' => sub { $format=0; },
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

  ##-- ugly but it's gotta happen: re-parse to get line numbers
  my ($node,$path,$name);
  foreach $node (@{$doc->documentElement->findnodes($pseudoXpath)}) {
    $path = $node->nodePath();
    $name = $node->nodeName();
    $path =~ s|/\Q$name\E([^/]*)$|/block$1|;
    $node->setAttribute($pathAttr,$path);
  }

  return $doc;
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
push(@ARGV,'-') if (!@ARGV);
our $parser = XML::LibXML->new();
#$parser->keep_blanks(0);  ##-- ... or do we want blanks kept?!
$parser->keep_blanks(1); ##-- maybe for this app, we *want* blanks kept?
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);
$parser->expand_entities(1);

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

dta-cook-paths.perl - add 'path' attributes to pseudo-text nodes for DTA XML files

=head1 SYNOPSIS

 dta-cook-paths.perl [OPTIONS] [FILE...]

 General Options:
  -help                  # this help message

 Extraction Options:
  -pseudo-element ELT    # specify pseudo-element for wrapping text nodes (default='text')
  -path-attribute ATTR   # specify path attribute for output pseudo-text elements (default='tp')

 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))
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

