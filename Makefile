RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
RESET = \033[0m

CC = clang
CFLAGS = -Wall -Wextra -Werror -std=c11
INC = -I./includes

NAME = ping

SRC_DIR = src
OBJ_DIR = obj

SRC_FILES = $(wildcard $(SRC_DIR)/*.c) $(wildcard $(SRC_DIR)/ft_fprintf/*.c)
OBJ_FILES = $(patsubst $(SRC_DIR)/%.c, $(OBJ_DIR)/%.o, $(SRC_FILES))

INC_DIRS = $(INC)


all: $(NAME)

$(NAME): $(OBJ_FILES)
	@$(CC) $(CFLAGS) -o $(NAME) $(OBJ_FILES)
	@printf "$(GREEN)$(NAME) built\n$(RESET)"

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) $(INC_DIRS) -c $< -o $@
	@printf "$(YELLOW)Compiling $<$(RESET)\n"

clangd: clean
	@which bear >/dev/null 2>&1 || { printf "$(RED)Error: bear not installed.$(RESET)"; exit 1; }
	@mkdir -p $(OBJ_DIR)
	@printf "$(GREEN)Generating compile_commands.json with bear...$(RESET)\n"
	@bear -- $(MAKE) all
	@printf "$(GREEN)Done. compile_commands.json ready for clangd.$(RESET)"

clean:
	@echo -e "$(RED)Cleaning object files...$(RESET)"
	@rm -rf $(OBJ_DIR)
	@echo -e "$(RED)✓ Object files cleaned!$(RESET)"

fclean: clean
	@rm -r $(NAME)
	@printf "$(RED)Binary file deleted$(RESET)"

re: clean all

test: $(NAME)
	@./tests/test_parsing.sh

.PHONY: all clean fclean re test 
