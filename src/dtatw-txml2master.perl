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

## \$str = loadCharXmlFile($filename)
## \$str = loadCharXmlFile($filename,\$str)
sub loadCharXmlFile {
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

our @wids    = qw();  ##-- ($w_id, ...), in .t.xml document order
our %wid2sid = qw();  ##-- ($w_id => $s_id, ...)
our %cid2wid = qw();  ##-- ($c_id => $w_id, ...)

## undef = cb_start($expat, $elt,%attrs)
sub txml_cb_start {
  ($_xp,$_elt,%_attrs) = @_;
  if ($_elt eq 's') {
    $sid = $_attrs{'xml:id'};
  }
  elsif ($_elt eq 'w') {
    return if (!defined($wid = $_attrs{'xml:id'}));  ##-- ignore tokens without an @xml:id
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
## XML::Parser handlers (for .t.xml file)

our ($total_depth,$text_depth);
our ($cid);

## undef = cb_init($expat)
sub cxml_cb_init {
  #($_xp) = @_;
  $wid = $sid = '';
  $total_depth = $text_depth = 0;
}

## undef = cb_xmldecl($xp, $version, $encoding, $standalone)
sub cxml_cb_xmldecl {
  cxml_cb_catchall(@_);
  $outfh->print("\n<!-- File created by $prog -->\n");
}

## undef = cb_start($expat, $elt,%attrs)
sub cxml_cb_start {
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
sub cxml_cb_end {
  #($_xp,$_elt) = @_;
  --$total_depth;
}

## undef = cb_char($expat,$string)
#*cxml_cb_char = \&cxml_cb_catchall;

## undef = cb_catchall($expat, ...)
##  + catch-all; just prints original document input string
sub cxml_cb_catchall {
  $outfh->print($_[0]->original_string);
}

## undef = cb_default($expat, $str)
*cxml_cb_default = \&cxml_cb_catchall;




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
loadCharXmlFile($cxmlfile,\$cxmlbuf);
print STDERR "$prog: buffered ", length($cxmlbuf), " XML bytes from '$cxmlfile'\n";

##-- splice in sentences & tokens: directly during parse of .chr.xml file
$xp_cxml = XML::Parser->new(
			    ErrorContext => 1,
			    ProtocolEncoding => 'UTF-8',
			    #ParseParamEnt => '???',
			    Handlers => {
					 Init   => \&cxml_cb_init,
					 XmlDecl => \&cxml_cb_xmldecl,
					 #Char  => \&cxml_cb_char,
					 Start  => \&cxml_cb_start,
					 End    => \&cxml_cb_end,
					 Default => \&cxml_cb_default,
					 #Final   => \&cxml_cb_final,
					},
			   )
  or die("$prog: couldn't create XML::Parser for .char.xml file");



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
