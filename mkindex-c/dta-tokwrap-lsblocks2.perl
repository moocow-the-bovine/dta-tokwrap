#!/usr/bin/perl -w

use IO::File;
use XML::Parser;
use Getopt::Long qw(:config no_ignore_case);
use Encode qw(encode decode);
use File::Basename qw(basename);
#use Time::HiRes qw(gettimeofday tv_interval);
use Pod::Usage;

##======================================================================
## Globals

##-- event type identifier for BLOCK events
our $BLOCK_ID = '$BLOCK$';

##-- $rootObj: stack object for ROOT pseudo-element
## + each XML element corresponds to one element on the stack
## + stack object structure:
##   {
##    key    => $blockKey,
##    elt    => $eltName,
##    attrs  => \%eltAttrs,
##    blocks => [ \%eltBlock1, ... \%eltBlockN ],
##   }
## + where each \%eltBlock =
##   {
##    xbegin =>$xoff,    ##-- XML byte offset where this block run begins
##    xend   =>$xoff1,   ##-- XML byte offset where this block run ends
##    tbegin =>$toff0,   ##-- text byte offset where this block run begins
##    tend   =>$toff1,   ##-- text byte offset where this block run ends
##   }
our $rootObj =
  {
   key    => '__ROOT__',
   elt    => '__ROOT__',
   attrs  => {},
   blocks => [ { xbegin=>0,xend=>0, tbegin=>0,tend=>0, } ],
  };

##-- $top : current top of the stack
our $top = $rootObj;

##-- @stack: stack of objects mirroring XML element structure
our @stack = ($top);

##-- %key2obj : known objects
our %key2obj = ( $rootObj->{key} => $rootObj );

##-- %lastobj : $objType => $lastOpenEltForType
##  + used for tracking discontinuous segments with '<seg>'
our %lastobj = qw();

##-- $all_implicit_block_elts
##  + if true, new blocks will be created for all elements, unless:
##    - they occur as a daughter of a 'seg' element
##    - or if they occur in %no_implicit_block_elts
our $all_implicit_block_elts = 1;

##-- @implicit_block_elts
## + create new blocks for these elements, unless they occur as a daughter of a 'seg' element
## + overrides @no_implicit_block_elts
our @implicit_block_elts = (
			    ##-- title page stuff
			    qw(titlePage titlePart docTitle byline docAuthor docImprint pubPlace docDate),
			    ##
			    ##-- main text body
			    qw(p div head text front back body),
			    ##
			    ##-- genre-specific: drama
			    qw(speaker sp stage castList castItem role roleDesc set),
			    ##
			    ##-- citations
			    qw(cit q quote),
			    ##
			    ##-- genre-specific: letters
			    qw(salute dateline opener closer signed),
			    ##
			    ##-- tables
			    qw(table row cell),
			    ##
			    ##-- lists
			    qw(list item),
			    ##
			    ##-- notes etc
			    qw(note argument),
			    ##
			    ##-- misc
			    qw(figure ref fw),
			   );
our %implicit_block_elts = map {$_=>undef} @implicit_block_elts;


##-- @no_implicit_block_elts
## + do NOT implicitly create new blocks for these elements
#our @no_implicit_block_elts = qw();
our @no_implicit_block_elts = ( qw(lb hi pb g milestone) );
our %no_implicit_block_elts = map {$_=>undef} @no_implicit_block_elts;

##-- prog
our $prog = File::Basename::basename($0);

##======================================================================
## Subs

## $blk = open_block($oldObj, $newKey, $xoff, $toff)
##  + opens a new block logically BEFORE current event ($xoff~$toff)
##  + implicitly closes $oldBlk if defined
##  + returns new block
sub open_block {
  my ($_old,$_key,$_xoff,$_toff) = @_;
  $_xoff = $::xoff if (!defined($_xoff));
  $_toff = $::toff if (!defined($_toff));
  $_key = ".$_xoff" if (!defined($_key));
  close_block($_old,$_xoff,$_toff) if (defined($_old));
  return { key=>$_key, xbegin=>$_xoff,xend=>undef, tbegin=>$_toff,tend=>undef };
}

