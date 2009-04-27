#!/usr/bin/perl -w

use lib ('.');
use DTA::TokWrap;
use DTA::TokWrap::Utils qw(:si);
use File::Basename qw(basename);
use IO::File;

use Getopt::Long (':config' => 'no_ignore_case');
use Pod::Usage;

##------------------------------------------------------------------------------
## Constants & Globals
##------------------------------------------------------------------------------

##-- general
our $prog = basename($0);
our ($help);
our $verbose = 1;      ##-- verbosity

##-- DTA::TokWrap options
my %bx0opts = DTA::TokWrap::Processor::mkbx0->defaults();
our %twopts = (
	       inplacePrograms=>1,
	       keeptmp => 1,
	       procOpts => {
			    #traceLevel => 'trace',
			    hint_sb_xpaths => $bx0opts{hint_sb_xpaths},
			    hint_wb_xpaths => $bx0opts{hint_wb_xpaths},
			   },
	      );
our %docopts = (
		##-- Document class options
		class => 'DTA::TokWrap::Document',
		#class => 'DTA::TokWrap::Document::Maker',

		##-- DTA::TokWrap::Document options
		#traceOpen => 'trace',
		#traceClose => 'trace',
		#traceLoad   => 'trace',
		#traceSave   => 'trace',
		format => 1,

		##-- DTA::TokWrap::Document::Maker options
		#traceMake => 'trace',
		#traceGen  => 'trace',
		#genDummy => 0,
		#force => 0,  ##-- propagated from DTA::TokWrap $doc->{tw}
	       );

##-- Logging options
our $logConfFile = undef;
our ($logConf);            ##-- default log configuration string; see below
our $logToStderr = 1;      ##-- log to stderr?
our $logFile     = undef;  ##-- log to file?
our $logProfile  = 'info'; ##-- log-level for profiling information?

##-- make/generate options
our $makeKeyAct = 'make';   ##-- one of 'make', 'gen'
our @targets = qw();
our @defaultTargets = qw(all);

##-- debugging options
our $dump_xsl_prefix = undef;
our $traceLevel = 'trace'; ##-- trace level for '-trace' options
our @traceOptions = (
		     {opt=>'traceOpen',ref=>\$docopts{traceOpen},default=>1},
		     {opt=>'traceClose',ref=>\$docopts{traceClose},default=>0},
		     {opt=>'traceLoad',ref=>\$docopts{traceLoad},default=>1},
		     {opt=>'traceSave',ref=>\$docopts{traceSave},default=>1},
		     {opt=>'traceMake',ref=>\$docopts{traceMake},default=>1},
		     {opt=>'traceGen',ref=>\$docopts{traceGen},default=>0},
		     {opt=>'traceProc',ref=>\$twopts{procOpts}{traceLevel},default=>1},
		     {opt=>'traceRun', ref=>\$DTA::TokWrap::Utils::TRACE_RUNCMD,default=>0},
		    );

