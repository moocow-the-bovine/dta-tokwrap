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
our $s_refAttr = 'n';      ##-- attribute in which to place id-reference for non-initial <w>-segments
our $s_idAttr  = 'xml:id'; ##-- attribute in which to place literal id for initial <w>-segments

##-- vars: default filename infixes
our $srcInfix = '.cw';
our $soInfix  = '.s';

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
## Subs: standoff-xml (.s.xml)

##--------------------------------------------------------------
## XML::Parser handlers (for standoff .s.xml file)

our ($_xp, $_elt, %_attrs);

our ($sid);      ##-- id of currently open <s>, or undef
our ($wid);      ##-- id of currently open <w>, or undef
our (@s_ids);     ##-- $sid = $s_ids[$wix];           # <s> id-strings in .s.xml doc-order (serialized order)
our (%wid2sid);  ##-- $sid = $wid2sid{$wid}         # <s> id-strings from <w> id-strings

our $wRefAttr = 'ref'; ##-- <w> attribute carrying id-reference for .s.xml file

## undef = cb_init($expat)
sub so_cb_init {
  #($_xp) = @_;
  $sid     = undef;
  @s_ids    = qw();
  %wid2sid = qw();
}

## undef = cb_start($expat, $elt,%attrs)
sub so_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  if ($_[1] eq 'w' && defined($wid=$_attrs{$wRefAttr})) {
    $wid =~ s/^\#//;
    $wid2sid{$wid} = $sid;
  }
  elsif ($_[1] eq 's') {
    $sid = $_attrs{'xml:id'};
    push(@s_ids,$sid);
  }
}

## undef = cb_end($expat,$elt)
sub so_cb_end {
  $sid=undef if ($_[1] eq 's');
}


##======================================================================
## Subs: source-file stuff (.cw.xml)

##--------------------------------------------------------------
## XML::Parser handlers: src2segs: ($srcfile -> @wsegs)
##
## @s_segs0 = ( $s1seg1, ..., $sIseg1, ..., $sIseg2, ..., $sNsegN )
## + where:
##   $sXsegX = [$xref,$xoff,$xlen], ##-- later, [$xref,$xoff,$xlen, $segi]
##   $xref   = $str, ##-- xml:id of the <s> to which this segment belongs
##   $xoff   = $int, ##-- byte offset in $srcbuf of this <s>-segment's contents
##   $xlen   = $int, ##-- byte length in $srcbuf of this <s>-segment's contents
##   $segi   = $int, ##-- segment index (+1): 1 <= $segi <= $sid2nsegs{$xref}

our (@s_segs0);
our ($total_depth,$text_depth);
our ($s_xref,$s_xoff,$s_xend);

## undef = cb_init($expat)
sub src2segs_cb_init {
  #($_xp) = @_;
  ($s_xref,$s_xoff,$s_xend) = ('',0,0);
  $total_depth = $text_depth = 0;
  @s_segs0 = qw();
}

## undef = src2segs_flush_segment()
##  + flushes current <w> segment, if any
sub src2segs_flush_segment {
  $s_xlen  = $s_xend-$s_xoff;
  return if (!$s_xref || !$s_xlen);
  push(@s_segs0, [$s_xref,$s_xoff,$s_xlen]);
  ($s_xref,$s_xoff,$s_xend)=('',0,0);
}

## undef = cb_final($expat)
sub src2segs_cb_final {
  src2segs_flush_segment();
  return \@s_segs0;
}

