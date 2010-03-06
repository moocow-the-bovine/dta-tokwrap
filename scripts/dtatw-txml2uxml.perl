#!/usr/bin/perl -w

use XML::LibXML;
use Getopt::Long (':config'=>'no_ignore_case');
use File::Basename qw(basename);
use Encode qw(encode decode);
#use Unicruft; ##-- optionally pulled in via require(); see below
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $encoding = 'UTF-8';
our $format   = 1;
our $outfile  = '-';
our $expand_ents = 0;
our $keep_blanks = 0;

our $txtfile = undef; ##-- default: from xml file
our $do_t0 = 1;
our $do_unicruft = 1;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- text file?
	   'textfile|txtfile|text|txt|tf=s' => \$txtfile,
	   't0!' => \$do_t0,
	   'unicruft|cruft|u!' => \$do_unicruft,

	   ##-- formatting
	   'entities|ent|e!' => sub { $expand_ents=!$_[1]; },
	   'blanks|b!'       => sub { $keep_blanks=$_[1]; },
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },

	   ##-- output
	   'output|o=s'=>\$outfile,
	  );

pod2usage({-exitval=>0, -verbose=>0})
  if ($help);
#pod2usage({-exitval=>0, -verbose=>0, -msg=>'-textfile must be specified when reading from stdin!'})
#  if (!@ARGV || $ARGV[0] eq '-');

##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

## \$txtRef = slurpText($filename)
sub slurpText {
  my $txtfile = shift;
  open(TXT,"<$txtfile")
    or die("$0: open failed for '$txtfile': $!");
  binmode(TXT);
  local $/=undef;
  my $buf=<TXT>;
  close(TXT);
  return \$buf;
}

## $doc = txml2uxml($doc)
##  + uses global $txtbufr
sub txml2uxml {
  my $doc = shift;
  my ($wnod,$wb,$off,$len, $wt0,$wt);
  foreach $wnod (@{$doc->findnodes('//w')}) {
    if ($do_unicruft) {
      ##-- unicruft approximation
      $wt = $wnod->getAttribute('t');
      $wnod->setAttribute('u', decode('latin1',Unicruft::utf8_to_latin1_de($wt)));
    }
    if ($do_t0) {
      ##-- raw text
      if (!defined($wb = $wnod->getAttribute('b'))) {
	warn("$0: could not get 'b' attribute for 'w' node ", $wnod->toString(0), "\n");
	$wb = '0 0';
      }
      ($off,$len) = split(/\s+/,$wb);
      $wt0 = decode('utf8',substr($$txtbufr,$off,$len));
      $wnod->setAttribute('t0', $wt0);

      ##-- raw text + unicruft
      $wnod->setAttribute('u0', decode('latin1',Unicruft::utf8_to_latin1_de($wt0))) if ($do_unicruft);
    }
  }
  return $doc;
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
push(@ARGV,'-') if (!@ARGV);

our $parser = XML::LibXML->new();
$parser->keep_blanks($keep_blanks);     ##-- do we want blanks kept?
$parser->expand_entities($expand_ents); ##-- do we want entities expanded?
$parser->line_numbers(1);
$parser->load_ext_dtd(0);
$parser->validation(0);
$parser->recover(1);

##-- parse input XML
our $infile = shift;
our $doc   = $parser->parse_file($infile)
  or die("$prog: could not parse input .t.xml file '$infile': $!");

##-- parse raw text buffer
our ($txtbufr);
if ($do_t0) {
  if (!defined($txtfile)) {
    $txtfile = $infile;
    $txtfile =~ s/\.t\.xml//i;
    $txtfile .= '.txt';
  }
  $txtbufr = slurpText($txtfile);
}

##-- maybe pull in unicruft
if ($do_unicruft) {
  require Unicruft;
}

##-- munge & dump
$doc = txml2uxml($doc);
$doc->toFile($outfile,$format);

__END__
=pod

=head1 NAME

dtatw-txml2uxml.perl - DTA::TokWrap: convert .t.xml to enrichted .u.xml

=head1 SYNOPSIS

 dtaec-txml2uxml.perl [OPTIONS] [TXMLFILE]

 General Options:
  -help                  # this help message

 Processing Options
  -textfile TXTFILE      # .txt file for TXMLFILE://w/@b locations
  -t0     , -not0        # do/don't output original text from TXTFILE as //w/@t0 (default=do)
  -cruft  , -nocruft     # do/don't output unicruft approximations as //w/@u rsp //w/@u0 (default=do)

 I/O Options:
  -ent    , -noent       # don't/do expand entities (default=don't (-ent))
  -blanks , -noblanks    # do/don't keep "ignorable" input blanks (default=don't (-noblanks))
  -ws     , -nows        # do/don't keep token-internal whitespace (default=don't (-nows))
  -format , -noformat    # do/don't pretty-print output? (default=do (-format))
  -output OUTFILE        # specify output file (default='-' (STDOUT))

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

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
