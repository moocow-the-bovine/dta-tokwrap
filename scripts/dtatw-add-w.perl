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
our $w_idAttr  = 'id';     ##-- attribute in which to place literal id for initial <w>-segments
our $s_idAttr  = 'id';	   ##-- attribute in which to place literal id for initial <s>-segments

##-- vars: default filename infixes
our $srcInfix = '.chr';
our $soInfix  = '.t';

##-- constants: verbosity levels
our $vl_silent   = 0;
our $vl_info     = 1;
our $vl_progress = 2;

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,
	   'verbose|v=i' => \$verbose,
	   'quiet|q' => sub { $verbose=0; },

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
our $base = File::Basename::basename($srcfile);
$prog = "$prog: $base";

##======================================================================
## Subs: source xml file: .chr.xml

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
    or die("$prog: ERROR: open failed for source file '$file': $!");
  binmode(SRC);
  local $/=undef;
  $$bufr = <SRC>;
  close(SRC);
  return $bufr;
}


##======================================================================
## Subs: standoff-xml (.w.xml)

##--------------------------------------------------------------
## XML::Parser handlers (for standoff .w.xml file WITH //w/@xb attribute)

our ($_xp, $_elt, %_attrs);

our ($wid);      ##-- id of currently open <w>, or undef
our ($nw);	 ##-- number of tokens (//w elements) parsed
our ($ns);	 ##-- number of sentences (//s elements) parsed

## @w_segs = ( $w1seg1, ..., $wIseg1, ..., $wIseg2, ..., $wNsegN )
## + where:
##   $wXsegX = [$xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send]
##     $xref = $str, ##-- xml:id of the <w> to which this segment belongs
##     $xoff = $int, ##-- byte offset in $srcbuf of this <w>-segment's contents
##     $xlen = $int, ##-- byte length in $srcbuf of this <w>-segment's contents
##     $segi = $int, ##-- original segment index (+1): 1 <= $segi <= $wid2nsegs{$xref}
##     $sid  = $str, ##-- xml:id of the <s> element to which this <w> belongs
##     $sbegi = $int,  ##-- <s>-segment index (+1) to be opened before this token: 1 <= $ssegi <= $wid2nsegs{$xref} [see find_s_segments()]
##     $sprvi = $int,  ##-- previous <s>-segment index (+1)
##     $snxti = $int,  ##-- next <s>-segment index (+1)
##     $send  = $bool, ##-- true iff the enclosing <s>-segment should be closed after this <w>-segment
## + @w_segs is sorted in logical (serialized) order
our (@w_segs,%wid2nsegs,%sid2nsegs);

##-- constants for accessing $wseg,$sseg structures
our $SEG_XREF = 0;
our $SEG_XOFF = 1;
our $SEG_XLEN = 2;
our $SEG_SEGI = 3;
our $SEG_SID   = 4;
our $SEG_SBEGI = 5;
our $SEG_SPRVI = 6;
our $SEG_SNXTI = 7;
our $SEG_SEND  = 8;

## undef = cb_init($expat)
sub so_cb_init {
  #($_xp) = @_;
  $wid       = undef;
  $nw        = 0;
  $ns        = 0;
  @w_segs    = qw();
  %wid2nsegs = qw();
  %sid2nsegs = qw();
}

## undef = cb_start($expat, $elt,%attrs)
our ($xb,$xbi,@xbs);
sub so_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  if ($_[1] eq 'w') {
    $wid = $_attrs{'id'} || $_attrs{'xml:id'};
    ++$nw;
    if (defined($xb=$_attrs{'xb'})) {
      ##-- v0.34-1 .t.xml format: xml-bytes in //w/@xb
      $xbi = 0;
      foreach (split(/\s+/,$xb)) {
	if (/^([0-9]+)\+([0-9]+)/) {
	  push(@w_segs,[$wid,$1,$2,++$xbi, $sid,undef,undef,undef,undef]);
	} else {
	  $_[0]->xpcroak("$prog: could not parse //w/\@xb attribute");
	}
      }
      $wid2nsegs{$wid} = $xbi;
    }
    else {
      $_[0]->xpcroak("$prog: no //w/\@xb attribute defined (do you have DTA::TokWrap >= v0.34-1?)");
    }
  }
  elsif ($_[1] eq 's') {
    $sid = $_attrs{'id'} || $_attrs{'xml:id'};
    ++$ns;
  }
}

## undef = cb_end($expat,$elt)
sub so_cb_end {
  if    ($_[1] eq 'w') { $wid=undef; }
  elsif ($_[1] eq 's') { $sid=undef; }
}

