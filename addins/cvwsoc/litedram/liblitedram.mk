###include ../include/generated/variables.mak
###include $(SOC_DIRECTORY)/software/common.mak

AS=riscv64-unknown-elf-as
CC=riscv64-unknown-elf-gcc
AR=riscv64-unknown-elf-ar

MARCH           ?= -march=rv64imfdc_zifencei
MABI            ?= -mabi=lp64d
override CFLAGS += $(MARCH) $(MABI) -mcmodel=medany -O2 -g -DEXT_MEM_BASE=${EXT_MEM_BASE} -DLITEDRAM_BASE=${LITEDRAM_BASE}

CUR_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
LITEDRAM_CONFIG ?= genesys2soc
INC_DIRS ?= $(CUR_DIR)/$(LITEDRAM_CONFIG) $(CUR_DIR)/$(LITEDRAM_CONFIG)/include $(LIBLITEDRAM_DIRECTORY)/../include $(LIBLITEDRAM_DIRECTORY)/..
INC+=${INC_DIRS:%=-I%}

#OBJECTS = sdram.o bist.o sdram_dbg.o sdram_spd.o utils.o accessors.o
OBJECTS = sdram.o accessors.o

all: liblitedram.a

liblitedram.a: $(OBJECTS)
	echo "LIBLITEDRAM_DIRECTORY: $(LIBLITEDRAM_DIRECTORY)"
	echo "LITEDRAM_BASE: $(LITEDRAM_BASE)"
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
	echo "CC: $(CC)"
