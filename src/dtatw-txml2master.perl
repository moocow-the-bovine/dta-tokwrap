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

##-- debugging
our $DEBUG = 0;

##-- vars: I/O
our $outfile = "-"; ##-- default: stdout

##-- XML::Parser stuff
our ($xp); ##-- underlying XML::Parser object

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(##-- General
	   'help|h' => \$help,

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
	  }) if (@ARGV < 2);

##-- command-line: arguments
our ($txmlfile, $cxmlfile) = @ARGV;

##======================================================================
## Subs: .char.xml

## \$str = bufferCharXmlFile($filename)
## \$str = bufferCharXmlFile($filename,\$str)
##   + buffers $filename contents to $str
sub bufferCharXmlFile {
  my ($file,$bufr) = @_;
  if (!$bufr) {
    my $buf = '';
    $bufr = \$buf;
  }
  open(CHARXML,"<$file")
    or die("$prog: open failed for .char.xml file '$file': $!");
  binmode(CHARXML);
  local $/=undef;
  $$bufr = <CHARXML>;
  close(CHARXML);
  return $bufr;
}


##======================================================================
## Subs: .t.xml stuff

##--------------------------------------------------------------
## XML::Parser handlers (for .t.xml file)

our ($_xp, $_elt, %_attrs);
our ($sid,$wid) = ('','');

our @wids    = qw();  ##-- $wid = $wids[$wix];           # <w> id-strings in .t.xml doc-order (serialized order)
our %wid2sid = qw();  ##-- $sid = $wid2sid{$wid};        # <s> id-strings from <w> id-strings
our %cid2wid = qw();  ##-- $wid = $cid2wid{$cid}         # <w> id-strings from <c> id-strings

## undef = cb_start($expat, $elt,%attrs)
sub txml_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  if ($_[1] eq 's') {
    %_attrs = @_[2..$#_];
    $sid = $_attrs{'xml:id'};
  }
  elsif ($_[1] eq 'w') {
    %_attrs = @_[2..$#_];
    $wid = $_attrs{'xml:id'};
    push(@wids,$wid);
    $wid2sid->{$wid} = $sid;
    foreach (grep {defined($_) && $_ ne ''} split(/ /,$_attrs{'c'})) {
      $cid2wid->{$_} = $wid;
    }
  }
}

##======================================================================
## Subs: .char.xml stuff

##--------------------------------------------------------------
## XML::Parser handlers: cxml2w (.char.xml -> .cw.xml)

our ($cwxmlbuf);
our ($total_depth,$text_depth);
our ($cid);
our %wid2nsegs = qw();

## undef = cb_init($expat)
sub cxml2w_cb_init {
  #($_xp) = @_;
  $cwxmlbuf = '';
  $wid = '';
  $total_depth = $text_depth = 0;
}

## undef = cb_xmldecl($xp, $version, $encoding, $standalone)
sub cxml2w_cb_xmldecl {
  cxml_cb_catchall(@_);
  $cwxmlbuf .= "\n<!-- File created by $prog -->\n";
}

## undef = cb_start($expat, $elt,%attrs)
sub cxml2w_cb_start {
  #($_xp,$_elt,%_attrs) = @_;
  ++$total_depth;
  if ($_[1] eq 'c') {
    %_attrs = @_[2..$#_];
    $cid = $_attrs{'xml:id'};
    ## ??
  }
  elsif ($_[1] eq 'text') {
    ++$text_depth;
  }
}

## undef = cb_end($expat, $elt)
sub cxml2w_cb_end {
  #($_xp,$_elt) = @_;
  --$total_depth;
}

## undef = cb_char($expat,$string)
#*cxml2w_cb_char = \&cxml_cb_catchall;

## undef = cb_catchall($expat, ...)
##  + prints original document input string
sub cxml2w_cb_catchall {
  $cwxmlbuf .= $_[0]->original_string;
}

## undef = cb_default($expat, $str)
*cxml2w_cb_default = \&cxml2w_cb_catchall;




##======================================================================
## MAIN

##-- initialize XML::Parser (for .t.xml file)
$xp_txml = XML::Parser->new(
			    ErrorContext => 1,
			    ProtocolEncoding => 'UTF-8',
			    #ParseParamEnt => '???',
			    Handlers => {
					 #Init  => \&cb_init,
					 #Char  => \&cb_char,
					 Start => \&txml_cb_start,
					 #End   => \&cb_end,
					 #Default => \&cb_default,
					 #Final => \&cb_final,
					},
			   )
  or die("$prog: couldn't create XML::Parser for .t.xml file");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
our $outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- load .t.xml records: @wids, %cid2wid, %wid2sid
$xp_txml->parsefile($txmlfile);
print STDERR "$prog: loaded ", scalar(@wids), " token records from '$txmlfile'\n";

##-- load .char.xml buffer
our $cxmlbuf = '';
bufferCharXmlFile($cxmlfile,\$cxmlbuf);
print STDERR "$prog: buffered ", length($cxmlbuf), " XML bytes from '$cxmlfile'\n";

##-- splice in <w> elements for tokens
$xp_cxml2w = XML::Parser->new(
			      ErrorContext => 1,
			      ProtocolEncoding => 'UTF-8',
			      #ParseParamEnt => '???',
			      Handlers => {

					   Init   => \&cxml2w_cb_init,
					   XmlDecl => \&cxml2w_cb_xmldecl,
					   #Char  => \&cxml2w_cb_char,
					   Start  => \&cxml2w_cb_start,
					   End    => \&cxml2w_cb_end,
					   Default => \&cxml2w_cb_default,
					   #Final   => \&cxml2w_cb_final,
					  },
			     )
  or die("$prog: couldn't create XML::Parser for .char.xml->.cw.xml conversion");

$xp_xml2w->parse($cxmlbuf);
print STDERR "$prog: ???\n";



__END__

=pod

=head1 NAME

dtatw-txml2master.perl - splice tokenizer output into original .char.xml files

=head1 SYNOPSIS

 dtatw-txml2master.perl [OPTIONS] T_XML_FILE CHAR_XML_FILE

 General Options:
  -help                  # this help message

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

L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
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