## undef = cb_final($expat)
sub so_cb_final {
  #@w_segs = sort {$a->[$SEG_XOFF] <=> $b->[$SEG_XOFF]} @w_segs; ##-- NOT HERE
  ;
}

##======================================================================
## Subs: compute //s segment attributes in @w_segs

## undef = find_s_segments()
##  + populates @$seg[$SEG_SXLEN,$SEG_SSEGI] for segments in @w_segs
##  + assumes @w_segs is sorted on serialized (text) document order
##  + BUG: assumes sentence contents are in source-document order!
sub find_s_segments {
  my $pseg = undef;
  my $off  = 0;
  my ($wxref,$wxoff,$wxlen,$wsegi, $sid);
  my ($ssegi);
  my %sid2cur = qw(); ##-- $sid => [$seg_open,$seg_close]
  %sid2nsegs = qw();
  foreach (@w_segs) {
    ($wxref,$wxoff,$wxlen,$wsegi, $sid) = @$_;

    if ($sid && ($pseg=$sid2cur{$sid})
	&& $wxoff >= $off
	&& substr($srcbuf, $off, ($wxoff-$off)) =~ m{^(?:
						       (?:\s)                  ##-- non-markup
						       |(?:<[^>]*/>)           ##-- empty element
						       |(?:<!--[^>]*-->)       ##-- comment
						       |(?:<c\b[^>]*>\s*</c>)  ##-- c (whitespace-only)
						       #|(?:<w\b[^>]*>\s*</w>)  ##-- w-tag (e.g. from OCR)
						      )*$}sx
       ) {
      ##-- extend current <s>-segment to enclose this <w>-segment
      $pseg->[1][$SEG_SEND] = 0;
      $pseg->[1]            = $_;
      $_->[$SEG_SEND]       = 1;
     }
    elsif ($sid) {
      ##-- new <s>-segment beginning at this <w>-segment
      $_->[$SEG_SBEGI] = ++$sid2nsegs{$sid};
      $_->[$SEG_SEND] = 1;
      if ($pseg) {
	$pseg->[0][$SEG_SNXTI] = $_->[$SEG_SBEGI];
	$_->[$SEG_SPRVI]       = $pseg->[0][$SEG_SBEGI];
      }
      $sid2cur{$sid} = [$_,$_];
    }
    else {
      ##-- no <s>-segment at all at this <w>-segment
      $_->[$SEG_SBEGI] = $_->[$SEG_SEND] = undef;
    }

    $off = $wxoff + $wxlen;
  }
}

##======================================================================
## Subs: splice segments into base document

