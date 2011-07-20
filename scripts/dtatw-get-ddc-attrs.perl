#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use XML::LibXML;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode encode_utf8 decode_utf8);
use File::Basename qw(basename);
use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

use strict;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------
our $prog = basename($0);
our $verbose = 1;     ##-- print progress messages by default
our ($help);

##-- vars: I/O
our $txmlfile = undef; ##-- required
our $cxmlfile = "-";   ##-- default: stdin
our $outfile  = "-";   ##-- default: stdout
our $format = 1;       ##-- output format level

##-- selection
our $keep_blanks = 0;
our $do_page = 1;
our $do_rendition = 1;
our $do_xcontext = 1;
our $do_xpath = 1;
our $do_bbox = 1;

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
	   'keep-blanks|blanks|whitespace|ws!' => \$keep_blanks,
	   'page|pb|p!' => $do_page,
	   'rendition|rend|r!' => \$do_rendition,
	   'xcontext|context|xcon|con|xc!' => \$do_xcontext,
	   'xpath|path|xp!' => \$do_xpath,
	   'coordinates|coords|coord|c|bboxes|bbox|b!' => \$do_bbox,
	   'output|out|o=s' => \$outfile,
	   'format|f!' => \$format,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);

##-- command-line: arguments
($txmlfile, $cxmlfile) = @ARGV;
$txmlfile = '-' if (!$txmlfile);
if (!defined($cxmlfile) || $cxmlfile eq '') {
  ($cxmlfile = $txmlfile) =~ s/\.t\.xml$/.xml/;
  pod2usage({-exitval=>0,-verbose=>0,-msg=>"$prog: could not guess CHR_XML_FILE for T_XML_FILE=$txmlfile"})
    if ($cxmlfile eq $txmlfile);
}

##======================================================================
## Subs: t-xml stuff (*.t.xml)

## %cid2wid = ($cid=>$wid, ...)
our %cid2wid = qw();

## $txmldoc = load_txml($txmlfile)
##  + loads and returns xml doc
##  + initializes auxilliary indices:
##     %cid2wid = ($cid=>$wid, ...)
sub load_txml {
  my $txmlfile = shift;

  ##-- initialize LibXML parser
  my $parser = XML::LibXML->new();
  $parser->keep_blanks($keep_blanks ? 1 : 0);
  $parser->line_numbers(1);

  ##-- load xml
  my $xdoc = $txmlfile eq '-' ? $parser->parse_fh(\*STDIN) : $parser->parse_file($txmlfile);
  die("$prog: could not parse .t.xml file '$txmlfile': $!") if (!$xdoc);

  ##-- initialize cid->wid map
  my ($wnod,$wid,$cids,@cids);
  foreach $wnod (@{$xdoc->findnodes('/*/*/w')}) {
    $wid  = $wnod->getAttribute('id') || $wnod->getAttribute('xml:id') || next; ##-- skip //w nodes without ids
    $cids = $wnod->getAttribute('c') || $wnod->getAttribute('cs');
    @cids = (
	     ##-- expand compressed //c/@id lists
	     map {
	       (m/^(.*)c([0-9]+)\+([0-9]+)$/
		? (map {$1.'c'.$_} ($2..($2+$3-1)))
		: $_)
	     } split(' ',$cids)
	    );
    $cid2wid{$_} = $wid foreach (@cids);
  }

  return $xdoc;
}

##======================================================================
## Subs: generic

## @uniq = luniq(@list)
my ($lu_tmp);
sub luniq {
  $lu_tmp=undef;
  return map {(defined($lu_tmp) && $lu_tmp eq $_ ? qw() : ($lu_tmp=$_))} sort @_;
}

##======================================================================
## Subs: cxmlfile stuff (*.chr.xml)

## @stack: stack of element-data hashes
##  + each $edata on stack = {tag=>$tag, rendition=>\%rendition, context=>\%context, ...}
##  + global $edata: current top of stack
##  + $path: current xpath (without numeric positions)
our (@stack,$edata,$xpath,$page);

our %wid2page = qw();   ##-- %wid2page: ($wid=>$pb_facs, ...)
our %wid2coords = qw(); ##-- %wid2coords: ($wid=>"$ulx,$uly,$lrx,$lry ...", ...) with $ulx<=$lrx, $uly<=$lry; -1 for undef
our %wid2rend = qw();
our %wid2xcon = qw();
our %wid2xpath = qw();

## undef = cxml_cb_init($expat)
sub cxml_cb_init {
  #($_xp) = @_;
  @stack = qw();
  $edata = { rendition=>{}, xcontext=>{} };  ##-- current stack item
  $xpath = '';
  $page  = -1;
  %wid2page = qw();
  %wid2coords = qw();
  %wid2rend = qw();
  %wid2xcon = qw();
  %wid2xpath = qw();
}

