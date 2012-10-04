#!/usr/bin/perl -w

my $bufsize=4 * 2^20; ##-- 4MB

push(@ARGV,'-') if (!@ARGV);
foreach my $file (@ARGV) {
  open(IN,"<$file") or die("$0: open failed for '$file': $!");
  while (read(IN,$_,$bufsize)) {
    #s|\s+(?=<c\b)||g;		##-- remove all whitespace preceding <c> tags :: BUG: also removes newlines!
    #s|(?<=<c\b)||g;		##-- remove single-spaces before <c> tags
    s|<c\b[^>]*> </c>||g;		##-- remove whitespace <c> tags inserted by dtatw-add-c.perl (original whitespace is retained in following text node)

    s|</?c\b[^>]*>||g;		##-- remove all <c> tags (and any preceding whitespace)
    s|<lb\b[^\>]*/>|<lb/>|g;	##-- remove <lb> attributes too
    print;
  }
  close(IN);
}
