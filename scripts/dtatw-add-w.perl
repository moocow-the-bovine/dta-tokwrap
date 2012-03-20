#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;


##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $verbose = 1;     ##-- print progress messages by default

##-- debugging
our $DEBUG = 0;

##-- vars: I/O
our $outfile = "-";   ##-- default: stdout

##-- vars: xml structure
our $w_refAttr = 'n';      ##-- attribute in which to place id-reference for non-initial <w>-segments
our $w_idAttr  = 'id';     ##-- attribute in which to place literal id for initial <w>-segments

##-- vars: default filename infixes
our $srcInfix = '.char';
our $soInfix  = '.t';

##-- constants: verbosity levels
our $vl_progress = 1;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=!$_[1]; },

	   ##-- I/O
	   'output|out|o=s' => \$outfile,
	  );

pod2usage({
	   -exitval=>0,
	   -verbose=>0,
	  }) if ($help);
pod2usage({
	   -message=>"Not enough arguments given!",
	   -exitval=>0,
	   -verbose=>0,
	  }) if (@ARGV < 1);


##-- command-line: arguments
our ($srcfile, $sofile) = @ARGV;
if (!defined($sofile)) {
  ($sofile = $srcfile) =~ s/\.xml$/${soInfix}.xml/i;
}

##======================================================================
## Subs: source xml file: .char.xml

## \$str = bufferSrcFile($filename)
## \$str = bufferSrcFile($filename,\$str)
##   + buffers $filename contents to $str
sub bufferSrcFile {
  my ($file,$bufr) = @_;
  if (!$bufr) {
    my $buf = '';
    $bufr = \$buf;
  }
  open(SRC,"<$file")
    or die("$prog: open failed for source file '$file': $!");
  binmode(SRC);
  local $/=undef;
  $$bufr = <SRC>;
  close(SRC);
  return $bufr;
}


##======================================================================
## Subs: standoff-xml (.w.xml)

##--------------------------------------------------------------
## XML::Parser handlers (for standoff .w.xml file)

our ($_xp, $_elt, %_attrs);

our ($wid);      ##-- id of currently open <w>, or undef
our ($cid);      ##-- id of currently open <c>, or undef
our (@w_ids);     ##-- $wid = $w_ids[$wix];           # <w> id-strings in .t.xml doc-order (serialized order)
our (%cid2wid);  ##-- $wid = $cid2wid{$cid}         # <w> id-strings from <c> id-strings

our $cRefAttr = 'ref'; ##-- <c> attribute carrying id-reference for .w.xml file

## undef = cb_init($expat)
sub so_cb_init {
  #($_xp) = @_;
  $wid     = undef;
  @w_ids   = qw();
  %cid2wid = qw();
}

## undef = cb_start($expat, $elt,%attrs)
our ($cs,@cids,$cp,$ci0,$cin);
sub so_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  if ($_[1] eq 'w') {
    $wid = $_attrs{'id'} || $_attrs{'xml:id'};
    push(@w_ids,$wid);
    if (defined($cs=$_attrs{'cs'}) || defined($cs=$_attrs{'c'})) {
      ##-- .t.xml or .u.xml format: id-list in @cs or @c attribute
      @cids = map {
	(m/^(.*)c([0-9]+)\+([0-9]+)$/ ? (map {$1.'c'.$_} ($2..($2+$3-1))) : $_)
      } split(' ',$cs);
      $cid2wid{$_} = $wid foreach (@cids);
    }
  }
  elsif ($_[1] eq 'c' && defined($cid=$_attrs{$cRefAttr})) {
    ##-- .w.xml format (big & ugly)
    $cid =~ s/^\#//;
    $cid2wid{$cid} = $wid;
  }
}

## undef = cb_end($expat,$elt)
sub so_cb_end {
  $wid=undef if ($_[1] eq 'w');
}


##======================================================================
## Subs: source-file stuff (.char.xml)

##--------------------------------------------------------------
## XML::Parser handlers: src2segs: ($srcfile -> @w_segs0)
##
## @w_segs0 = ( $w1seg1, ..., $wIseg1, ..., $wIseg2, ..., $wNsegN )
## + where:
##   $wXsegX = [$xref,$xoff,$xlen], ##-- later, [$xref,$xoff,$xlen, $segi]
##   $xref   = $str, ##-- xml:id of the <w> to which this segment belongs
##   $xoff   = $int, ##-- byte offset in $srcbuf of this <w>-segment's contents
##   $xlen   = $int, ##-- byte length in $srcbuf of this <w>-segment's contents
##   $segi   = $int, ##-- segment index (+1): 1 <= $segi <= $wid2nsegs{$xref}

our (@w_segs0);
our ($total_depth,$text_depth);
our ($w_xref,$w_xoff,$w_xend);