## undef = cxml_cb_final($expat)
#sub cxml_cb_final {
#  base_flush_segment();
#  return \@w_segs0;
#}

our (%_attrs);
our ($facs,$rendition,$xcontext);
our ($cid,$wid);

our %xcontext_elts = (map {($_=>$_)}
		      qw(text front body back head left foot end argument hi cit fw lg stage speaker)
		     );

## undef = cxml_cb_start($expat, $elt,%attrs)
sub cxml_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  %_attrs = @_[2..$#_];

  ##-- new stack item
  $edata = {%$edata, tag=>$_[1]};
  push(@stack,$edata);
  $xpath .= "/$_[1]";

  ##-- rendition
  if ($do_rendition && defined($rendition=$_attrs{rendition})) {
    $edata->{rendition} = { %{$edata->{rendition}}, map {($_=>undef)} split(' ',$rendition) };
  }

  ##-- tag-dispatch
  if ($_[1] eq 'c' && (defined($cid=$_attrs{'id'}) || defined($cid=$_attrs{'xml:id'})) && defined($wid=$cid2wid{$cid})) {
    ##-- //c assigned to some //w: extract data
    $wid2page{$wid}  = $page  if ($do_page && !defined($wid2page{$wid}));
    $wid2xpath{$wid} = $xpath if ($do_xpath && !defined($wid2xpath{$wid}));
    $wid2rend{$wid}  = join(' ', luniq keys(%{$edata->{rendition}}), split(' ',($wid2rend{$wid}||''))) if ($do_rendition);
    $wid2xcon{$wid}  = join(' ', luniq keys(%{$edata->{xcontext}}),  split(' ',($wid2xcon{$wid}||''))) if ($do_xcontext);

    ##-- extract coords for bbox (first page only)
    if ($do_bbox && $wid2page{$wid} == $page && defined($_attrs{ulx})) {
      $wid2coords{$wid} .= ' '.join(',', map {defined($_) ? $_ : -1} @_attrs{qw(ulx uly lrx lry)});
    }
  }
  elsif ($do_xcontext && defined($xcontext=$xcontext_elts{$_[1]})) {
    ##-- structural context: element-based
    $edata->{xcontext} = { %{$edata->{xcontext}}, $xcontext=>undef };
  }
  elsif ($do_xcontext && $_[1] eq 'note') {
    ##-- structural context: marginalia: subdivide by placement
    $xcontext = 'note_'.($_attrs{'place'}||'other');
    $edata->{xcontext} = { %{$edata->{xcontext}}, $xcontext=>undef };
  }
  elsif ($do_page && $_[1] eq 'pb' && defined($facs=$_attrs{'facs'})) {
    ##-- page break
    ($page=$facs) =~ s/^\#?f?0*//;
  }

  return;
}

