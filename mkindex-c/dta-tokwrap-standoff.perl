#!/usr/bin/perl -w

use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use IO::File;
use Pod::Usage;
use XML::LibXML;
use bytes;
no bytes;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $progname = basename($0);
our $wfile  = undef;  ##-- default: "$xmlbase.w.xml"
our $sfile  = undef;  ##-- default: "$xmlbase.s.xml"
our $xmlbase = undef; ##-- default: basename($cxfile,'.cx').".xml"
our $format   = 0; ##-- output formatting?

##-- profiling
our $profile = 1;
our ($ntoks,$nchrs) = (0,0);
our ($tv_started,$elapsed) = (undef,undef);

##-- output elements
our $sDocElt = 'sentences';
our $wDocElt = 'tokens';

##-- constants
our $VLEN_CI  = 32; ##-- bits for character-index vec() items
our $VLEN_OFF = 32; ##-- bits for offset vec() items
our $VLEN_LEN =  8; ##-- bits for length vec() items

our $noc_v = '';
vec($noc_v, 0, $VLEN_CI) = -1;
our $noc = vec($noc_v, 0, $VLEN_CI);

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- I/O
	   'xml-base|xb|b=s' => \$xmlbase,
	   'output-word-file|word-file|owf|wf|w|output-token-file|otf|tf|t=s' => \$wfile,
	   'output-sentence-file|sentence-file|osf|sf|s=s' => \$sfile,
	   'output|o=s'=>sub { $wfile="$_[1].w.xml"; $sfile="$_[1].s.xml"; },
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },
	   'profile|p!' =>\$profile,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({
	   -message => 'No character index (.cx) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 1);
pod2usage({
	   -message => 'No block index (.bx) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 2);
pod2usage({
	   -message => 'No tokenizer data (.tt) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 3);


##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

## \@bx = read_bx_file($bxfile)
sub read_bx_file {
  my $bxfile = shift;
  my (@bx,$blk);
  open(BX,"<$bxfile") or die("$0: open failed for block index file '$bxfile': $!");
  while (<BX>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    $blk = {};
    @$blk{qw(key elt xoff xlen toff tlen otoff otlen)} = split(/\t/,$_);
    push(@bx, $blk);
  }
  close(BX);
  return \@bx;
}

## \%cx = read_cx_file($cx)
##   + \%cx keys:
##     ids    => \@ids,       ##-- $ids[$i] = $xmlid_of_char_i
##     tb2ci  => $tb2ci,      ##-- vec($tb2ci, $txbyte, $VLEN_CI) = $char_index_of_txbyte
##     ntb    => $n_tx_bytes, ##-- s.t. 0 <= $n_tx_bytes <= (-s $txfile)
##     nchr   => $n_chr,      ##-- s.t. 0 <= $ci < $n_chr
sub read_cx_file {
  my $cxfile = shift;
  my $ids = [];
  my $tb2ci = '';
  my ($tbi);
  my ($id,$xoff,$xlen,$toff,$tlen);
  open(CX,"<$cxfile") or die("$0: open failed for character index file '$cxfile': $!");
  while (<CX>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    ($id,$xoff,$xlen,$toff,$tlen) = split(/\t/,$_);
    push(@$ids,$id);
    foreach $tbi ($toff..($toff+$tlen)) {
      vec($tb2ci, $tbi, $VLEN_CI) = $#$ids;
    }
  }
  close(CX);
  return {
	  ids  =>$ids,
	  tb2ci=>$tb2ci,
	  ntb  =>length($tb2ci)/($VLEN_CI/8),
	  nchr =>scalar(@$ids),
	 };
}

## $ob2ci = byte_to_charnum(\%cx,\@bx)
##  + s.t. vec($ob2ci, $txtbyte, $VLEN_CI) = $char_index_of_txtbyte
sub byte_to_charnum {
  my ($cx,$bx) = @_;
  my $ob2ci = '';
  my $tb2ci = $cx->{tb2ci};
  my ($blk);
  my ($toff,$tlen,$otoff,$otlen);
  my ($obi);
  foreach $blk (@$bx) {
    ($toff,$tlen,$otoff,$otlen) = @$blk{qw(toff tlen otoff otlen)};
    if ($tlen > 0) {
      ##-- normal text
      foreach $obi (0..($otlen-1)) {
	vec($ob2ci, $otoff+$obi, $VLEN_CI) = vec($tb2ci, $toff+$obi, $VLEN_CI);
      }
    } else {
      ##-- implicit break
      foreach $obi (0..($otlen-1)) {
	vec($ob2ci, $otoff+$obi, $VLEN_CI) = $noc;
      }
    }
  }
  return $ob2ci;
}

sub flush_sentence {
  our($si,@s_wids);
  $snod = $sroot->addNewChild(undef, 's');
  $snod->setAttribute("xml:id", "s_".($si++));
  $snod->setAttribute("ref", join(' ', map {"#$_"} @s_wids));
  @s_wids = qw();
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------
##-- command-line stuff
($cxfile,$bxfile,$ttfile) = @ARGV;
if (!defined($xmlbase)) {
  $xmlbase = basename($cxfile,'.cx','.CX');
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

$tv_started = [gettimeofday] if ($profile);

##-- read input files
our $cx = read_cx_file($cxfile);
our $bx = read_bx_file($bxfile);
our $ob2ci = byte_to_charnum($cx,$bx);
our $cids = $cx->{ids};

##-- create output documents
our ($wdoc,$wroot);
$wdoc = XML::LibXML::Document->new("1.0","UTF-8");
$wdoc->setDocumentElement($wroot=$wdoc->createElement($wDocElt));
$wroot->setAttribute('xml:base', $xmlbase);

our ($sdoc,$sroot);
$sdoc = XML::LibXML::Document->new("1.0","UTF-8");
$sdoc->setDocumentElement($sroot=$sdoc->createElement($sDocElt));
$sroot->setAttribute('xml:base', basename($wfile));


##-- process tokenizer data
my ($text,$otofflen,$otoff,$otlen,@rest);
our (@w_cis, @w_cids, @s_wids);
our ($wi,$si) = (0,0);
my ($wid);

open(TT,"<$ttfile") or die("$0: open failed for tokenizer data file '$ttfile': $!");
while (<TT>) {
  chomp;
  next if (/^\s*%%/);

  ##-- check for EOS
  if ($_ eq '') {
    flush_sentence() if (@s_wids);
    next;
  }

  ##-- normal token: parse it
  ($text,$otofflen,@rest) = split(/\t/,$_);
  ($otoff,$otlen) = split(/\s+/,$otofflen);
  @w_cis  = grep {$_ != $noc} map {vec($ob2ci, $_, $VLEN_CI)} ($otoff..($otoff+$otlen-1));
  @w_cis  = ($w_cis[0], @w_cis[grep {$w_cis[$_-1] != $w_cis[$_]} (1..$#w_cis)]);
  @w_cids = @$cids[@w_cis];

  ##-- ... and create XML output
  $wid = "w_".($wi++);
  $wnod = $wroot->addNewChild(undef,'w');
  $wnod->setAttribute("xml:id", $wid);
  $wnod->setAttribute("ref", join(' ', map {"#$_"} @w_cids));
  $wnod->setAttribute("off", $otoff);
  $wnod->setAttribute("len", $otlen);
  $wnod->appendText(join("\t",$text,@rest));
  push(@s_wids, $wid);
  ++$ntoks; ##-- profiling
}
close(TT);

$nchrs = $cx->{nchr}; ##-- profiling

##-- flush any open sentence
if (@s_wids) {
  flush_sentence();
}

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
	     $progname, $ntoks,$nchrs, $elapsed, $toksPerSec, $chrsPerSec));
}


=pod

=head1 NAME

dta-tokwrap-standoff.perl - generate standoff annotation from character index and tokenizer output

=head1 SYNOPSIS

 dta-tokwrap-standoff.perl [OPTIONS] CXFILE BXFILE TTFILE

 General Options:
  -help                  # this help message

 I/O Options:
  -xml-base XMLBASE      # specify xml:base for stand-off files (default=from .cx file)
  -word-file WFILE       # output token standoff file
  -sentence-file SFILE   # output sentence standoff file
  -output BASE           # like -word-file=BASE.w -sentence-file=BASE.s
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

