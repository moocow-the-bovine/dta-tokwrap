#!/usr/bin/perl -w

use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use IO::File;
use Pod::Usage;
use bytes;
no bytes;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $progname = basename($0);
our $outfile  = '-';

##-- profiling
our $profile = 1;
our ($ntoks,$nchrs) = (0,0);
our ($tv_started,$elapsed) = (undef,undef);

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'output|o=s'=>\$outfile,
	   'profile|p!' =>\$profile,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);


##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

##--------------------------------------------------------------
## Slurp

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

##--------------------------------------------------------------
## File tokenization

## undef = dtaTokenizeFile($filename,$outfh)
sub dtaTokenizeFile {
  my ($infile,$outfh) = @_;

  ##-- slurp text file
  my $txbuf = '';
  slurp_file($infile,\$txbuf);
  $txbuf = decode("UTF-8",$txbuf);

  ##-- Tokenize buffered text
  my ($tokstr,$textstr,$textlen);
  my $byte = 0;
  while ($txbuf =~ m/(
                        (?:([[:alpha:]\#]+)\-(?:\n+)([[:alpha:]\#]+))   ##-- line-broken alphabetics
                        | (?i:\$[SWT]B\$)                               ##-- implicit break
                        | (?i:[IVXLCDM\#]+\.)                           ##-- dotted roman numerals (hack)
                        | (?:[[:alpha:]\#]\.)                           ##-- dotted single-letter abbreviations
                        #| (?:[[:digit:]\#]+[[:alpha:]\#]?\.)            ##-- dotted numbers with optional character suffixes
                        | (?:[[:digit:]\#]+[[:alpha:]\#]*)              ##-- numbers with optional alphabetic suffixes
                        | (?:[[:digit:]\#]+\,[[:digit:]\#]+)            ##-- comma-separated numbers
                        | (?:\,\,|\`\`|\'\'|\-+|\_+|\.\.+)              ##-- special punctuation sequences
                        | (?:[[:alpha:]\#]+)                            ##-- "normal" alphabetics (with "#" ~= unknown)
                        | (?:[[:punct:]])                               ##-- "normal" punctuation characters
                        | (?:[^[:punct:][:digit:][:space:]]+)           ##-- "normal" alphabetic tokens
                       )
                        |.                                              ##-- HACK: non-tokenized material
                       /xsg)
    {
      if (!defined($tokstr=$1)) {
	$byte += length(encode('UTF-8',$&));
	next;
      }

      ##-- update text string, length
      $textstr = defined($2) ? "$2$3" : $1; ##-- special handling for line-broken alphabetics
      $textlen = bytes::length($&);

      ##-- check for implicit breaks (just ignore for now)
      if ($textstr =~ m/^\$[SWT]B\$$/) {
	$outfh->print("\n") if ($textstr eq '$SB$');
	$byte += length($textstr);
	next;
      }

      ##-- encode as bytes
      $textstr = encode('UTF-8', $textstr);

      ##-- output
      $outfh->print($textstr, "\t", $byte, ' ', $textlen, "\n");

      ##-- hack: output sentence breaks at any of: . ? !
      if ($textstr eq '.' || $textstr eq '?' || $textstr eq '!') { $outfh->print("\n"); }

      ##-- update: current byte
      $byte += $textlen;

      ++$ntoks; ##-- profiling
    }

  ##-- profiling: character-wise
  $nchrs += length($txbuf);

  ##-- always terminate with EOS
  $outfh->print("\n");
}


##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------

##-- ye olde guttes
push(@ARGV,'-') if (!@ARGV);

$outfh = IO::File->new(">$outfile") or die("$0: could not open output file '$outfile': $!");

$tv_started = [gettimeofday] if ($profile);

foreach $f (@ARGV) {
  #print STDERR "$progname: parsing file '$f'...";

  dtaTokenizeFile($f,$outfh);

  #print STDERR " done.\n";
}

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
	     $progname, $ntoks,$nchrs, $elapsed, $toksPerSec, $chrsPerSec));
}


=pod

=head1 NAME

dta-tokenize-dummy.perl - dummy tokenizer for raw DTA UTF-8 text, outputs byte offset & length

=head1 SYNOPSIS

 dta-tokenize-dummy.perl [OPTIONS] [FILE...]

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

