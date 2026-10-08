#pragma once
/* the compiler runs inside a browser: no processes. -c is all it is asked for. */
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
static inline pid_t fork(void){ return -1; }
static inline FILE *popen(const char *c, const char *m){ (void)c;(void)m; return NULL; }
static inline int pclose(FILE *f){ (void)f; return -1; }
#define execl(...) (-1)
#define execv(a,b) (-1)
