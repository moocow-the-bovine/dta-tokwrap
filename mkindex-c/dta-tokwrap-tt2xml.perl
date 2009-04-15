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
our $prog = basename($0);
our $outfile  = '-';     ##-- default: stdout
our $xmlbase  = undef;  ##-- default: basename($cxfile,'.cx').".xml"
our $format   = 0;      ##-- output formatting?
our $verbose  = 0;      ##-- verbosity

##-- profiling
our $profile = 1;
our ($ntoks,$nchrs) = (0,0);
our ($tv_started,$elapsed) = (undef,undef);

##-- output XML structure
our $oDocElt = 'sentences';
our $sElt = 's';
our $wElt = 'w';
our $aElt = 'a';
our $posAttr = 'b';
our $textAttr = 't';

##-- constants
our $VLEN_CI  = 32; ##-- bits for character-index vec() items
our $VLEN_OFF = 32; ##-- bits for offset vec() items
our $VLEN_LEN =  8; ##-- bits for length vec() items

our $noc_v = '';
vec($noc_v, 0, $VLEN_CI) = -1;
our $noc = vec($noc_v, 0, $VLEN_CI);

##-- initialization
BEGIN {
  select(STDERR);
  $|=1;
  select(STDOUT);
}

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|V=i' => \$verbose,

	   ##-- I/O
	   'xml-base|xb|b=s' => \$xmlbase,
	   'output-file|output|out|of|o=s' => \$outfile,
	   'format|f:i'   =>sub { $format=$_[1] ? $_[1] : 1; },
	   'noformat|nof' =>sub { $format=0; },
	   'profile|p!' =>\$profile,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({
	   -message => 'No tokenizer data (.tt) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 1);
pod2usage({
	   -message => 'No block index (.bx) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 2);
pod2usage({
	   -message => 'No character index (.cx) file specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 3);


##------------------------------------------------------------------------------
## Subs
##------------------------------------------------------------------------------

##--------------------------------------------------------------
## Subs: messaging

sub vmsg {
  my ($vlevel,@msg) = @_;
  if ($verbose >= $vlevel) {
    print STDERR @msg;
  }
}

sub vmsg1 {
  vmsg($_[0],"$prog: ", @_[1..$#_], "\n");
}

sub vdo {
  my ($vlevel, $sub, $premsg, $postmsg) = @_;
  vmsg($vlevel, "$prog: $premsg");
  my $rc = $sub->();
  vmsg($vlevel, ' ', $postmsg, "\n");
  return $rc;
}

##--------------------------------------------------------------
## Subs: I/O

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
##     cx     => [$c0,...],   ##-- each $ci = [ $id_0, $xoff_1, $xlen_2, $toff_3, $tlen_4, ... ]
##     tb2ci  => $tb2ci,      ##-- vec($tb2ci, $txbyte, $VLEN_CI) = $char_index_of_txbyte
##     ntb    => $n_tx_bytes, ##-- s.t. 0 <= $n_tx_bytes <= (-s $txfile)
##     nchr   => $n_chr,      ##-- s.t. 0 <= $ci < $n_chr
sub read_cx_file {
  my $cxfile = shift;
  my $cx = [];

  ##-- load full .cx file
  open(CX,"<$cxfile") or die("$0: open failed for character index file '$cxfile': $!");
  while (<CX>) {
    chomp;
    next if (/^%%/ || /^\s*$/);
    push(@$cx, [split(/\t/,$_)]);
  }
  close(CX);

  ##-- create $tb2ci index vector
  my ($ci,$toff,$tlen,$tbi);
  my $tb2ci = '';
  vec($tb2ci, $cx->[$#$cx][3]+$cx->[$#$cx][4], $VLEN_CI) = $#$cx; ##-- initialize  / allocate
  foreach $ci (0..$#$cx) {
    ($toff,$tlen) = @{$cx->[$ci]}[3,4];
    foreach $tbi ($toff..($toff+$tlen)) {
      vec($tb2ci, $tbi, $VLEN_CI) = $ci;
    }
  }

  ##-- return
  return {
	  cx   =>$cx,
	  tb2ci=>$tb2ci,
	  ntb  =>length($tb2ci)/($VLEN_CI/8),
	  nchr =>scalar(@$cx),
	 };
}

##--------------------------------------------------------------
## Subs: Indexing

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

##--------------------------------------------------------------
## Subs: output utils

## undef = flush_sentence()
##  + flushes output sentence
sub flush_sentence {
  our($si,@s_wnods);
  return if (!@s_wnods);
  $snod = $oroot->addNewChild(undef, 's');
  $snod->setAttribute("xml:id", "s_".($si++));
  #$snod->setAttribute("ref", join(' ', map {"#".$_->getAttribute('xml:id')} @s_wnods));
  $snod->appendChild($_) foreach (@s_wnods);
  @s_wnods = qw();
}

##------------------------------------------------------------------------------
## MAIN
##------------------------------------------------------------------------------
##-- command-line stuff
($ttfile,$bxfile,$cxfile) = @ARGV;
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
our ($cx,$bx,$ob2ci,$cxi);
$cx    = vdo(1, sub {read_cx_file($cxfile);}, "loading .cx file '$cxfile'...", "loaded.");
$bx    = vdo(1, sub {read_bx_file($bxfile);}, "loading .bx file '$bxfile'...", "loaded.");
$ob2ci = vdo(1, sub {byte_to_charnum($cx,$bx);}, "building byte->charnum index...", "done.");
$cxi   = $cx->{cx};

##-- create output document
our ($odoc,$oroot);
$odoc = XML::LibXML::Document->new("1.0","UTF-8");
$odoc->setDocumentElement($oroot=$odoc->createElement($oDocElt));
$oroot->setAttribute('xml:base', $xmlbase);

##-- process tokenizer data
vmsg(1, "$prog: processing tokenizer data file '$ttfile'...");
my ($text,$otofflen,$otoff,$otlen,@rest);
our (@w_cis, @w_cids, $wnod, @s_wnods);
our ($wi,$si) = (0,0);
my ($wid);

open(TT,"<$ttfile") or die("$0: open failed for tokenizer data file '$ttfile': $!");
while (<TT>) {
  chomp;
  next if (/^\s*%%/);

  ##-- check for EOS
  if ($_ eq '') {
    flush_sentence();
    next;
  }

  ##-- normal token: parse it
  ($text,$otofflen,@rest) = split(/\t/,$_);
  ($otoff,$otlen) = split(/\s+/,$otofflen);
  @w_cis  = grep {$_ != $noc} map {vec($ob2ci, $_, $VLEN_CI)} ($otoff..($otoff+$otlen-1));
  @w_cis  = ($w_cis[0], @w_cis[grep {$w_cis[$_-1] != $w_cis[$_]} (1..$#w_cis)]);
  @w_cids = map {$_->[0]} @$cxi[@w_cis];

  ##-- ... and create XML output
  $wid = "w_".($wi++);
  $wnod = $odoc->createElement($wElt);
  $wnod->setAttribute("xml:id", $wid);
  $wnod->setAttribute($posAttr, "$otoff $otlen");
  ##----
  #$wnod->appendText(join("\t",$text,@rest));
  ##--
  #$wnod->appendText($text);
  ##--
  #$wnod->appendTextChild($textElt,$text);
  ##--
  $wnod->setAttribute($textAttr, $text);
  ##----
  $wnod->setAttribute("ref", join(' ', map {"#$_"} @w_cids));
  foreach (0..$#rest) {
    $anod = $wnod->addNewChild(undef,$aElt);
    $anod->setAttribute('n',$_+1);
    $anod->appendText($rest[$_]);
  }
  push(@s_wnods,$wnod);
  ++$ntoks; ##-- profiling
}
close(TT);

$nchrs = $cx->{nchr}; ##-- profiling

##-- flush any open sentence
flush_sentence();

vmsg(1, " done.\n");

##-- output
$odoc->toFile($outfile,$format);

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
    (sprintf("%s: %stok, %schr in %.2f sec: %stok/sec ~ %schr/sec\n",
	     $prog, sistr($ntoks),sistr($nchrs), $elapsed, $toksPerSec, $chrsPerSec));
}


=pod

=head1 NAME

dta-tokwrap-tt2xml.perl - generate standoff annotation from tokenizer output and indices

=head1 SYNOPSIS

 dta-tokwrap-tt2xml.perl [OPTIONS] TTFILE BXFILE CXFILE

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

