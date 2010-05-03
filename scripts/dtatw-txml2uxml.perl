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
our $wpxfile = undef; ##-- default: from xml file
our $cpxfile = undef; ##-- default: from xml file
our $do_t0 = 1;
our $do_pb = undef;
our $do_unicruft = 1;
our $do_inter_token_chars = 0;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

	   ##-- text file?
	   'textfile|txtfile|text|txt|tf=s' => \$txtfile,
	   'wpx-file|wpxfile|wpxf|wpx|wpf=s' => \$wpxfile,
	   'cpx-file|xpxfile|cpxf|cpx|cpf=s' => \$cpxfile,
	   't0!' => \$do_t0,
	   'pb!' => \$do_pb,
	   'unicruft|cruft|u!' => \$do_unicruft,
	   'inter-token-characters|inter-token-chars|chars|itc|c!' => \$do_inter_token_chars,

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

## $wpx = load_pxfile($pxfile)
sub load_pxfile {
  my $pxfile = shift;
  my $px = {};
  open(PX,"<$pxfile") or die("$0: load_pxfile(): open failed for '$pxfile': $!");
  my ($line,$xid,@data);
  while (defined($line=<PX>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^\%\%/);
    ($xid,@data) = split(/\t/,$line);
    $px->{$xid} = [@data];
  }
  return $px;
}

## $doc = txml2uxml($doc)
##  + uses global $txtbufr
sub txml2uxml {
  my $doc = shift;
  my ($wi,$wnod,$wb,$off,$len, $wt0,$wt, $wpnod, $xid,$pxdata);
  my $wnods = $doc->findnodes('//w');
  my $poff  = 0;
  foreach $wnod (@$wnods) {
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
    if ($do_inter_token_chars) {
      ##-- inter-token characters
      $cnod = cNode($poff,$off);
      $wnod->parentNode->insertBefore($cnod,$wnod);
    }
    if ($do_pb) {
      if (defined($wpx)) {
	##-- pagebreak index from .wpx file
	$xid = $wnod->getAttribute('id');
	$xid = $wnod->getAttribute('xml:id') if (!defined($xid));
	$pxdata=$wpx->{$xid};
      }
      elsif (defined($cpx)) {
	##-- pagebreak index from .cpx file
	$xid = $wnod->getAttribute('c');
	$xid =~ s/\s.*$//; ##-- truncate
	$pxdata=$cpx->{$xid};
      }
      $wnod->setAttribute('pb',($pxdata && defined($pxdata->[0]) ? $pxdata->[0] : '-1'));
    }
    $poff = $off+$len;
  }
  if ($do_inter_token_chars) {
    ##-- final <c> node
    $cnod = cNode($poff,length($$txtbufr));
    $wnods->[$#$wnods]->parentNode->insertAfter($cnod, $wnods->[$#$wnods]);
  }
  return $doc;
}

## $cnod_or_undef = cNode($previous_offset,$current_offset)
##  + creates a new <c> node for text range ($previous_offset..$current_offset)
our ($poff,$off,$cstr,$cnod);
BEGIN { *cNode=\&cNode1; }
sub cNode2 {
  ($poff,$off) = @_;
  $cstr = substr($$txtbufr,$poff,($off-$poff));
  $cstr = decode('utf8',$cstr) if (!utf8::is_utf8($cstr));
  ##
  $cnod = XML::LibXML::Text->new($cstr);
  return $cnod;
}

sub cNode1 {
  ($poff,$off) = @_;
  $cstr = substr($$txtbufr,$poff,($off-$poff));
  $cstr = decode('utf8',$cstr) if (!utf8::is_utf8($cstr));
  ##
  $cnod = XML::LibXML::Element->new('c');
  #$cnod->setAttribute('t', $cstr);
  $cnod->setAttribute('b', $poff." ".($off-$poff));
  #$cnod->appendText($cstr);
  $cnod->setAttribute('t',$cstr);
  return $cnod;
}

sub cNode0 {
  my ($poff,$off) = @_;
  my $cstr = substr($$txtbufr,$poff,($off-$poff));
  $cstr = decode('utf8',$cstr) if (!utf8::is_utf8($cstr));
  ##
  my $cnod = XML::LibXML::Element->new('c');
  $cnod->setAttribute('t', $cstr);
  $cnod->setAttribute('b', $poff." ".($off-$poff));
  my ($ustr);
  if ($do_unicruft) {
    ##-- unicruft approximation
    $cnod->setAttribute('u', $ustr=decode('latin1',Unicruft::utf8_to_latin1_de($cstr)));
  }
  if ($do_t0) {
    ##-- raw text
    $cnod->setAttribute('t0',$cstr);
    $cnod->setAttribute('u0', $ustr) if ($do_unicruft);
  }
  return $cnod;
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

##-- input basename
our $inbase = $infile;
$inbase =~ s/\.t\.xml//i;

##-- parse raw text buffer
our ($txtbufr);
if ($do_t0) {
  $txtfile = "$inbase.txt" if (!defined($txtfile));
  $txtbufr = slurpText($txtfile);
}

##-- pagebreak index (use one of $wpx or $cpx, depending on args)
our ($wpx); ##-- $wpx: w/@id to page data: {$wid=>\@pxdata=[$pb_i,$pb_n,$pb_facs]}
our ($cpx); ##-- $cpx: c/@id to page data: {$cid=>\@pxdata=[$pb_i,$pb_n,$pb_facs]}
$do_pb=1 if (!defined($do_pb) && (defined($wpxfile) || defined($cpxfile)));
if ($do_pb) {
  if (!defined($wpxfile) && !defined($cpxfile)) {
    $wpxfile = "$inbase.wpx";
    $cpxfile = "$inbase.cpx";
  }
  if (defined($wpxfile)) {
    $wpx = load_pxfile($wpxfile);
  } elsif (defined($cpxfile)) {
    $cpx = load_pxfile($cpxfile);
  }
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
  -wpxfile  WPXFILE      # .wpx file for output //w/@pb locations
  -pb     , -nopb        # do/don't parse and output page break indices as //w/@pb (default=only if -wpxfile is given)
  -t0     , -not0        # do/don't output original text from TXTFILE as //w/@t0 (default=do)
  -cruft  , -nocruft     # do/don't output unicruft approximations as //w/@u rsp //w/@u0 (default=do)
  -chars  , -nochars     # do/don't output inter-token chars as //c (default=don't)

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
