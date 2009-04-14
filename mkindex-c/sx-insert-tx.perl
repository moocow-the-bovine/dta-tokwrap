#!/usr/bin/perl -w

use XML::LibXML;
use Getopt::Long (':config'=>'no_ignore_case');
#use Encode qw(encode decode);
use File::Basename qw(basename);
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $progname = basename($0);

our $encoding = 'UTF-8';
our $format   = 0; ##-- setting this to anything other than "0" might break line numbers
our $outfile  = '-';

our $expand_ents = 0; ##-- for .sx input file
our $keep_blanks = 1; ##-- for .sx input file

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- xml input
	   'entities|ent|e!' => sub { $expand_ents=!$_[1]; },
	   'blanks|b!'       => sub { $keep_blanks=$_[1]; },

	   ##-- output
	   'output|o=s'=>\$outfile,
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);

pod2usage({
	   -message=>'No XML .sx file(s) specified!',
	   -exitval=>1,
	   -verbose=>0
	  }) if (@ARGV < 1);
pod2usage({
	   -message=>'No text .tx file specified!',
	   -exitval=>1,
	   -verbose=>0
	  }) if (@ARGV < 2);

##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

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

sub sx_inherit_text {
  my ($sxdoc,$txbuf) = @_;

  my ($c,$n, $xoff,$xlen,$toff,$tlen, $txt);
  foreach $c ($doc->findnodes("//c")) {
    $n = $c->getAttribute("n") || '0 0 0 0';
    ($xoff,$xlen,$toff,$tlen) = split(/\s+/, $n);
    $c->appendTextNode(substr($$txbuf, $toff, $tlen));
  }
  return $sxdoc;
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
our ($sxfile,$txfile) = @ARGV;

##-- slurp text file
our $txbuf = '';
slurp_file($txfile,\$txbuf);

##-- munge .sx file
our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks);     ##-- do we want blanks kept?
$parser->expand_entities($expand_ents); ##-- do we want entities expanded?
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);

##-- parse .sx file
$doc = $parser->parse_file($sxfile)
  or die("$progname: could not parse input .sx file '$sxfile': $!");

##-- munge .sx doc
sx_inherit_text($doc, \$txbuf);

##-- output
$doc->toFile($outfile,$format);


=pod

=head1 NAME

sx-inherit-text.perl - merge raw .tx data into .sx structure index file (for debugging)

=head1 SYNOPSIS

 sx-inherit-text.perl [OPTIONS] SXFILE TXFILE

 General Options:
  -help                  # this help message

 Extraction Options:
  -ent    , -noent       # don't/do expand entities for SXFILE (default=don't (-ent))
  -blanks , -noblanks    # do/don't keep blanks for SXFILE (default=do (-blanks))

 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))
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

...

=cut


##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>moocow@bbaw.deE<gt>

=cut

