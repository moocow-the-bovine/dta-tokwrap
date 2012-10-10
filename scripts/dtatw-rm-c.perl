#!/usr/bin/perl -w

while (<>) {
  s|<c> </c>||g;		##-- remove id-less whitespace <c> tags inserted by dtatw-add-c.perl (original whitespace is retained in following text node)
  s|\s*<c\s[^>]*>(.*)</c>\s*|$1|sg; ##-- remove whitespace following OCR <c> tags
  s|</?c\b[^>]*>||g;		##-- remove all remaining <c> tags (but keep content)
  print;
}