## undef = write_spliced_fh($outfh)
##  + splices final segments from @w_segs into $srcbuf; dumping output to $outfh
##  + sorts @w_segs on xml offset ($SEG_OFF)
sub splice_segments {
  my $outfh = shift;
  my ($xref_this,$xref_prev,$xref_next);
  my ($xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send);
  my ($nwsegs,$nssegs);
  my $off = 0;

  @w_segs = sort {$a->[$SEG_XOFF] <=> $b->[$SEG_XOFF]} @w_segs; ##-- sort in source-document order
  foreach (@w_segs) {
    ##-- common vars
    ($xref,$xoff,$xlen,$segi, $sid,$sbegi,$sprvi,$snxti,$send) = @$_;
    $nwsegs  = $wid2nsegs{$xref};

    ##-- splice in prefix
    $outfh->print(substr($srcbuf, $off, ($xoff-$off)));

    ##-- maybe splice in <s>-start-tag
    if ($sbegi) {
      if (!$sprvi && !$snxti) {
	##-- //s-start-tag: single-element item
	$outfh->print("<s $s_idAttr=\"$sid\">");
      } else {
	##-- //s-start-tag: multi-segment item
	$xref_this = "${sid}".($sprvi ? "_$sbegi" : '');
	$xref_prev = "${sid}".(($sprvi||1)==1 ? '' : "_${sprvi}");
	$xref_next = "${sid}_".($snxti||'');

	if (!$sprvi) {
	  ##-- //s-start-tag: multi-segment item: initial segment
	  $outfh->print("<s part=\"I\" $s_idAttr=\"$xref_this\" next=\"$xref_next\">");
	} elsif (!$snxti) {
	  ##-- //s-start-tag: multi-segment item: final segment
	  $outfh->print("<s part=\"F\" $s_idAttr=\"$xref_this\" prev=\"$xref_prev\">"); #." $s_refAttr=\"#$xref\""
	} else {
	  ##-- //s-start-tag: multi-segment item: middle segment
	  $outfh->print("<s part=\"M\" $s_idAttr=\"$xref_this\" prev=\"$xref_prev\" next=\"$xref_next\">"); #." $s_refAttr=\"#$xref\""
	}
      }
    }

    ##-- splice in <w>-start-tag
    ## + CHANGED Tue, 20 Mar 2012 16:28:51 +0100 (moocow): dta-tokwrap v0.28
    ##    - use @prev,@next attributes for segmentation
    ##    - keep old @part attributes for compatibility (but throw out $w_refAttr ("n"))
    if ($nwsegs==1) {
      ##-- //w-start-tag: single-segment item
      $outfh->print("<w $w_idAttr=\"$xref\">");
    } else {
      ##-- //w-start-tag: multi-segment item
      $xref_this = "${xref}".($segi>1 ? ("_".($segi-1)) : '');
      $xref_prev = "${xref}".($segi>2 ? ("_".($segi-2)) : '');
      $xref_next = "${xref}_${segi}";

      if ($segi==1) {
	##-- //w-start-tag: multi-segment item: initial segment
	$outfh->print("<w part=\"I\" $w_idAttr=\"$xref_this\" next=\"$xref_next\">");
      } elsif ($segi==$nwsegs) {
	##-- //w-start-tag: multi-segment item: final segment
	$outfh->print("<w part=\"F\" $w_idAttr=\"$xref_this\" prev=\"$xref_prev\">"); #." $w_refAttr=\"#$xref\""
      } else {
	##-- //w-start-tag: multi-segment item: middle segment
	$outfh->print("<w part=\"M\" $w_idAttr=\"$xref_this\" prev=\"$xref_prev\" next=\"$xref_next\">"); #." $w_refAttr=\"#$xref\""
      }
    }

    ##-- //w-segment: splice in content and end-tag(s)
    $outfh->print(substr($srcbuf,$xoff,$xlen),
		  "</w>",
		  ($send ? "</s>" : qw()));

    ##-- update offset
    $off = $xoff+$xlen;
  }

  ##-- splice in post-token material
  $outfh->print(substr($srcbuf, $off,length($srcbuf)-$off));
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
					 Final => \&so_cb_final,
					},
			   )
  or die("$prog: ERROR: couldn't create XML::Parser for standoff ${soInfix}-xml file");

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
our $outfh = IO::File->new(">$outfile")
  or die("$prog: ERROR: open failed for output file '$outfile': $!");

##-- load source xml (.chr.xml) buffer
print STDERR "$prog: buffering source file '$srcfile'..."
  if ($verbose>=$vl_progress);
our $srcbuf = '';
bufferSrcFile($srcfile,\$srcbuf);
print STDERR " done.\n" if ($verbose>=$vl_progress);

##-- load standoff (.w.xml) records: @w_segs, %wid2nsegs, $nw
print STDERR "$prog: parsing standoff ${soInfix}.xml file '$sofile'..." if ($verbose>=$vl_progress);
$xp_so->parsefile($sofile);
print STDERR " done.\n" if ($verbose>=$vl_progress);

##-- compute //s segments
print STDERR "$prog: searching for //s segments..." if ($verbose>=$vl_progress);
find_s_segments();
print STDERR " done.\n" if ($verbose>=$vl_progress);

##-- report final assignment
if ($verbose>=$vl_info) {
  my $nseg_w = scalar(@w_segs);
  my $ndis_w = scalar(grep {$_>1} values %wid2nsegs);
  my $pdis_w = ($nw==0 ? 'NaN' : 100*$ndis_w/$nw);
  ##
  my $nseg_s = 0; $nseg_s += $_ foreach (values %sid2nsegs);
  my $ndis_s = scalar(grep {$_>1} values %sid2nsegs);
  my $pdis_s = ($ns==0 ? 'NaN' : 100*$ndis_s/$ns);
  ##
  my $dfmt = "%".length($nw)."d";
  print STDERR
    (sprintf("$prog: INFO: $dfmt token(s)    in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)\n", $nw, $nseg_w, $ndis_w, $pdis_w),
     sprintf("$prog: INFO: $dfmt sentence(s) in $dfmt segment(s): $dfmt discontinuous (%5.1f%%)\n", $ns, $nseg_s, $ndis_s, $pdis_s),
    );
}

##-- output: splice in <w>-segments
splice_segments($outfh);
print STDERR ("$prog: wrote output to '$outfile'\n")
  if ($verbose>=$vl_progress);

__END__

=pod

=head1 NAME

dtatw-add-w.perl - splice standoff <w>-records into original .chr.xml files

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

Splice standoff <w>-records into original .chr.xml files, producing .cw.xml files.

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
