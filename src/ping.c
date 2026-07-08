#include "ping.h"

t_flags flags = {0};

static const char string_help[] = "Usage\n"
                                  "  ping [options] <destination>\n\n"
                                  "Options:\n"
                                  "  <destination>    DNS name or IP address\n"
                                  "  -v               verbose output\n"
                                  "  -?               print help and exit\n";

int parse_flags(int argc, char **argv) {
  if (argc < 2)
    return TOO_FEW_ARGS;

  if (argv[1][0] == '-') {
    if (strcmp(argv[1], "-v") == 0)
      flags.verbose = true;
    else if (strcmp(argv[1], "-?") == 0)
      flags.help = true;
    else
      return UNKNOWN_FLAG;

    if (!flags.help && argc < 3)
      return TOO_FEW_ARGS;
  } else if (argc > 2) {
    return TOO_MANY_ARGS;
  }

  if (flags.verbose && argc > 3)
    return TOO_MANY_ARGS;

  return 0;
}

int has_parsing_err(int flags_err, char *argv[]) {
  if (flags_err == UNKNOWN_FLAG) {
    fprintf(stderr, "ping: invalid option -- '%s'\n", argv[1] + 1);
    return EXIT_FAILURE;
  } else if (flags_err == TOO_FEW_ARGS) {
    fprintf(stderr, "ping: usage error: Destination address required\n");
    return EXIT_FAILURE;
  } else if (flags_err == TOO_MANY_ARGS)
    return EXIT_FAILURE;

  return 0;
}

uint16_t compute_checksum(const void *buf, int len) {
  const uint16_t *data = buf;
  uint32_t sum = 0;

  while (len >= 4) {
    sum += data[0];
    sum += data[1];
    data += 2;
    len -= 4;
  }

  while (len >= 2) {
    sum += *data++;
    len -= 2;
  }

  if (len == 1) {
    sum += (*(uint8_t *)data) << 8;
  }

  while (sum >> 16)
    sum = (sum & 0xFFFF) + (sum >> 16);

  return ~sum;
}

t_icmphd build_header(uint16_t seq) {
  t_icmphd header = {.type = ICMP_ECHO,
                     .code = 0,
                     .checksum = 0,
                     .id = htons(getpid() & 0xFFFF),
                     .seq = htons(seq)};

  return header;
}

int resolve_address(const char *host, struct sockaddr_in *addr) {
  struct addrinfo hints = {0};
  struct addrinfo *result;

  hints.ai_family = AF_INET; // IPv4 only for now
  hints.ai_socktype = SOCK_RAW;
  hints.ai_protocol = IPPROTO_ICMP;

  int err = getaddrinfo(host, NULL, &hints, &result);
  if (err != 0) {
    fprintf(stderr, "ping: %s: %s\n", host, gai_strerror(err));
    return -1;
  }

  memcpy(addr, result->ai_addr, sizeof(*addr));
  freeaddrinfo(result);
  return 0;
}

void packet_exchange_loop(int sockfd, struct sockaddr_in *dest_addr) {
  int seq = 0;
  uint16_t id = getpid() & 0xFFFF;

  while (1) {
    t_packet packet;
    packet.hdr = build_header(seq);
    gettimeofday((struct timeval *)packet.payload, NULL);
    packet.hdr.checksum = compute_checksum(&packet, sizeof(packet));

    ssize_t sent = sendto(sockfd, &packet, sizeof(packet), 0,
                          (struct sockaddr *)dest_addr, sizeof(*dest_addr));
    if (sent < 0) {
      perror("sendto");
      seq++;
      sleep(1);
      continue;
    }

    // Receive reply
    char recv_buf[84]; // IP header (20) + ICMP packet (64)
    struct sockaddr_in from;
    socklen_t fromlen = sizeof(from);

    ssize_t bytes = recvfrom(sockfd, recv_buf, sizeof(recv_buf), 0,
                             (struct sockaddr *)&from, &fromlen);

    if (bytes < 0) {
      if (errno == EAGAIN || errno == EWOULDBLOCK) {
        printf("Request timeout for icmp_seq %d\n", seq);
      } else {
        perror("recvfrom");
      }
      seq++;
      sleep(1);
      continue;
    }

    // Parse IP header to find ICMP data
    struct ip *ip_hdr = (struct ip *)recv_buf;
    int ip_hdr_len = ip_hdr->ip_hl << 2; // ip_hl is in 4-byte words

    // Get ICMP header from after IP header
    t_icmphd *icmp_reply = (t_icmphd *)(recv_buf + ip_hdr_len);

    // Verify this is our reply
    if (icmp_reply->type == ICMP_ECHOREPLY && ntohs(icmp_reply->id) == id &&
        ntohs(icmp_reply->seq) == seq) {

      // Calculate RTT
      struct timeval now, *sent_time;
      gettimeofday(&now, NULL);
      sent_time = (struct timeval *)(recv_buf + ip_hdr_len + sizeof(t_icmphd));

      double rtt = (now.tv_sec - sent_time->tv_sec) * 1000.0 +
                   (now.tv_usec - sent_time->tv_usec) / 1000.0;

      char from_ip[INET_ADDRSTRLEN];
      inet_ntop(AF_INET, &from.sin_addr, from_ip, sizeof(from_ip));

      printf("%zd bytes from %s: icmp_seq=%d ttl=%d time=%.3f ms\n",
             bytes - ip_hdr_len, from_ip, seq, ip_hdr->ip_ttl, rtt);
    }

    seq++;
    sleep(1);
  }
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "ping: usage error: Destination address required\n");
    return EXIT_FAILURE;
  }

  int flags_err = parse_flags(argc, argv);
  if (has_parsing_err(flags_err, argv) == EXIT_FAILURE || flags.help) {
    printf(string_help);
    return EXIT_FAILURE;
  }

  const char *destination = flags.verbose ? argv[2] : argv[1];

  // Resolve destination address
  struct sockaddr_in dest_addr;
  if (resolve_address(destination, &dest_addr) < 0) {
    return EXIT_FAILURE;
  }

  // Create raw socket once
  int sockfd = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
  if (sockfd < 0) {
    perror("socket");
    return EXIT_FAILURE;
  }

  // Set receive timeout (1 second)
  struct timeval tv = {.tv_sec = 1, .tv_usec = 0};
  if (setsockopt(sockfd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv)) < 0) {
    perror("setsockopt");
    close(sockfd);
    return EXIT_FAILURE;
  }

  // Get resolved IP as string for display
  char ip_str[INET_ADDRSTRLEN];
  inet_ntop(AF_INET, &dest_addr.sin_addr, ip_str, sizeof(ip_str));

  if (flags.verbose)
    printf("Verbose mode enabled\n");

  printf("PING %s (%s): %zu data bytes\n", destination, ip_str,
         sizeof(t_packet) - sizeof(t_icmphd));

  packet_exchange_loop(sockfd, &dest_addr);

  close(sockfd);
  return EXIT_SUCCESS;
}
