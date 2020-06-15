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

PRG_NAME := ass3
SRCS     := $(wildcard $(SRC_DIR)/*.s)
OBJECTS  := $(subst .s,.o,$(subst $(SRC_DIR)/,$(OBJ_DIR)/,$(SRCS)))

all: $(PRG_NAME)

test_c: 
	$(foreach file,$(SRCS),\
		$(ASM) $(ASM_FLAGS) -DTEST_C $(file) -o\
		$(subst .s,.o,$(subst $(SRC_DIR)/,$(OBJ_DIR)/,$(file)))\
		-l $(subst .s,.lst,$(subst $(SRC_DIR)/,$(LIST_DIR)/,$(file)))\
		;\
	)
	$(CC) $(CC_FLAGS) -c $(TEST_DIR)/test.c -o $(TEST_DIR)/test.o
	$(CC) $(CC_FLAGS) $(TEST_DIR)/test.o $(OBJECTS) -o $(TEST_DIR)/test

$(PRG_NAME): $(OBJECTS)
	$(CC) -o $(BIN_DIR)/$(PRG_NAME) $(CC_FLAGS) $(OBJECTS)

# .c/.s compile rulesint
$(OBJ_DIR)/%.o: $(SRC_DIR)/%.c
	$(CC) -c $(CC_FLAGS) $< -o $@

$(OBJ_DIR)/%.o: $(SRC_DIR)/%.s
	$(ASM) $(ASM_FLAGS) $< -o $@ -l $(subst .o,.lst,$(subst $(OBJ_DIR),$(LIST_DIR),$@))

clean:
	rm -f $(BIN_DIR)/$(PRG_NAME)\
		  $(BIN_DIR)/*.bin\
		  $(OBJ_DIR)/*.o\
		  $(LIST_DIR)/*.lst\
		  test/test test/*.o test/*.lst
