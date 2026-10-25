BUILD_DIR ?= ../build/tangnano20k
VARS := $(BUILD_DIR)/software/include/generated/variables.mak

.DEFAULT_GOAL := all
.PHONY: all clean

clean:
	rm -f crt0.o main.o kyma_demo.elf kyma_demo.bin kyma_demo.elf.map *.d

ifeq ($(wildcard $(VARS)),)

all:
	$(error Falta el SDK de LiteX. Desde la raiz del repo: make soc)

else

include $(VARS)
include $(SOC_DIRECTORY)/software/common.mak

OBJECTS = crt0.o main.o
GENLD   = $(BUILDINC_DIRECTORY)/generated

all: kyma_demo.bin

%.bin: %.elf
	$(OBJCOPY) -O binary $< $@
	chmod -x $@

kyma_demo.elf: $(OBJECTS) linker.ld
	$(CC) $(LDFLAGS) -T linker.ld -L$(GENLD) -N -o $@ \
		$(OBJECTS) \
		$(PACKAGES:%=-L$(BUILD_DIR)/software/%) \
		-Wl,--start-group \
		$(LIBS:lib%=-l%) \
		-Wl,--end-group \
		-Wl,--gc-sections
	chmod -x $@

crt0.o: $(CPU_DIRECTORY)/crt0.S
	$(CC) -c $(CFLAGS) -o $@ $<

main.o: main.c
	$(CC) -c $(CFLAGS) -o $@ $<

endif
