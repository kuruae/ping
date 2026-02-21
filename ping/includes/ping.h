#ifndef PING_H
#define PING_H

#include <stdint.h>

#define TOO_FEW_ARGS 1
#define UNKNOWN_FLAG 2

typedef struct s_flags {
  uint8_t verbose : 1;
  uint8_t help : 1;
} t_flags;

#endif