## undef = cb_init($expat)
sub src2segs_cb_init {
  #($_xp) = @_;
  ($w_xref,$w_xoff,$w_xend) = ('',0,0);
  $total_depth = $text_depth = 0;
  @w_segs0 = qw();
}

## undef = src2segs_flush_segment()
##  + flushes current <w> segment, if any
sub src2segs_flush_segment {
  $w_xlen  = $w_xend-$w_xoff;
  return if (!$w_xref || !$w_xlen);
  push(@w_segs0, [$w_xref,$w_xoff,$w_xlen]);
  ($w_xref,$w_xoff,$w_xend)=('',0,0);
}

## undef = cb_final($expat)
sub src2segs_cb_final {
  src2segs_flush_segment();
  return \@w_segs0;
}

## undef = cb_start($expat, $elt,%attrs)
sub src2segs_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  ++$total_depth;
  ##--------------------------
  if ($_[1] eq 'c') {
    %_attrs = @_[2..$#_];
    $cid = $_attrs{'id'} || $_attrs{'xml:id'};
    $wid = $cid2wid{$cid||''} || '';
    if ($w_xref ne $wid) {
      ##-- flush current segment & start a new one
      src2segs_flush_segment();
      $w_xref = $wid;
      $w_xoff = $w_xend = $_[0]->current_byte();
    } else {
      $w_xend = $_[0]->current_byte();
    }
    return;
  }
  ##--------------------------
  elsif ($_[1] eq 'text') {
    ++$text_depth;
  }
  src2segs_flush_segment();
}

## undef = cb_end($expat, $elt)
sub src2segs_cb_end {
  #($_xp,$_elt) = @_;
  if ($_[1] eq 'c') {
    $w_xend = $_[0]->current_byte() + length($_[0]->original_string());
  } else {
    src2segs_flush_segment();
  }
  --$total_depth;
}

## undef = cb_char($expat,$string)
sub src2segs_cb_char {
  #src2segs_flush_segment();
  $w_xend = $_[0]->current_byte() + length($_[0]->original_string());
}

## undef = cb_default($expat, $str)
sub src2segs_cb_default {
  src2segs_flush_segment();
}


##======================================================================
## MAIN

##-- initialize XML::Parser (for .w.xml file)
$xp_so = XML::Parser->new(
			    ErrorContext => 1,
			    ProtocolEncoding => 'UTF-8',
			    #ParseParamEnt => '???',
			    Handlers => {
					 #Init  => \&so_cb_init,
					 #Char  => \&so_cb_char,
					 Start => \&so_cb_start,
					 End   => \&so_cb_end,
					 #Default => \&so_cb_default,
					 #Final => \&so_cb_final,
					},
			   )
  or die("$prog: couldn't create XML::Parser for standoff .w.xml file");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
our $outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- load standoff (.w.xml) records: @w_ids, %cid2wid
print STDERR "$prog: parsing standoff ${soInfix}.xml file '$sofile'...\n"
  if ($verbose>=$vl_progress);
$xp_so->parsefile($sofile);
print STDERR "$prog: parsed ", scalar(keys(%cid2wid)), " <c>-references in ", scalar(@w_ids), " <w>-records from '$sofile'\n"
  if ($verbose>=$vl_progress);

##-- load source xml (.char.xml) buffer
our $srcbuf = '';
bufferSrcFile($srcfile,\$srcbuf);
print STDERR "$prog: buffered ", length($srcbuf), " XML bytes from '$srcfile'\n"
  if ($verbose>=$vl_progress);

##-- find all potential standoff item-segments (@w_segs0)
print STDERR "$prog: scanning for potential <w>-segment boundaries in '$srcfile'...\n"
  if ($verbose>=$vl_progress);
$xp_src2segs = XML::Parser->new(
			      ErrorContext => 1,
			      ProtocolEncoding => 'UTF-8',
			      #ParseParamEnt => '???',
			      Handlers => {

					   Init   => \&src2segs_cb_init,
					   #XmlDecl => \&src2segs_cb_xmldecl,
					   #Char  => \&src2segs_cb_char,
					   Start  => \&src2segs_cb_start,
					   End    => \&src2segs_cb_end,
					   #Default => \&src2segs_cb_default,
					   Final   => \&src2segs_cb_final,
					  },
			     )
  or die("$prog: couldn't create XML::Parser for ${srcInfix}.xml <w>-segmentation");
$xp_src2segs->parse($srcbuf);
print STDERR ("$prog: found ", scalar(@w_segs0), " preliminary segments for ", scalar(@w_ids), " tokens\n")
  if ($verbose>=$vl_progress);

##-- check for bogus discontinutities
print STDERR "$prog: merging \"adjacent\" segments...\n"
  if ($verbose>=$vl_progress);