## undef = cxml_cb_end($expat, $elt)
sub cxml_cb_end {
  #($_xp,$_elt) = @_;
  substr($xpath,-length($edata->{tag})-1) = '';
  pop(@stack);
  $edata = $stack[$#stack];
}

### undef = cxml_cb_char($expat,$string)
#sub cxml_cb_char {
#  $_[0]->default_current;
#}

## undef = cxml_cb_default($expat, $str)
#sub cxml_cb_default {
#  $outfh->print($_[0]->original_string);
#}

##======================================================================
## Subs: merge

## $xdoc = apply_ddc_attrs($xdoc)
##  + applies ddc attributes from %wid2xyz to $xdoc
sub apply_ddc_attrs {
  my $xdoc = shift;

  my ($wnod, $wpage,$wrend,$wcon,$wxpath,$wcoords);
  my (@wbboxes,$wbbox,@cbbox);
  foreach $wnod (@{$xdoc->findnodes('/*/*/w')}) {
    $wid = $wnod->getAttribute('id') || $wnod->getAttribute('xml:id') || next; ##-- skip //w nodes without ids

    ##-- assign: page
    if ($do_page) {
      $wpage = $wid2page{$wid};
      $wnod->setAttribute('page', defined($wpage) ? $wpage : -1); ##-- ARGH: tokwrap-inserted 'FORMEL' will not get a page this way!
    }

    ##-- assign: rendition
    if ($do_rendition) {
      $wrend = $wid2rend{$wid}||'';
      $wnod->setAttribute('rendition', $wrend);
    }

    ##-- assign: structural context : xcontext
    if ($do_xcontext) {
      $wcon = $wid2xcon{$wid}||'';
      $wnod->setAttribute('xcontext', $wcon);
    }

    ##-- assign: xpath
    if ($do_xpath) {
      $wxpath = $wid2xpath{$wid}||'';
      $wxpath =~ s|/c$||i; ##-- prune final element from //w xpath
      $wnod->setAttribute('xpath', $wxpath);
    }

    ##-- compute & assign: bbox
    if ($do_bbox) {
      $wcoords = $wid2coords{$wid}||'';
      @wbboxes = qw();
      $wbbox   = undef;
      foreach (split(' ',$wcoords)) {
	@cbbox = map {defined($_) ? $_ : -1} split(/,/,$_); #
	#($ulx,$uly,$lrx,$lry)=@cbbox;
	next if (grep {$_ < 0} @cbbox); ##-- skip //c bboxes with bad values
	if (!$wbbox) {
	  ##-- initial bbox
	  @wbboxes = ($wbbox=[@cbbox]);
	  next;
	} elsif ($cbbox[2] < $wbbox->[0]) {
	  ##-- character:RIGHT << word:LEFT: probably a line-break: new word bbox
	  push(@wbboxes, $wbbox=[@cbbox]);
	} elsif ($cbbox[3] < $wbbox->[1]) {
	  ##-- character:BOTTOM >> word:TOP: probably a column-break: new word bbox
	  push(@wbboxes, $wbbox=[@cbbox]);
	} else {
	  ##-- extend current word bbox if required
	  $wbbox->[0] = $cbbox[0] if ($cbbox[0] < $wbbox->[0]);
	  $wbbox->[1] = $cbbox[1] if ($cbbox[1] < $wbbox->[1]);
	  $wbbox->[2] = $cbbox[2] if ($cbbox[2] > $wbbox->[2]);
	  $wbbox->[3] = $cbbox[3] if ($cbbox[3] > $wbbox->[3]);
	}
      }
      $wnod->setAttribute('bbox',join('_', map {join('|',@$_)} @wbboxes));
    }
  }
  return $xdoc;
}


##======================================================================
## MAIN

##-- grab .t.xml file into a libxml doc & pre-index some data
print STDERR "$prog: loading *.t.xml file '$txmlfile'...\n"
  if ($verbose>=$vl_progress);
our $xdoc = load_txml($txmlfile);

##-- scan .chr.xml file and grab attributes
print STDERR "$prog: scanning *.chr.xml file '$cxmlfile'...\n"
  if ($verbose>=$vl_progress);
our $xp_cxml = XML::Parser->new(
				ErrorContext => 1,
				ProtocolEncoding => 'UTF-8',
				#ParseParamEnt => '???',
				Handlers => {
					     Init   => \&cxml_cb_init,
					     #XmlDecl => \&cxml_cb_xmldecl,
					     #Char  => \&cxml_cb_char,
					     Start  => \&cxml_cb_start,
					     End    => \&cxml_cb_end,
					     #Default => \&cxml_cb_default,
					     #Final   => \&cxml_cb_final,
					    },
			       )
  or die("$prog: couldn't create XML::Parser for *.c.xml file '$cxmlfile'");
$xp_cxml->parsefile($cxmlfile);

##-- apply attributes
print STDERR "$prog: applying DDC-relevant attributes...\n"
  if ($verbose>=$vl_progress);
$xdoc = apply_ddc_attrs($xdoc);

##-- dump
print STDERR "$prog: dumping output file '$outfile'...\n"
  if ($verbose>=$vl_progress);
($outfile eq '-' ? $xdoc->toFH(\*STDOUT,$format) : $xdoc->toFile($outfile,$format))
  or die("$0: failed to write output file '$outfile': $!");






__END__

=pod

=head1 NAME

dtatw-get-ddc-attrs.perl - get DDC-relevant attributes from DTA::TokWrap files

=head1 SYNOPSIS

 dtatw-get-ddc-attrs.perl [OPTIONS] T_XML_FILE [CHR_XML_FILE=T_XML_FILE:.t.xml=.xml]

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (0<=LEVEL<=1)
  -quiet                 # be silent

 I/O Options:
  -blanks , -noblanks    # don't/do ignore 'ignorable' whitespace in T_XML_FILE file (default=ignored)
  -page   , -nopage      # do/don't extract //w/@page attributes (default=do)
  -rend   , -norend      # do/don't extract //w/@rendition attributes (default=do)
  -xcon   , -noxcon      # do/don't extract //w/@xcontext attributes (default=do)
  -xpath  , -noxpath     # do/don't extract //w/@xpath attributes (default=do)
  -bbox   , -nobbox      # do/don't extract //w/@bbox attributes (default=do)
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

Splice DDC-relevant attributes from DTA *.chr.xml files into DTA::TokWrap *.t.xml files.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

L<dtatw-add-c.perl(1)|dtatw-add-c.perl>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
L<dtatw-add-w.perl(1)|dtatw-add-w.perl>,
L<dtatw-add-s.perl(1)|dtatw-add-s.perl>,
L<dtatw-splice.perl(1)|dtatw-splice.perl>,
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