## undef = cb_start($expat, $elt,%attrs)
sub src2segs_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  ++$total_depth;
  ##--------------------------
  if ($_[1] eq 'w') {
    %_attrs = @_[2..$#_];
    if (!($wid = $_attrs{'xml:id'}) && $_attrs{'n'}) {
      ($wid = $_attrs{'n'}) =~ s/^\#//;
    } else {
      ##-- bogus '//w[not(@n)]', maybe from OCR software: flush segment but otherwise ignore it
      src2segs_flush_segment();
      return;
    }
    $sid = $wid2sid{$wid} || '';
    #if ($s_xref ne $sid) {
      ##-- flush current segment & start a new one
      src2segs_flush_segment();
      $s_xref = $sid;
      $s_xoff = $s_xend = $_[0]->current_byte();
    #} else {
    #  $s_xend = $_[0]->current_byte();
    #}
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
  if ($_[1] eq 'w') {
    $s_xend = $_[0]->current_byte() + length($_[0]->original_string());
  } else {
    src2segs_flush_segment();
  }
  --$total_depth;
}

## undef = cb_char($expat,$string)
sub src2segs_cb_char {
  #src2segs_flush_segment();
  $s_xend = $_[0]->current_byte() + length($_[0]->original_string());
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

##-- load standoff (.s.xml) records: @s_ids, %wid2sid
print STDERR "$prog: parsing standoff ${soInfix}.xml file '$sofile'...\n"
  if ($verbose>=$vl_progress);
$xp_so->parsefile($sofile);
print STDERR "$prog: parsed ", scalar(keys(%wid2sid)), " <w>-references in ", scalar(@s_ids), " <s>-records from '$sofile'\n"
  if ($verbose>=$vl_progress);

##-- load source xml (.char.xml) buffer
our $srcbuf = '';
bufferSrcFile($srcfile,\$srcbuf);
print STDERR "$prog: buffered ", length($srcbuf), " XML bytes from '$srcfile'\n"
  if ($verbose>=$vl_progress);

##-- find all standoff item-segments (@s_segs0)
print STDERR "$prog: scanning for potential <s>-segment boundaries in '$srcfile'...\n"
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
  or die("$prog: couldn't create XML::Parser for ${srcInfix}.xml <s>-segmentation");
$xp_src2segs->parse($srcbuf);
print STDERR ("$prog: found ", scalar(@s_segs0), " preliminary segments for ", scalar(@s_ids), " sentences\n")
  if ($verbose>=$vl_progress);

##-- check for bogus discontinutities
print STDERR "$prog: merging \"adjacent\" segments...\n"
  if ($verbose>=$vl_progress);
@s_segs  = qw();
$pseg    = undef;
$off     = 0;
foreach (@s_segs0) {
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
      push(@s_segs,$_);
      $pseg = $_;
    }
  $off  = $xoff+$xlen;
}
print STDERR ("$prog: found ", scalar(@s_segs), " final segments for ", scalar(@s_ids), " sentences\n")
  if ($verbose>=$vl_progress);

##-- count segments
print STDERR "$prog: assigning segments to sentences...\n"
  if ($verbose>=$vl_progress);
our %sid2nsegs = qw();  ##-- ($sid => $n_segments_for_sid, ...)
foreach (@s_segs) {
  push(@$_, ++$sid2nsegs{$_->[0]});
}
print STDERR
  ("$prog: assigned ", scalar(@s_segs), " segments to ", scalar(keys(%sid2nsegs)), " sentences",
   ": ", (@s_segs-keys(%sid2nsegs)), " discontinuities\n",
  )
  if ($verbose>=$vl_progress);

##-- output: splice in <s>-segments
our $off = 0; ##-- global offset
foreach (@s_segs) {
  ##-- common vars
  ($xref,$xoff,$xlen,$segi) = @$_;
  $nsegs = $sid2nsegs{$xref};

  ##-- splice in prefix
  $outfh->print(substr($srcbuf, $off, ($xoff-$off)));

  ##-- splice in start-tag
  if ($nsegs==1) {
    ##-- start-tag: single-segment item
    $outfh->print("<s $s_idAttr=\"$xref\">");
  } elsif ($segi==1) {
    ##-- start-tag: multi-segment item: initial segment
    $outfh->print("<s part=\"I\" $s_idAttr=\"$xref\">");
  } elsif ($segi==$nsegs) {
    ##-- start-tag: multi-segment item: final segment
    $outfh->print("<s part=\"F\" $s_refAttr=\"#$xref\">");
  } else {
    ##-- start-tag: multi-segment item: middle segment
    $outfh->print("<s part=\"M\" $s_refAttr=\"#$xref\">");
  }

  ##-- splice in segment content and end-tag
  $outfh->print(substr($srcbuf,$xoff,$xlen), "</s>");

  ##-- update offset
  $off = $xoff+$xlen;
}

##-- splice in post-token material
$outfh->print(substr($srcbuf, $off,length($srcbuf)-$off));

__END__

=pod

=head1 NAME

dtatw-add-s.perl - splice standoff <s>-records into .cw.xml files

=head1 SYNOPSIS

 dtatw-add-w.perl [OPTIONS] CW_XML_FILE S_XML_FILE

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

Now respects pre-existing "c" elements, assigning them C<xml:id>s to these if required.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dtatw-add-c.perl(1)|dtatw-add-c.perl>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-add-w.perl(1)|dtatw-add-w.perl>,
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
