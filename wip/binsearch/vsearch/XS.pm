package Algorithm::BinarySearch::Vec::XS;

use 5.008004;
use strict;
use warnings;
use Carp;
use AutoLoader;
use Exporter;

our @ISA = qw(Exporter);

our $VERSION = '0.01';

require XSLoader;
XSLoader::load('Algorithm::BinarySearch::Vec::XS', $VERSION);

# Preloaded methods go here.
#require Algorithm::BinarySearch::Vec::Whatever;

# Autoload methods go after =cut, and are processed by the autosplit program.

##======================================================================
## Exports
##======================================================================
our (%EXPORT_TAGS, @EXPORT_OK, @EXPORT);
BEGIN {
  %EXPORT_TAGS =
    (
     std   => [qw( vbsearch  vbsearch_lb  vbsearch_ub),
	       qw(vabsearch vabsearch_lb vabsearch_ub),
	      ],
     debug => [qw(vget vset)],
    );
  $EXPORT_TAGS{default} = [@{$EXPORT_TAGS{std}}];
  $EXPORT_TAGS{all}     = [@{$EXPORT_TAGS{std}}, @{$EXPORT_TAGS{debug}}];
  @EXPORT_OK            = @{$EXPORT_TAGS{all}};
  @EXPORT               = @{$EXPORT_TAGS{default}};
}

##======================================================================
## Constants
##======================================================================


##======================================================================
## Exports: finish
##======================================================================


1;

__END__