## $blk = close_block($blk, $xoff, $toff)
##  + closes current $blk logically BEFORE current event ($xoff~$toff)
##  + writes a record for the current block run to STDOUT
sub close_block {
  my ($_blk,$_xoff,$_toff) = @_;
  $_blk = $::blk if (!defined($_blk));
  $_xoff = $::xoff if (!defined($_xoff));
  $_toff = $::toff if (!defined($_xoff));


  my $_xlen = $_xoff-$_blk->{xbegin};
  my $_tlen = $_toff-$_blk->{tbegin};
  #if ($_tlen) {  ##-- only print if block has non-zero text length
    print join("\t", $BLOCK_ID, $_blk->{xbegin},$_xlen, $_blk->{tbegin},$_tlen, $_blk->{key}), "\n";
  #}
  @$_blk{qw(xend tend)} = ($_xoff,$_toff);
  return $_blk;
}

##--------------------------------------------------------------
## XML::Parser handlers

## undef = cb_start($expat, $elt,%attrs)
our ($_xp,$elt,%attrs,$e);
sub cb_start {
  ($_xp,$eltname,%attrs) = @_;

  ##-- update stack(s)
  ($xbegin,$tbegin, $xend,$tend) = split(/ /,$attrs{'dta.tw.at'});
  $obj = { elt=>$eltname, attrs=>{%attrs} };


  ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  if ($eltname eq 'seg') {
    if ( ($attrs{part} && $attrs{part} eq 'I') || !($attrs{part}) )
      {
	##-- start-tag: <seg>: initial
	$blk = open_block($blk, "seg.${xoff}", $xoff, $toff);
	$lastkey{'seg'} = $blk->{key} if ($attrs{part});
	push(@keystack,$blk->{key});
      }
    elsif ( $attrs{part} ) ## ($attrs{part} eq 'M' || $attrs{part} eq 'F')
      {
	##-- start-tag: <seg>: non-initial
	$blk = open_block($blk, $lastkey{'seg'}, $xoff, $toff); ##-- re-open most recent seg[@part="I"]
	push(@keystack,$blk->{key});
      }
  }
  ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  elsif (
	 ($all_implicit_block_elts && !exists($no_implicit_block_elts{$eltname}))
	 ||
	 exists($implicit_block_elts{$eltname})
	) {
    ##-- start-tag: <note> etc.: implicit block
    if ($blk->{key} !~ /^seg\b/) {
      ##-- start-tag: <note> etc.: no parent <seg>: allocate a new block
      $blk = open_block($blk, "${eltname}.${xoff}", $xoff, $toff);
    }
    push(@keystack,$blk->{key});
  }
  ##~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
  else { # ($eltname =~ m/./)
    ##-- start-tag, but no implicit block: just keep current block running
    push(@keystack, $blk->{key});
    #print STDERR "inheriting block '$blk' for <$eltname>\n";
  }
}

## undef = cb_end($expat, $elt)
sub cb_end {
  #($_xp,$elt) = @_;
  $popkey = pop(@keystack);
  $newkey = $keystack[$#keystack];
  if ($popkey ne $newkey) {
    ##-- block switch: re-open the block we popped from the stack
    $blk = open_block($blk, $newkey, $xoff, $toff);
  }
}

##======================================================================
## MAIN

##-- initialize XML::Parser
our ($xoff,$toff) = (0,0);
$xp = XML::Parser->new(
		       ErrorContext => 1,
		       ProtocolEncoding => 'UTF-8',
		       #ParseParamEnt => '???',
		       Handlers => {
				    #Init  => \&cb_init,
				    Start => \&cb_start,
				    End   => \&cb_end,
				    #Char  => \&cb_char,
				    #Final => \&cb_final,
				   },
		      )
  or die("$prog: couldn't create XML::Parser");

##-- initialize: @ARGV
push(@ARGV,'-') if (!@ARGV);

##-- print header
print
  (
   "%% XML block list file generated by $0\n",
   "%% Command-line: $0 ", join(' ', map {"'$_'"} @ARGV), "\n",
   "%%======================================================================\n",
   "%% \$ID\$\t\$XML_OFFSET\$\t\$XML_LENGTH\$\t\$TXT_OFFSET\$\t\$TXT_LEN\$\t\$KEY\$\n",
  );

##-- parse file(s)
$xp->parsefile($ARGV[0]);
