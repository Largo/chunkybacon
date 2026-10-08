#pragma once
#include <sys/types.h>
#define WIFEXITED(s) (1)
#define WEXITSTATUS(s) ((s) & 0xff)
static inline pid_t waitpid(pid_t p, int *s, int o){ (void)p;(void)s;(void)o; return -1; }
