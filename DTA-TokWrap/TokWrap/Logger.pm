## -*- Mode: CPerl -*-
##
## File: DTA::TokWrap::Logger.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Description: DTA::Tokwrap logging (using Log::Log4perl)

package DTA::TokWrap::Logger;
use Carp;
use Log::Log4perl;
use File::Basename;
use strict;

##==============================================================================
## Globals
##==============================================================================

## $DEFAULT_LOG_CONF
##  + default configuration for Log::Log4perl
##  + see Log::Log4perl(3pm), Log::Log4perl::Config(3pm) for details
BEGIN {
  our $L4P_CONF_DEFAULT = qq{
##-- Loggers
log4perl.oneMessagePerAppender = 1     ##-- suppress duplicate messages to the same appender
log4perl.rootLogger     = WARN, AppStderr
log4perl.logger.DTA.TokWrap = TRACE, AppStderr

##-- Appenders: Utilities
log4perl.PatternLayout.cspec.G = sub { return File::Basename::basename("$::0"); }

##-- Appender: AppStderr
log4perl.appender.AppStderr = Log::Log4perl::Appender::Screen
log4perl.appender.AppStderr.stderr = 1
log4perl.appender.AppStderr.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.AppStderr.layout.ConversionPattern = %d{yyyy-MM-dd hh:mm:ss} %G[%P] %p: %c: %m%n
  };
}

##==============================================================================
## Functions: Initialization
##==============================================================================

## undef = PACKAGE->logInit()             ##-- use default configuration
## undef = PACKAGE->logInit($file)        ##-- read configuration from a file
## undef = PACKAGE->logInit($file,$watch) ##-- watch configuration file
##  + all log calls in the 'DTA::TokWrap' namespace should use a subcategory of 'DTA::TokWrap'
##  + only needs to be called once; see Log::Log4perl->initialized()
sub logInit {
  my ($that,$file,$watch) = @_;
  if (!defined($file)) {
    our ($L4P_CONF_DEFAULT);
    Log::Log4perl::init(\$L4P_CONF_DEFAULT);
  } elsif (defined($watch)) {
    Log::Log4perl::init_and_watch($file);
  }
  #__PACKAGE__->info("initialized logging facility");
}

## undef = PACKAGE->ensureLog()             ##-- ensure a Log::Log4perl has been initialized
sub ensureLog {
  my $that = shift;
  $that->logInit(@_) if (!Log::Log4perl->initialized);
}

##==============================================================================
## Methods: get logger
##==============================================================================

## $logger = $class_or_obj->logger()
## $logger = $class_or_obj->logger($category)
##  + wrapper for Log::Log4perl::get_logger($category)
##  + $category defaults to ref($class_or_obj)||$class_or_obj
sub logger { Log::Log4perl::get_logger(ref($_[0])||$_[0]); }

##==============================================================================
## Methods: messages
##==============================================================================

## undef = $class_or_obj->trace(@msg)
##   + be sure you have called Log::Log4perl::init() or similar first
##     - e.g. DTA::TokWrap::Logger::logInit()
sub trace { $_[0]->logger->trace(@_[1..$#_]); }
sub debug { $_[0]->logger->debug(@_[1..$#_]); }
sub info  { $_[0]->logger->info(@_[1..$#_]); }
sub warn  { $_[0]->logger->warn(@_[1..$#_]); }
sub error { $_[0]->logger->error(@_[1..$#_]); }
sub fatal { $_[0]->logger->fatal(@_[1..$#_]); }

## undef = $class_or_obj->vlog($level, @msg)
##  + $level is some constant exported by Log::Log4perl::Level
sub vlog { $_[0]->logger->log(@_[1..$#_]); }

##==============================================================================
## Methods: carp & friends
##==============================================================================

## undef = $class_or_obj->logcroak(@msg)
sub logwarn { $_[0]->logger->logwarn(@_[1..$#_]); }     # warn w/o stack trace
sub logcarp { $_[0]->logger->logcarp(@_[1..$#_]); }     # warn w/ 1-level stack trace
sub logcluck { $_[0]->logger->logcluck(@_[1..$#_]); }   # warn w/ full stack trace

sub logdie { $_[0]->logger->logdie(@_[1..$#_]); }         # die w/o stack trace
sub logcroak { $_[0]->logger->logcroak(@_[1..$#_]); }     # die w/ 1-level stack trace
sub logconfess { $_[0]->logger->logconfess(@_[1..$#_]); } # die w/ full stack trace

1; ##-- be happy

__END__
