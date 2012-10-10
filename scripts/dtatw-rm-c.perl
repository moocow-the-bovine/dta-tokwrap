#!/usr/bin/perl -w

while (<>) {
  #s|\s+(?=<c\b)||g;		##-- remove all whitespace preceding <c> tags :: BUG: also removes newlines!
  #s|(?<=<c\b)||g;		##-- remove single-spaces before <c> tags
  s|<c> </c>||g;		##-- remove id-less whitespace <c> tags inserted by dtatw-add-c.perl (original whitespace is retained in following text node)

  s|</?c\b[^>]*>||g;		##-- remove all remaining <c> tags (but keep content)
  #s|<lb\b[^\>]*/>|<lb/>|g;	##-- remove <lb> attributes too
  print;
}
