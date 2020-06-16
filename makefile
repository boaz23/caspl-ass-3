CC          := gcc
CC_FLAGS    := -Wall -m32 -g
ASM         := nasm
ASM_FLAGS   := -f elf -w+all
LINK        := ld
LINK_FLAGS  := -g -m elf_i386

SRC_DIR         := .
OBJ_DIR         := bin
LIST_DIR        := bin
BIN_DIR         := bin
TEST_DIR        := test

PRG_NAME     := ass3
SRCS_ASM     := $(wildcard $(SRC_DIR)/*.s)
SRCS_C       := $(wildcard $(SRC_DIR)/*.c)
OBJECTS      := $(subst .c,.o,$(subst $(SRC_DIR)/,$(OBJ_DIR)/,$(SRCS_C))) $(subst .s,.o,$(subst $(SRC_DIR)/,$(OBJ_DIR)/,$(SRCS_ASM)))
TEST_SRCS    := $(wildcard $(TEST_DIR)/*.c)
TEST_OBJECTS := $(subst $(OBJ_DIR)/,$(TEST_DIR)/,$(OBJECTS)) $(subst .c,.o,$(TEST_SRCS))

all: $(PRG_NAME)

$(PRG_NAME): $(OBJECTS)
	$(CC) -o $(BIN_DIR)/$(PRG_NAME) $(CC_FLAGS) $(OBJECTS)

# .c/.s compile rulesint
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) -c $(CC_FLAGS) $< -o $@
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.s
	$(ASM) $(ASM_FLAGS) $< -o $@ -l $(subst .o,.lst,$(subst $(OBJ_DIR),$(LIST_DIR),$@))

test: $(TEST_OBJECTS)
	$(CC) -o $(TEST_DIR)/test $(CC_FLAGS) $(TEST_OBJECTS)

$(TEST_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) -c $(CC_FLAGS) $< -o $@
$(TEST_DIR)/%.o: $(TEST_DIR)/%.c
	$(CC) -c $(CC_FLAGS) $< -o $@
$(TEST_DIR)/%.o: $(SRC_DIR)/%.s
	$(ASM) $(ASM_FLAGS) -DTEST_C $< -o $@ -l $(subst .o,.lst,$@)

clean:
	rm -f $(BIN_DIR)/$(PRG_NAME)\
		  $(BIN_DIR)/*.bin\
		  $(OBJ_DIR)/*.o\
		  $(LIST_DIR)/*.lst\
		  $(TEST_DIR)/test\
		  $(TEST_DIR)/*.o\
		  $(TEST_DIR)/*.lst
