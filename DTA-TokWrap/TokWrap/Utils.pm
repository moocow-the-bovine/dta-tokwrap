## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Utils.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: generic utilities

package DTA::TokWrap::Utils;
use DTA::TokWrap::Version;
use Env::Path;
use Exporter;
use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(Exporter);

our @EXPORT = qw();
our %EXPORT_TAGS = (
		    progs => [qw(path_prog runcmd)],
		   );
$EXPORT_TAGS{all} = [map {@$_} values(%EXPORT_TAGS)];
our @EXPORT_OK = @{$EXPORT_TAGS{all}};


## $TRACE_RUNCMD
##  + if true, trace messages will be printed to STDERR for runcmd()
our $TRACE_RUNCMD = 1;

##==============================================================================
## Utils: path search (program location)
##==============================================================================

## $progpath_or_undef = PACKAGE::path_prog($progname,%opts)
##  + %opts:
##    prepend => \@paths,  ##-- prepend @paths to Env::Path->PATH->List
##    append  => \@paths,  ##-- append @paths to Env::Path->PATH->List
##    warnsub => \&sub,    ##-- warn subroutine if path not found (undef for no warnings);
sub path_prog {
  my ($prog,%opts) = @_;
  return $prog if ($prog =~ /^[\.\/]/ && -x $prog); ##-- detect fully specified paths
  my @paths = Env::Path->PATH->List;
  unshift(@paths, @{$opts{prepend}}) if ($opts{prepend});
  push   (@paths, @{$opts{append}} ) if ($opts{append});
  foreach (@paths) {
    return "$_/$prog" if (-x "$_/$prog");
  }
  $opts{warnsub}->(__PACKAGE__, "::path_prog(): could not find program '$prog' in path (", join(' ', @paths), ")")
    if ($opts{warnsub});
  return undef;
}

##==============================================================================
## Utils: external programs
##==============================================================================

## $system_rc = PACKAGE::runcmd(@cmd)
sub runcmd {
  my @argv = @_;
  print STDERR __PACKAGE__, "::runcmd(): ", join(' ', map {$_=~/\s/ ? "\"$_\"" : $_} @argv), "\n"
    if ($TRACE_RUNCMD);
  return system(@argv);
}

##==============================================================================
## Utils: Misc
##==============================================================================

1; ##-- be happy

