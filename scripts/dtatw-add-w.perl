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
#our $w_refAttr = 'n';      ##-- attribute in which to place id-reference for non-initial <w>-segments
our $w_idAttr  = 'id';     ##-- attribute in which to place literal id for initial <w>-segments

##-- vars: default filename infixes
our $srcInfix = '.chr';
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
our $base = File::Basename::basename($srcfile);

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
    or die("$prog: $base: ERROR: open failed for source file '$file': $!");
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
#our ($cid);      ##-- id of currently open <c>, or undef
our (@w_ids);    ##-- $wid = $w_ids[$wix];           # <w> id-strings in .t.xml doc-order (serialized order)
#our (%cid2wid);  ##-- $wid = $cid2wid{$cid}         # <w> id-strings from <c> id-strings

## @w_segs0 = ( $w1seg1, ..., $wIseg1, ..., $wIseg2, ..., $wNsegN )
## + where:
##   $wXsegX = [$xref,$xoff,$xlen], ##-- later, [$xref,$xoff,$xlen, $segi,$prvi,$nxti]
##     $xref = $str, ##-- xml:id of the <w> to which this segment belongs
##     $xoff = $int, ##-- byte offset in $srcbuf of this <w>-segment's contents
##     $xlen = $int, ##-- byte length in $srcbuf of this <w>-segment's contents
##     $segi = $int, ##-- original segment index (+1): 1 <= $segi <= $wid2nsegs{$xref}
## + @w_segs0 is sorted in logical (serialized) order
our (@w_segs0,%wid2nsegs);
our ($x_xref,$w_xoff,$w_xend);

## @w_segs
##  + pointers to @w_segs0 segment elements
##  + segments are sorted in base-document order (according to $xoff)
our (@w_segs);

## undef = cb_init($expat)
sub so_cb_init {
  #($_xp) = @_;
  $wid     = undef;
  @w_ids   = qw();
  @w_segs0 = qw();
}

## undef = cb_start($expat, $elt,%attrs)
our ($xb,$xbi,@xbs);
sub so_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];
  if ($_[1] eq 'w') {
    $wid = $_attrs{'id'} || $_attrs{'xml:id'};
    push(@w_ids,$wid);
    if (defined($xb=$_attrs{'xb'})) {
      ##-- v0.34-1 .t.xml format: xml-bytes in //w/@xb
      $xbi = 0;
      foreach (split(/\s+/,$xb)) {
	if (/^([0-9]+)\+([0-9]+)/) {
	  push(@w_segs0,[$wid,$1,$2, ++$xbi]);
	} else {
	  $_[0]->xpcroak("$prog: $base: could not parse //w/\@xb attribute");
	}
      }
      $wid2nsegs{$wid} = $xbi;
    }
    else {
      $_[0]->xpcroak("$prog: $base: no //w/\@xb attribute defined (you need DTA::TokWrap >= v0.34-1!)");
    }
  }
}

## undef = cb_end($expat,$elt)
sub so_cb_end {
  $wid=undef if ($_[1] eq 'w');
}

##======================================================================
## Subs: splice segments into base document

## undef = write_spliced_fh($outfh)
##  + splices final segments from @w_segs into $srcbuf; dumping output to $outfh
sub splice_segments {
  my $outfh = shift;
  my ($xref_this,$xref_prev,$xref_next);
  my $off = 0;

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
	$outfh->print("<w part=\"I\" $w_idAttr=\"$xref_this\" next=\"$xref_next\">");
      } elsif ($segi==$nsegs) {
	##-- start-tag: multi-segment item: final segment
	$outfh->print("<w part=\"F\" $w_idAttr=\"$xref_this\" prev=\"$xref_prev\">"); #." $w_refAttr=\"#$xref\""
      } else {
	##-- start-tag: multi-segment item: middle segment
	$outfh->print("<w part=\"M\" $w_idAttr=\"$xref_this\" prev=\"$xref_prev\" next=\"$xref_next\">"); #." $w_refAttr=\"#$xref\""
      }
    }

    ##-- splice in segment content and end-tag
    $outfh->print(substr($srcbuf,$xoff,$xlen), "</w>");

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
					 #Final => \&so_cb_final,
					},
			   )
  or die("$prog: $base: ERROR: couldn't create XML::Parser for standoff .w.xml file");

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
our $outfh = IO::File->new(">$outfile")
  or die("$prog: $base: ERROR: open failed for output file '$outfile': $!");

##-- load source xml (.chr.xml) buffer
print STDERR "$prog: buffering source file '$srcfile'..."
  if ($verbose>=$vl_progress);
our $srcbuf = '';
bufferSrcFile($srcfile,\$srcbuf);
print STDERR " done.\n" if ($verbose>=$vl_progress);

##-- load standoff (.w.xml) records: @w_ids, @w_segs0, %wid2nsegs
print STDERR "$prog: parsing standoff ${soInfix}.xml file '$sofile'..."
  if ($verbose>=$vl_progress);
$xp_so->parsefile($sofile);
print STDERR " done.\n" if ($verbose>=$vl_progress);

##-- report final assignment
if ($verbose>=$vl_progress) {
  my $nitems   = scalar(keys(%wid2nsegs));
  my $ndiscont = scalar(grep {$_>1} values %wid2nsegs);
  my $pdiscont = ($nitems==0 ? 'NaN' : sprintf("%.1f", 100*$ndiscont/$nitems));
  print STDERR
    ("$prog: assigned ", scalar(@w_segs0), " segments to $nitems tokens",
     #": ", (@w_segs-keys(%wid2nsegs)), " discontinuities\n",
     "; $ndiscont discontinuous ($pdiscont%)\n",
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
