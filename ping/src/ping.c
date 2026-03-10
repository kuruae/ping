#include "ping.h"
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
  }

  return 0;
}

int main(int argc, char *argv[]) {
  if (argc < 2) {
    fprintf(stderr, "ping: usage error: Destination address required\n");
    return EXIT_FAILURE;
  }

  int flags_err = parse_flags(argc, argv);

  if (flags_err == TOO_FEW_ARGS) {
    fprintf(stderr, "ping: usage error: Destination address required\n");
    return EXIT_FAILURE;
  }

  if (flags_err == UNKNOWN_FLAG) {
    fprintf(stderr, "ping: invalid option -- '%s'\n%s\n", argv[1] + 1,
            string_help);
    return EXIT_FAILURE;
  }

  if (flags.help) {
    printf("%s\n", string_help);
    return EXIT_SUCCESS;
  }

  const char *destination = flags.verbose ? argv[2] : argv[1];

  if (flags.verbose)
    printf("Verbose mode enabled\n");

  printf("Pinging %s...\n", destination);

  return EXIT_SUCCESS;
}
