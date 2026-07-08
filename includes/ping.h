#ifndef PING_H
#define PING_H

#include <arpa/inet.h>
#include <errno.h>
#include <netdb.h>
#include <netinet/in.h>
#include <netinet/ip.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#ifndef ICMP_ECHO
#define ICMP_ECHO 8
#endif

#ifndef ICMP_ECHOREPLY
#define ICMP_ECHOREPLY 0
#endif

#define TOO_FEW_ARGS 1
#define TOO_MANY_ARGS 3
#define UNKNOWN_FLAG 2

typedef struct s_flags {
  uint8_t verbose : 1;
  uint8_t help : 1;
} t_flags;

typedef struct s_icmphd {
  uint8_t type;
  uint8_t code;
  uint16_t checksum;
  uint16_t id;
  uint16_t seq;
} t_icmphd;

typedef struct s_packet {
  struct s_icmphd hdr;
  uint8_t payload[56]; // timeval + padding
} t_packet;

#endif