##------------------------------------------------------------------------------
## Command-line
##------------------------------------------------------------------------------
GetOptions(
	   ##-- General
	   'help|h' => \$help,
	   'verbose|V=i' => \$verbose,

	   ##-- document class
	   'class|c=s' => \$docopts{class},

	   ##-- pseudo-make
	   'make|m' => sub { $docopts{class}='DTA::TokWrap::Document::Maker'; $makeKeyAct='make'; },
	   'nomake|M' => sub { $docopts{class}='DTA::TokWrap::Document'; },
	   'remake|r!' => sub { $docopts{class}='DTA::TokWrap::Document::Maker'; $makeKeyAct='remake'; },
	   'targets|target|t=s' => \@targets,
	   'force-target|ft=s' => sub { push(@{$twopts{force}},$_[1]) },
	   'force|f' => sub { push(@{$twopts{force}},'all') },
	   'noforce|nof' => sub { $twopts{force} = [] },

	   ##-- DTA::TokWrap::Processor options
	   'inplacePrograms|inplace|i!' => \$twopts{inplacePrograms},
	   'processor-option|procopt|po=s%' => $twopts{procOpts},
	   'sentence-break-xpath|sbx|sb=s@' => $twopts{procOpts}{hint_sb_xpaths},
	   'word-break-xpath|wbx|wb=s@' => $twopts{procOpts}{hint_wb_xpaths},

	   ##-- DTA::TokWrap options: I/O
	   'outdir|od|d=s' => \$twopts{outdir},
	   'tmpdir|tmp|T=s' => \$twopts{tmpdir},
	   'keeptmp|keep|k!' => \$twopts{keeptmp},
	   'format-xml|format|fmt|pretty-xml|pretty|fx|px:i'  => sub { $docopts{format} = $_[1]||1; },
	   'noformat-xml|noformat|nofmt|nopretty-xml|nopretty|nofx|nopx'  => sub { $docopts{format} = 0; },

	   ##-- Log options
	   'log-config|logconfig|logconf|log-rc|logrc|lc=s' => \$logConfFile,
	   'log-level|loglevel|ll=s' => \$DTA::TokWrap::Logger::DEFAULT_LOGLEVEL,
	   'log-file|logfile|lf=s' => \$logFile,
	   'log-stderr|le!' => \$logToStderr,
	   'log-profile|profile|p!' => sub { $logProfile=$_[1] ? 'info' : undef; },
	   'silent|quiet|q' => sub { $DTA::TokWrap::Logger::DEFAULT_LOGLEVEL='FATAL'; },

	   ##-- Debugging options
	   (map {
	     my ($opt,$ref) = @$_{qw(opt ref)};
	     ("${opt}" => sub { $$ref = $traceLevel },
	      "${opt}Level|${opt}-level=s" => sub { $$ref = $_[1] },
	      (map { ("no$_" => sub { $$ref=undef }) } split(/\|/, $opt))
	     )
	   } @traceOptions),
	   "traceLevel|trace-level=s" => \$traceLevel,
	   "trace!" => sub { ${$_->{ref}} = $_[1] ? $traceLevel : undef foreach (grep {$_->{default}} @traceOptions) },
	   "traceAll|trace-all!" => sub { ${$_->{ref}} = $_[1] ? $traceLevel : undef foreach (@traceOptions) },
	   "dummy|no-act|n!" => \$docopts{dummy},

	   'dump-xsl-stylesheets|dump-xsl:s' => \$dump_xsl_prefix,
	  );


pod2usage({-exitval=>0, -verbose=>0}) if ($help);
pod2usage({
	   -message => 'No XML source file(s) specified!',
	   -exitval => 1,
	   -verbose => 0,
	  }) if (@ARGV < 1);


##==============================================================================
## Subs
##==============================================================================

##--------------------------------------------------------------
## Subs: Messaging

sub vmsg {
  my ($vlevel,@msg) = @_;
  if ($verbose >= $vlevel) {
    print STDERR @msg;
  }
}

