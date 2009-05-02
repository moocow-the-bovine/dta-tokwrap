#!/usr/bin/perl -w

use Pod::Select;

##-- options
our $tmpfile = 'selected.pod';

#our $toc_item = "=item "; ##-- item w/ =over 4
our $toc_item = "=item *\n\n"; ##-- bullet item w/ =over 4
#our $toc_item = "=head2 "; ##-- header.2
#our $toc_item = "=head3 "; ##-- header.3
#our $toc_item = "=head4 "; ##-- header.4

#our $tok_name_descr_sep = "\n\n"; ##-- name/description separator
our $tok_name_descr_sep = " - "; ##-- name/description separator

our $prepend_link_name = ""; ##-- text to prepend to link names (e.g. "::")

our $NAME = "toc - table of contents for perl module DTA::TokWrap";
our $FOOTER = '
##======================================================================
## Footer
##======================================================================

=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=cut

';

##-- parse
@pods = qw();
foreach $f (map {glob($_)} @ARGV) {
  podselect({-output=>$tmpfile,-sections=>["NAME"]}, $f);
  {
    open(TMP,"<$tmpfile");
    local $/=undef;
    $tmp = <TMP>;
    close(TMP);
    unlink($tmpfile);
  }
  $tmp =~ s/^=.*$//mg;
  $tmp =~ s/\n/ /sg;
  $tmp =~ s/^\s+//;
  $tmp =~ s/\s+$//;
  push(@pods,$tmp);

  ##-- debug
  #print "$f: ", $tmp, "\n";
}

##-- output
print
  (qq{##-- index file auto-generated by $0: do not edit!
=pod

=head1 NAME

$NAME

=head1 CONTENTS

}
   .($toc_item =~ m/=item/ ? "=over 4\n\n" : '')
   .join('',
	 map {
	   ($name,$descr) = split(/\s+/,$_,2);
	   $descr =~ s/^[\s\:\-]*//;
	   "${toc_item}L<${name}|${prepend_link_name}${name}>${tok_name_descr_sep}${descr}\n\n"
	 } sort(@pods))
   ."\n\n"
   .($toc_item =~ m/=item/ ? "=back\n\n" : '')
   .qq{
=cut

}
   .$FOOTER
  );




