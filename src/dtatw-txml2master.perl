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
	  }) if (@ARGV < 3);

##-- command-line: arguments
our ($txmlfile, $cxmlfile, $cxfile) = @ARGV;

##======================================================================
## Subs: .cx data

## \%id2pos = loadCxData($cxfilename)
##   + s.t. ($xoff,$xlen) = split(/ /,$id2pos{$c_id})
sub loadCxData {
  my $cxfile = shift;
  open(CXDATA,"<$cxfile") or die("$prog: open failed for .cx file '$cxfile': $!");
  my $id2pos = {};
  my ($id,$xoff,$xlen,$rest, $cx);
  while (<CXDATA>) {
    chomp;
    next if (m/^%%/ || m/^\s*$/);
    ($id,$xoff,$xlen,$rest) = split(/\t/,$_,4);
    next if ($id eq '-' || $id =~ m/^\$/); ##-- ignore pseudo-records
    $id2pos->{$id} = "$xoff $xlen";
  }
  close(CXDATA);
  return $id2pos;
}

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
## Subs: XML::Parser

##--------------------------------------------------------------
## XML::Parser handlers (for .t.xml file)

## undef = cb_start($expat, $elt,%attrs)
our ($_xp, $_elt, %_attrs);
our ($s_id, $w_id);
our $wdata = {}; ##-- ($s_id,@c_ids) = split(/ /,$wdata->{$wid})
sub cb_start {
  ($_xp,$_elt,%_attrs) = @_;
  if ($_elt eq 's') {
    $s_id = $_attrs{'xml:id'};
  }
  elsif ($_elt eq 'w') {
    return if (!defined($w_id = $_attrs{'xml:id'}));
    $wdata->{$w_id} = ($s_id||'').' '.$_attrs{'c'};
  }
}

##======================================================================
## MAIN

##-- initialize XML::Parser (for .t.xml file)
$xp = XML::Parser->new(
		       ErrorContext => 1,
		       ProtocolEncoding => 'UTF-8',
		       #ParseParamEnt => '???',
		       Handlers => {
				    #Init  => \&cb_init,
				    #Char  => \&cb_char,
				    Start => \&cb_start,
				    #End   => \&cb_end,
				    #Default => \&cb_default,
				    #Final => \&cb_final,
				   },
		      )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- initialize output file(s)
$outfile = '-' if (!defined($outfile));
our $outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");

##-- load .t.xml records
$xp->parsefile($txmlfile);
print STDERR "$prog: loaded ", scalar(keys(%$wdata)), " token records from '$txmlfile'\n";

##-- load .char.xml buffer
our $cxmlbuf = '';
loadCharXmlFile($cxmlfile,\$cxmlbuf);
print STDERR "$prog: buffered ", length($cxmlbuf), " XML bytes from '$cxmlfile'\n";

##-- load .cx records
our $cid2pos = loadCxData($cxfile)
  or die("$prog: loadCxData($cxfile) failed: $!");
print STDERR "$prog: loaded ", scalar(keys(%$cid2pos)), " .cx records from '$cxfile'\n";

##-- splice in tokens
foreach 

=pod

=head1 NAME

dtatw-txml2master.perl - splice tokenizer output into original .char.xml files

=head1 SYNOPSIS

 dtatw-txml2master.perl [OPTIONS] T_XML_FILE CHAR_XML_FILE CXFILE

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