sub vmsg1 {
  vmsg($_[0],"$prog: ", @_[1..$#_], "\n");
}


##--------------------------------------------------------------
## Subs: File processing

## $bool = processFile($argvFile)
##  + process a single file
sub processFile {
  my $f = shift;
  my $rc = 1;
  eval {
    $rc &&= ($doc = $tw->open($f,%docopts));
    foreach $target (@targets) {
      last if (!$rc);
      $rc &&= defined($makeKeySub->($doc,$target));
    }
    $rc &&= $doc->close();
  };
  return $rc;
}


##==============================================================================
## MAIN
##==============================================================================

##-- init logger
if (defined($logConfFile)) {
  DTA::TokWrap->logInit($logConfFile);
} else {
  $logConf ="
##-- Loggers
log4perl.oneMessagePerAppender = 1     ##-- suppress duplicate messages to the same appender
log4perl.rootLogger     = WARN, AppStderr
log4perl.logger.DTA.TokWrap = ". join(', ',
				      '__DTA_TOKWRAP_DEFAULT_LOGLEVEL__',
				      ($logToStderr ? 'AppStderr' : qw()),
				      ($logFile     ? 'AppFile'   : qw()),
				     ) . "

##-- Appenders: Utilities
log4perl.PatternLayout.cspec.G = sub { return '$prog'; }

##-- Appender: AppStderr
log4perl.appender.AppStderr = Log::Log4perl::Appender::Screen
log4perl.appender.AppStderr.stderr = 1
log4perl.appender.AppStderr.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.AppStderr.layout.ConversionPattern = %G[%P] %p: %c: %m%n

##-- Appender: AppFile
log4perl.appender.AppFile = Log::Log4perl::Appender::File
log4perl.appender.AppFile.filename = " . ($logFile || 'dta-tokwrap.log') . "
log4perl.appender.AppFile.layout = Log::Log4perl::Layout::PatternLayout
log4perl.appender.AppFile.layout.ConversionPattern = %d{yyyy-mm-dd hh:mm:ss} %G[%P] %p: %c: %m%n
  ";
  DTA::TokWrap->logInit(\$logConf);
}

##-- defaults: targets
if (!@targets) {
  @targets = @defaultTargets;
} else {
 @targets = map { split(/[\,\;\s]+/,$_) } @targets;
}

##-- create $tw
our $tw = DTA::TokWrap->new(%twopts)
  or die("$prog: could not create DTA::TokWrap object");

##-- debug: dump XSL?
if (defined($dump_xsl_prefix)) {
  $tw->{mkbx0}->dump_hint_stylesheet($dump_xsl_prefix."mkbx0_hint.xsl");
  $tw->{mkbx0}->dump_sort_stylesheet($dump_xsl_prefix."mkbx0_sort.xsl");
  $tw->{standoff}->dump_t2s_stylesheet($dump_xsl_prefix."standoff_t2s.xsl");
  $tw->{standoff}->dump_t2w_stylesheet($dump_xsl_prefix."standoff_t2w.xsl");
  $tw->{standoff}->dump_t2a_stylesheet($dump_xsl_prefix."standoff_t2a.xsl");
  exit(0);
}

##-- options: pseudo-make: make|gen
our $makeKeySub = $docopts{class}->can("${makeKeyAct}Key")
  or die("$prog: no method for $docopts{class}->${makeKeyAct}Key()");

##-- profiling
#our $tv_started = [gettimeofday];

##-- ye olde loope
our ($doc);
our $progrc=0;
our ($filerc,$target);
foreach $f (@ARGV) {
  $filerc = processFile($f);
  if ($@ || !$filerc) {
    vmsg1(0,"error processing XML file '$f': $@");
    ++$progrc;
  }
}

##-- profiling
$tw->logProfile($logProfile) if ($logProfile && $progrc==0);


exit($progrc); ##-- exit status

=pod

=head1 NAME

dta-tokwrap.perl - top-level tokenizer wrapper for DTA XML documents

=head1 SYNOPSIS

 dta-tokwrap.perl [OPTIONS] XMLFILE(s)...

 General Options:
  -help                  # this help message
  -verbose LEVEL         # set verbosity level (trace|debug|info|warn|error|fatal)

 Logging Options:
  -logconf FILE          # use external log4perl configuration file FILE
  -loglevel LEVEL        # set log level (default log configuration only)

 Generation Mode Options:
  -target TARGET         # set generation target(s) (default=all)
  -make                  # recursively (re-)generate stale target dependencies (default)
  -gen                   # generate only specified target(s) (overrides -make)
  -force                 # consider all target dependencies "stale"

 I/O Options:
  -outdir OUTDIR         # output directory for non-"temporary" files (default=.)
  -tmpdir TMPDIR         # output directory for "temporary" files (default=$DTATW_TMP||$TMP|$OUTDIR)
  -keep , -nokeep        # don't/do delete temporary files (default=do (-nokeep))

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

Not yet written.

=cut

##------------------------------------------------------------------------------
## See Also
##------------------------------------------------------------------------------
=pod

=head1 SEE ALSO

perl(1),
...

=cut

##------------------------------------------------------------------------------
## Footer
##------------------------------------------------------------------------------
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut

