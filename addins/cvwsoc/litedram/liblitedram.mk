###include ../include/generated/variables.mak
###include $(SOC_DIRECTORY)/software/common.mak

AS=riscv64-unknown-elf-as
CC=riscv64-unknown-elf-gcc
AR=riscv64-unknown-elf-ar


CUR_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
INC_DIRS ?= $(CUR_DIR)/genesys2soc $(CUR_DIR)/genesys2soc/include $(LIBLITEDRAM_DIRECTORY)/../include $(LIBLITEDRAM_DIRECTORY)/.. 
INC+=${INC_DIRS:%=-I%}

#OBJECTS = sdram.o bist.o sdram_dbg.o sdram_spd.o utils.o accessors.o
OBJECTS = sdram.o accessors.o

all: liblitedram.a

liblitedram.a: $(OBJECTS)
	$(AR) crs liblitedram.a $(OBJECTS)

# pull in dependency info for *existing* .o files
-include $(OBJECTS:.o=.d)

%.o: $(LIBLITEDRAM_DIRECTORY)/%.c
	echo "compiling $<. INC: $(INC)"
	$(CC) $(CFLAGS) $(INC) -DMAIN_RAM_BASE=$(EXT_MEM_BASE) -DCSR_BASE=$(LITEDRAM_BASE) -DSDRAM_TEST_DISABLE -c -o $@ $<

%.o: %.S
	$(assemble)

.PHONY: all clean

clean:
	$(RM) $(OBJECTS) liblitedram.a .*~ *~
	echo "LIBLITEDRAM_DIRECTORY: $(LIBLITEDRAM_DIRECTORY)"
	echo "LITEDRAM_BASE: $(LITEDRAM_BASE)"
	echo "CC: $(CC)"
