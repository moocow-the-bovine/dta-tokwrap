#!/usr/bin/perl -w

use utf8;

## \$buf = slurp_file($file)
## \$buf = slurp_file($file,\$buf)
sub slurp_file {
  my ($file,$bufr) = @_;
  if (!defined($bufr)) {
    my $buf = '';
    $bufr = \$buf;
  }
  open(SLURP,"<$file") or die("$0: open failed for '$file': $!");
  binmode(SLURP,":utf8");
  local $/=undef;
  $$bufr = <SLURP>;
  close SLURP;
  #$$bufr = Unicruft::utf8_to_latin1_de($$bufr); ##-- normalize via unicruft
  return $bufr;
}

##-- MAIN
binmode(STDOUT,":utf8");
binmode(STDERR,":utf8");
$|=1;
push(@ARGV,'-') if (!@ARGV);
our $data = '';
foreach $file (@ARGV) {
  print STDERR "$file\n";
  slurp_file($file,\$data);

  print STDERR "+ autofix/new: ITJ\n";
  $data =~ s/^(re\t\d+ \d+)\tITJ$/$1/mg;

  print STDERR ("+ autofix: linebreak: suspects\n");
  my @suspects = qw();
  while (
	 $data =~ /
		    [[:alpha:]\'\-\x{ac}]*                        ##-- w1.text [modulo final "-"]
		    [\-\x{ac}]                                    ##--   : w1.final "-"
		    \t.*                                          ##--   : w1.rest
		    \n+                                           ##--   : EOT (EOS?) (w1 . w2)
		    [[:alpha:]\'\-\x{ac}]*                        ##-- w2.text [modulo final "."]
		    \.?                                           ##--   : w2.text: final "." (optional)
		    \t.*                                          ##--   : w2.rest
		    \n                                            ##--   : EOT (w1 w2 .)
		  /mxg
	)
    {
      push(@suspects, [$-[0], $+[0]-$-[0]]);
    }

  ##-- DEBUG
  our %nojoin_txt2 = map {($_=>undef)} qw(und oder als wie noch sondern ſondern);
  if (1) {
    my ($s_str, $txt1,$off1,$len1,$rest1, $txt2,$off2,$len2,$rest2, $repl);
    foreach (reverse @suspects) {
      $s_str = substr($data,$_->[0],$_->[1]);
      $repl  = undef;

      if (
	  $s_str =~ m/^([^\t\n]*)            ##-- $1: w1.txt
		      \t(\d+)\ (\d+)         ##-- ($2,$3): (w1.off, w1.len)
		      ([^\n]*)               ##-- $4: w1.rest
		      \n+                    ##-- w1.EOT (EOS?)
		      ([^\t\n]*)             ##-- $5: w2.txt
		      \t(\d+)\ (\d+)         ##-- ($6,$7): (w2.off, w2.len)
		      ([^\n]*)               ##-- $8: w2.rest
		      \n+$                   ##-- w2.EOT
		     /sx
	 ) {
	($txt1,$off1,$len1,$rest1, $txt2,$off2,$len2,$rest2) = ($1,$2,$3,$4, $5,$6,$7,$8);

	##-- skip vowel-less w1
	next if ($txt1 !~ /[aeiouäöüy]/);

	##-- skip common conjunctions as w2
	next if (exists($nojoin_txt2{$txt2}));

	##-- skip upper-case and vowel-less w2
	next if ($txt2 =~ /[[:upper:]]/ || $txt2 !~ /[aeiouäöüy]/);

	##-- check for abbrevs
	if ($txt2 =~ /\.$/ && $rest2 =~ /\bXY\b/) {
	  $repl = (
		   substr($txt1,0,-1).substr($txt2,0,-1)."\t$off1 ".(($off2+$len2)-$off1-1)."\n"
		   .".\t".($off2+$len2-1)." 1\t\$.\n"
		   ."\n"
		  );
	} elsif ($rest2 =~ /^(?:\tTRUNC)?$/) {
	  $repl = (
		   substr($txt1,0,-1).$txt2."\t$off1 ".(($off2+$len2)-$off1)."$rest2\n"
		  );
	}

	##-- DEBUG
	print STDERR "  - SUSPECT: ($txt1 \@$off1.$len1 :$rest1)  +  ($txt2 \@$off2.$len2 :$rest2)  -->  ".(defined($repl) ? $repl : "IGNORE\n");
      } else {
	warn("$0: couldn't parse suspect line at $file offset $_->[0], length $_->[1] - skipping");
	next;
      }

      ##-- apply actual replacement
      substr($data,$_->[0],$_->[1]) = $repl if (defined($repl));
    }
  }

  ##-- dump
  print $data;
}

# Local Variables:
# coding: utf-8
# End:
