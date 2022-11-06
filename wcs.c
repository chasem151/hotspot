/* "wc-stream": wc with incremental output to display file deletion/creation progress. 
 * Akin to dd_rescue's line positioning with 'optimal 
 * positioning' i.e. vt100 positioning.
 *
 * (c) Chase Maivald <chase1@bu.edu> 20***REMOVED***. Distributed under The GNU public license.
 *
 * Compile into an executable via "cc -O3 -o wcs wcs.c"
 * Execute ./wcs via something like: cat /dev/zero | ./wcs > <target device> (erases drive thoroughly)
 * Deviations in per-core clocks may show negative time for short file transfers );)
 */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>

const char* up = "\x1b[A"; //] 
const char* down = "\n";
const char* right = "\x1b[C"; //]

char * usage() {
  return("\n"
"  Running count and speed statistics about a file transfer\n"
"  Reads stdin and stderr. Does cursor positioning, which\n" 
"  should work on most shells (vt100 or later).\n"
"\n"
"  stdin piped (copied via | ) into stdout, much like tee.\n" 
" The best usage is by piping just like ls | wc -l,\n"
" except this is for dynamic (live) readings of a transfer of data\n"
" instead of a static file count like in the example above.\n"
"\n\n");
}


void printverbose(long long l) {
      if (l < 1000000L) 
        fprintf(stderr, "%7.3f kB", l/1000.0);
      else if (l < 1000000000) 
        fprintf(stderr, "%7.3f MB", l/1000000.0);
      else if (l < 1000000000000LL) 
        fprintf(stderr, "%7.3f GB", l/1000000000.0);
      else 
        fprintf(stderr, "%7.3f TB", l/1000000000000.0);
}  



int main(int argc, char ** argv) {
  char buf[BUFSIZ];
  long long cnt = 0;
  time_t to, tn, ts, dt;
  int read_count;
  double rate;

  if (argc > 1) {
    fprintf(stderr, "%s", usage());
    exit(1);
  }

  to = time(NULL);
  ts = to;
  fprintf(stderr, "%s", down);

  while (1) {
    read_count = read (0, buf, sizeof(buf));
    if (read_count < 0 && errno == EINTR)  continue; // pass
    if (read_count < 0) {
      perror("Abnormal use case read from stdin:");
      exit(1);
    }

    if (read_count > 0) {
      cnt += read_count;
      if (fwrite (buf, 1, read_count, stdout) != read_count) {
        perror("Error for wcs writing to stdout console:");  
        exit(1);
      }
    }

    tn = time(NULL);
    if (tn != to || read_count == 0) {
      to = tn;
      fprintf(stderr, "%s read: ", up);
      printverbose(cnt);
      fprintf(stderr, " [ %12lld B]    avg: ", cnt);
        
      // Calculate speed of live file transfer/deletion
      dt = tn - ts;
      if (dt <= 0) dt = 1; // There is some variance in per-core times which cause the speed to oscillate.
      rate = cnt / (double)dt;
      printverbose((long long) rate);
      fprintf(stderr, "/sec [ %5d sec]%s", (int)dt, down);
    }
    if (read_count == 0)  break; // Success!
  }
  fprintf(stderr, "\n");
  return(0);
}
    
