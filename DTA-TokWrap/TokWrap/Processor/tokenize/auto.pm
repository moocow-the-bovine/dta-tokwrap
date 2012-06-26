## -*- Mode: CPerl -*-

## File: DTA::TokWrap::Processor::tokenize::auto.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: DTA tokenizer wrappers: auto-resolving tomasotath wrapper

package DTA::TokWrap::Processor::tokenize::auto;

use DTA::TokWrap::Version;
use DTA::TokWrap::Base;
use DTA::TokWrap::Utils qw(:progs :slurp);
use DTA::TokWrap::Processor::tokenize::http;
use DTA::TokWrap::Processor::tokenize::tomasotath_04x;
use DTA::TokWrap::Processor::tokenize::tomasotath_02x;
use DTA::TokWrap::Processor::tokenize::dummy;

use Carp;
use strict;

##==============================================================================
## Constants
##==============================================================================
our @ISA = qw(DTA::TokWrap::Processor::tokenize);

our @DEFAULT_CLASSES = qw(tomasotath_04x tomasotath_02x http dummy);

##==============================================================================
## Constructors etc.
##==============================================================================

## $ta = CLASS_OR_OBJ->new(%args)
##  + %args:
##    classes  => \@class_list,		   ##-- class search list
##    inplace  => $bool,                   ##-- prefer in-place programs for search?
##    tokz     => $tokz,		   ##-- underlying tokenizer object (subclass of DTA::TokWrap::Processor::tokenize)

## %defaults = CLASS->defaults()
sub defaults {
  my $that = shift;
  return (
	  $that->SUPER::defaults(), ##-- block inheritance from DTA::TokWrap::Processor::tokenize
	  #$that->DTA::TokWrap::Processor::defaults(),

	  classes=>\@DEFAULT_CLASSES,
	  inplace=>1,
	  tokz   =>undef,
	 );
}

## $ta = $ta->init()
sub init {
  my $ta = shift;
  return $ta if (defined($ta->{tokz}));

  foreach my $class (@{$ta->{classes}}) {
    my %args = qw();
    if ($class =~ /^tomasotath/) {
      next if ( !defined($args{tomata2} = path_prog('dwds_tomasotath', prepend=>($ta->{inplace} ? ['.','../src'] : undef))) );
      my $vstr = `$args{tomata2} --version 2>&1` or next;
      $vstr =~ s/^\S+\s+//;
      chomp($vstr);
      next if ($class =~ /_04x$/ && $vstr !~ /0\.4\./);
      next if ($class =~ /_02x$/ && $vstr !~ /0\.2\./);
    }
    eval { $ta->{tokz} = "DTA::TokWrap::Processor::tokenize::$class"->new(%$ta,%args); };
    last if (!$@ && defined($ta->{tokz}));
    $ta->vlog($ta->{traceLevel},"tokenizer class = $class");
  }

  return $ta;
}

##==============================================================================
## Methods
##==============================================================================

## $doc_or_undef = $CLASS_OR_OBJECT->tokenize($doc)
## + $doc is a DTA::TokWrap::Document object
## + %$doc keys:
##    txtfile => $txtfile,  ##-- (input) serialized text file
##    tokdata => $tokdata,  ##-- (output) tokenizer output data (string)
##    ntoks => $nTokens,    ##-- (output) number of output tokens (regex hack)
##    tokenize_stamp0 => $f, ##-- (output) timestamp of operation begin
##    tokenize_stamp  => $f, ##-- (output) timestamp of operation end
##    tokdata_stamp => $f,   ##-- (output) timestamp of operation end
## + may implicitly call $doc->mkbx() and/or $doc->saveTxtFile()
sub tokenize {
  my ($ta,$doc) = @_;
  return $ta->{tokz}->tokenize($doc);
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl, edited

##========================================================================
## NAME
=pod

=head1 NAME

DTA::TokWrap::Processor::tokenize::auto - DTA tokenizer wrappers: auto tokenizer

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use DTA::TokWrap::Processor::tokenize::auto;
 
 $td = DTA::TokWrap::Processor::tokenize::auto->new(%args);
 $doc_or_undef = $td->tokenize($doc);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

DTA::TokWrap::Processor::tokenize::auto provides a "smart" wrapper
for the low-level tokenizer class
L<DTA::TokWrap::Processor::tokenize|DTA::TokWrap::Processor::tokenize>.

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize::dummy: Constants
=pod

=head2 Constants

=over 4

=item @ISA

DTA::TokWrap::Processor::tokenize::auto
inherits from
L<DTA::TokWrap::Processor::tokenize|DTA::TokWrap::Processor::tokenize>.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize::auto: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item new

 $td = $CLASS_OR_OBJ->new(%args);

Constructor.

%args, %$td:

 tokenize => $path_to_dtatw_tokenize, ##-- default: search
 inplace  => $bool,                   ##-- prefer in-place programs for search?

=item defaults

 %defaults = $CLASS->defaults();

Static class-dependent defaults.

=item init

 $td = $td->init();

Dynamic object-dependent defaults.

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: DTA::TokWrap::Processor::tokenize::auto: Methods
=pod

=head2 Methods

=over 4

=item tokenize

 $doc_or_undef = $CLASS_OR_OBJECT->tokenize($doc);

See L<DTA::TokWrap::Processor::tokenize::tokenize()|DTA::TokWrap::Processor::tokenize/tokenize>.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## See Also
##======================================================================

=pod

=head1 SEE ALSO

L<DTA::TokWrap::Intro(3pm)|DTA::TokWrap::Intro>,
L<dta-tokwrap.perl(1)|dta-tokwrap.perl>,
...

=cut

##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.1 or,
at your option, any later version of Perl 5 you may have available.

=cut
