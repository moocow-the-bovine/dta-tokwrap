#include <errno.h>
#include <stdio.h>
#include <string.h>

int main (int argc, char **argv)
{
  int i;
  for (i=1; i < argc; i++) {
    int e = strtol(argv[i],NULL,0);
    printf("%d : %s\n", e, strerror(e));
  }
  return 0;
}
