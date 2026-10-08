#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <string.h>
#include <sys/stat.h>
int system(const char *c){ (void)c; errno = ENOSYS; return -1; }
char *mkdtemp(char *t){ size_t n = strlen(t); static unsigned k; for (int i = 0; i < 1000; i++) { unsigned v = ++k + 0u; for (size_t j = n - 6, d = 0; j < n; j++, d++) t[j] = 'a' + ((v >> (d * 3)) & 7); if (mkdir(t, 0700) == 0) return t; } return NULL; }
