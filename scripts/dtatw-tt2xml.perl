#!/usr/bin/perl -w

use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use IO::File;
use Pod::Usage;
#use XML::LibXML;
use bytes;
no bytes;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $outfile  = '-';     ##-- default: stdout
our $xmlbase  = undef;  ##-- default: basename($cxfile,'.cx').".xml"
our $format   = 0;      ##-- formatted output?
our $verbose  = 1;      ##-- verbosity

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
  my $cxcx  = $cx->{cx};
  my ($blk);
  my ($id,$toff,$tlen,$otoff,$otlen);
  my ($obi,$ci);
  foreach $blk (@$bx) {
    ($toff,$tlen,$otoff,$otlen) = @$blk{qw(toff tlen otoff otlen)};
    if ($tlen > 0) {
      ##-- normal text
      foreach $obi (0..($otlen-1)) {
	$ci = vec($ob2ci, $otoff+$obi, $VLEN_CI) = vec($tb2ci, $toff+$obi, $VLEN_CI);
	if ($cxcx->[$ci][0] =~ /^\$.*\$$/) {
	  ##-- special character (e.g. <lb/>): map to $noc
	  vec($ob2ci, $otoff+$obi, $VLEN_CI) = $noc;
	}
      }
    } else {
      ##-- implicit break or special
      foreach $obi (0..($otlen-1)) {
	vec($ob2ci, $otoff+$obi, $VLEN_CI) = $noc;
      }
    }
  }
  return $ob2ci;
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

##-- open output file
our $outfh = IO::File->new(">$outfile") or die("$0: open failed for output file '$outfile': $!");
$outfh->print("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<$oDocElt xml:base=\"$xmlbase\">");
our ($fmtroot,$fmts,$fmtw,$fmta) = ('','','','');
if ($format) {
  my $indent = "  ";
  $fmtroot = "\n";
  $fmts = "\n".$indent;
  $fmtw = $fmts.$indent;
  $fmta = $fmtw.$indent;
}

$tv_started = [gettimeofday] if ($profile);

##-- read input files
our ($cx,$bx,$ob2ci,$cxi);
$cx    = vdo(1, sub {read_cx_file($cxfile);}, "loading .cx file '$cxfile'...", "loaded.");
$bx    = vdo(1, sub {read_bx_file($bxfile);}, "loading .bx file '$bxfile'...", "loaded.");
$ob2ci = vdo(1, sub {byte_to_charnum($cx,$bx);}, "building byte->charnum index...", "done.");
$cxi   = $cx->{cx};

##-- process tokenizer data
sub process_tt_data {
  vmsg(1, "$prog: processing tokenizer data file '$ttfile'...");
  my ($text,$otofflen,$otoff,$otlen,@rest);
  our $s_open = 0;
  our ($wi,$si) = (0,0);
  my ($wid);

  open(TT,"<$ttfile") or die("$0: open failed for tokenizer data file '$ttfile': $!");
  while (<TT>) {
    chomp;
    next if (/^\s*%%/);

    ##-- check for EOS
    if ($_ eq '') {
      $outfh->print($fmts."</$sElt>") if ($s_open);
      $s_open = 0;
      next;
    }

    ##-- normal token: parse it
    ($text,$otofflen,@rest) = split(/\t/,$_);
    ($otoff,$otlen) = split(/\s+/,$otofflen);
    $last_cid = undef;
    @w_cids = (
	       map {$_->[0]}
	       @$cxi[
		     grep { $_ != $noc && (!defined($last_cid) || $_ != $last_cid) && (($last_cid=$_)||1) }
		     map {vec($ob2ci, $_, $VLEN_CI)}
		     ($otoff..($otoff+$otlen-1))
		    ],
	      );

    ##-- make text output XML-save
    foreach ($text,@rest) {
      s/\&/&amp;/g;
      s/\"/&quot;/g;
      s/\'/&apos;/g;
      s/\</&lt;/g;
      s/\>/&gt;/g;
      s/\t/&#09;/g;
      s/\n/&#10;/g;
      s/\r/&#13;/g;
    }

    ##-- ... and create XML output
    $wid = "w".($wi++);
    $outfh->print(
		  ##-- maybe open new sentence: <s>
		  (!$s_open ? ($fmts."<$sElt xml:id=\"s".(++$si)."\">") : qw()),
		  ##
		  ##-- common token properties: s/w
		  ($fmtw."<$wElt xml:id=\"$wid\" $posAttr=\"$otoff $otlen\" $textAttr=\"$text\" c=\"".join(' ', @w_cids)."\""),
		  ##
		  ##-- additional analyses: s/w/a
		  (@rest
		   ? (">", (map { ($fmta."<$aElt>$_</$aElt>") } @rest), $fmtw."</$wElt>")
		   : "/>"),
		 );
    $s_open = 1;

    ##-- profiling
    ++$ntoks;
  }
  close(TT);

  ##-- flush any open sentence
  $outfh->print($fmts."</$sElt>") if ($s_open);
  $outfh->print($fmtroot."</$oDocElt>", $fmtroot);

  $nchrs = $cx->{nchr}; ##-- profiling

  ##-- all done
  vmsg(1, " done.\n");
}
process_tt_data();

##-- profiling
sub sistr {
  my ($x, $how, $prec) = @_;
  $how  = 'f' if (!defined($how));
  $prec = '.2' if (!defined($prec));
  my $fmt = "%${prec}${how}";
  return sprintf("$fmt T", $x/10**12) if ($x >= 10**12);
  return sprintf("$fmt G", $x/10**9)  if ($x >= 10**9);
  return sprintf("$fmt M", $x/10**6)  if ($x >= 10**6);
  return sprintf("$fmt K", $x/10**3)  if ($x >= 10**3);
  return sprintf("$fmt ", $x);
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

dtatw-tt2xml.perl - generate standoff annotation from tokenizer output and indices

=head1 SYNOPSIS

 dtatw-tt2xml.perl [OPTIONS] TTFILE BXFILE CXFILE

 General Options:
  -help                  # this help message

 I/O Options:
  -xml-base XMLBASE      # specify xml:base for stand-off files (default=from .cx file)
  -word-file WFILE       # output token standoff file
  -sentence-file SFILE   # output sentence standoff file
  -output BASE           # like -word-file=BASE.w -sentence-file=BASE.s
  -format , -noformat    # do/don't pretty-print output (default=no)
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

