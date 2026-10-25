# Tang Nano 20K — Yosys / nextpnr-himbaechel / gowin_pack / openFPGALoader
# and a LiteX SoC with the VexRiscv softcore.

DEVICE  := GW2AR-LV18QN88C8/I7
FAMILY  := GW2A-18C
FREQ    := 27
BUILD   := build
PORT    ?= /dev/tty.usbserial-20250303171

YOSYS    ?= yosys
NEXTPNR  ?= nextpnr-himbaechel
PACK     ?= gowin_pack
LOADER   ?= openFPGALoader
PYTHON   ?= python3

.PHONY: help doctor blinky load-blinky flash-blinky soc load-soc flash-soc demo term term-demo clean

help:
	@echo "make doctor        comprueba las herramientas"
	@echo "make blinky        sintetiza rtl/blinky.v (Yosys + nextpnr + gowin_pack)"
	@echo "make load-blinky   carga el blinky en SRAM de la FPGA"
	@echo "make flash-blinky  graba el blinky en la SPI flash"
	@echo "make soc           genera el SoC VexRiscv con LiteX y Apicula"
	@echo "make load-soc      carga el bitstream del SoC"
	@echo "make flash-soc     graba el SoC en la SPI flash"
	@echo "make demo          compila firmware/ contra el SDK generado"
	@echo "make term PORT=/dev/cu.usbmodemXXX"
	@echo "make term-demo PORT=/dev/cu.usbmodemXXX"

doctor:
	@for t in $(YOSYS) $(NEXTPNR) $(PACK) $(LOADER) $(PYTHON) litex_term; do \
		if command -v $$t >/dev/null 2>&1; then echo "ok  $$t"; else echo "FALTA  $$t"; fi; \
	done
	@$(YOSYS) -p 'help synth_gowin' 2>/dev/null | grep -q gw2a && echo "ok  synth_gowin -family gw2a" || echo "FALTA  synth_gowin -family gw2a (Yosys reciente)"
	@if command -v riscv64-unknown-elf-gcc >/dev/null || command -v riscv-none-elf-gcc >/dev/null; then \
		echo "ok  toolchain RISC-V"; \
	else \
		echo "FALTA  riscv64-unknown-elf-gcc o riscv-none-elf-gcc"; \
	fi

$(BUILD)/blinky.json: rtl/blinky.v
	mkdir -p $(BUILD)
	$(YOSYS) -p "read_verilog $<; synth_gowin -top blinky -family gw2a -json $@"

$(BUILD)/blinky_routed.json: $(BUILD)/blinky.json constraints/tangnano20k.cst
	$(NEXTPNR) --json $< --write $@ --top blinky \
		--device $(DEVICE) \
		--vopt family=$(FAMILY) \
		--vopt cst=constraints/tangnano20k.cst \
		--freq $(FREQ)

$(BUILD)/blinky.fs: $(BUILD)/blinky_routed.json
	$(PACK) -d $(FAMILY) -o $@ $<

blinky: $(BUILD)/blinky.fs

load-blinky: $(BUILD)/blinky.fs
	$(LOADER) -b tangnano20k $<

flash-blinky: $(BUILD)/blinky.fs
	$(LOADER) -b tangnano20k -f $<

soc:
	$(PYTHON) -m tang_nano_kyma.soc --toolchain=apicula --build

load-soc:
	$(PYTHON) -m tang_nano_kyma.soc --toolchain=apicula --load

flash-soc:
	$(PYTHON) -m tang_nano_kyma.soc --toolchain=apicula --flash

demo:
	$(MAKE) -C firmware

term:
	@test -n "$(PORT)" || (echo "Pasa el puerto: make term PORT=/dev/cu.usbmodemXXX"; exit 1)
	litex_term $(PORT)

term-demo: demo
	@test -n "$(PORT)" || (echo "Pasa el puerto: make term-demo PORT=/dev/cu.usbmodemXXX"; exit 1)
	litex_term --kernel firmware/kyma_demo.bin $(PORT)

clean:
	rm -rf $(BUILD)
	$(MAKE) -C firmware clean || true