@w_segs  = qw();
$pseg    = undef;
$off     = 0;
foreach (@w_segs0) {
  ($xref,$xoff,$xlen,$segi) = @$_;
  if ($pseg && $pseg->[0] eq $xref
      &&
      substr($srcbuf, $off, ($xoff-$off)) =~ m{^(?:
                                                   (?:\s)                 ##-- whitespace
                                                  |(?:<[^>]*/>)           ##-- empty element
                                                  |(?:<!--[^>]*-->)       ##-- comment
                                                  |(?:<c\b[^>]*>\s*</c>)  ##-- c (whitespace-only)
                                                )*$}sx
     )
    {
      $pseg->[2] += ($xoff+$xlen-$off);
    }
  else
    {
      push(@w_segs,$_);
    }
  $pseg = $_;
  $off  = $xoff+$xlen;
}
print STDERR ("$prog: found ", scalar(@w_segs), " final segments for ", scalar(@w_ids), " tokens\n")
  if ($verbose>=$vl_progress);

##-- count segments
print STDERR ("$prog: assigning segments to tokens...\n")
  if ($verbose>=$vl_progress);
our %wid2nsegs = qw();  ##-- ($wid => $n_segments_for_wid, ...)
foreach (@w_segs) {
  push(@$_, ++$wid2nsegs{$_->[0]});
}

if ($verbose>=$vl_progress) {
  my $nitems   = scalar(keys(%wid2nsegs));
  my $ndiscont = scalar(grep {$_>1} values %wid2nsegs);
  my $pdiscont = ($nitems==0 ? 'NaN' : sprintf("%.1f", 100*$ndiscont/$nitems));
  print STDERR
    ("$prog: assigned ", scalar(@w_segs), " segments to $nitems tokens",
     #": ", (@w_segs-keys(%wid2nsegs)), " discontinuities\n",
     "; $ndiscont discontinuous ($pdiscont%)\n",
    );
}

##-- output: splice in <w>-segments
our $off = 0; ##-- global offset
our ($xref_this,$xref_prev,$xref_next);
foreach (@w_segs) {
  ##-- common vars
  ($xref,$xoff,$xlen,$segi) = @$_;
  $nsegs = $wid2nsegs{$xref};

  ##-- splice in prefix
  $outfh->print(substr($srcbuf, $off, ($xoff-$off)));

  ##-- splice in start-tag
  ## + CHANGED Tue, 20 Mar 2012 16:28:51 +0100 (moocow): dta-tokwrap v0.28
  ##    - use @prev,@next attributes for segmentation
  ##    - keep old @part attributes for compatibility (but throw out $w_refAttr ("n"))
  if ($nsegs==1) {
    ##-- start-tag: single-segment item
    $outfh->print("<w $w_idAttr=\"$xref\">");
  } else {
    $xref_this = "${xref}".($segi>1 ? ("_".($segi-1)) : '');
    $xref_prev = "${xref}".($segi>2 ? ("_".($segi-2)) : '');
    $xref_next = "${xref}_${segi}";

    if ($segi==1) {
      ##-- start-tag: multi-segment item: initial segment
      $outfh->print("<w part=\"I\" $w_idAttr=\"$xref_this\" next=\"#$xref_next\">");
    } elsif ($segi==$nsegs) {
      ##-- start-tag: multi-segment item: final segment
      $outfh->print("<w part=\"F\" $w_idAttr=\"$xref_this\" prev=\"#$xref_prev\">"); #." $w_refAttr=\"#$xref\""
    } else {
      ##-- start-tag: multi-segment item: middle segment
      $outfh->print("<w part=\"M\" $w_idAttr=\"$xref_this\" prev=\"#$xref_prev\" next=\"#$xref_next\">"); #." $w_refAttr=\"#$xref\""
    }
  }

  ##-- splice in segment content and end-tag
  $outfh->print(substr($srcbuf,$xoff,$xlen), "</w>");

  ##-- update offset
  $off = $xoff+$xlen;
}

##-- splice in post-token material
$outfh->print(substr($srcbuf, $off,length($srcbuf)-$off));

__END__

=pod

=head1 NAME

dtatw-add-w.perl - splice standoff <w>-records into original .char.xml files

=head1 SYNOPSIS

 dtatw-add-w.perl [OPTIONS] CHAR_XML_FILE (W|T|U)_XML_FILE

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -output FILE           # specify output file (default='-' (STDOUT))

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

Splice standoff <w>-records into original .char.xml files, producing .cw.xml files.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dtatw-add-c.perl(1)|dtatw-add-c.perl>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-add-s.perl(1)|dtatw-add-s.perl>,
L<dtatw-rm-c.perl(1)|dtatw-rm-c.perl>,
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut
