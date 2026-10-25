# Tang Nano 20K — LiteX, VexRiscv, Yosys

SoC RISC-V para la [Sipeed Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html) (Gowin GW2AR-LV18QN88C8/I7). La placa está descrita en Python y en Verilog. El núcleo es **VexRiscv**, el softcore RISC-V que usa LiteX.

El flujo de implementación es el abierto:

`Yosys` (`synth_gowin -family gw2a`) → `nextpnr-himbaechel` → `gowin_pack` (Apicula) → `openFPGALoader`

El IDE de Gowin sigue disponible con `--toolchain=gowin`.

## Qué hay en el repo

| Ruta | Rol |
| --- | --- |
| `tang_nano_kyma/platform.py` | Reloj, UART, LEDs, botones, flash, SD, HDMI, SDRAM del encapsulado y conectores J5/J6 |
| `tang_nano_kyma/soc.py` | SoC LiteX: PLL a 48 MHz, VexRiscv, UART, botones y el periférico Verilog |
| `rtl/kyma_leds.v` | Seis LEDs activos en bajo, colgados del bus CSR |
| `rtl/blinky.v` | Blinky Verilog, sin LiteX |
| `constraints/tangnano20k.cst` | Pines del blinky |
| `firmware/` | Programa bare-metal que se carga por la UART encima del BIOS |

Por defecto la ROM del BIOS, la SRAM y 32 KiB de RAM principal salen de los bloques de RAM de la FPGA. `--with-sdram` usa los 64 Mbit de SDRAM que van dentro del GW2AR (hace falta `litedram`).

## Herramientas

Hace falta un Yosys con `synth_gowin -family gw2a` (0.40 o más nuevo) y un `nextpnr-himbaechel` compilado con los dispositivos Gowin. El `nextpnr` de Homebrew suele traer solo iCE40: el binario que vale es `nextpnr-himbaechel`.

La vía más corta es [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases). Después:

```bash
pip install apycula          # instala gowin_pack
brew install openfpgaloader  # o el paquete de tu distro
```

El compilador RISC-V tiene que llamarse `riscv64-unknown-elf-gcc` o `riscv-none-elf-gcc`.

LiteX se instala desde git, no desde el snapshot de PyPI:

```bash
mkdir -p ~/src && cd ~/src
curl -fsSL -o litex_setup.py https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
python3 litex_setup.py --init --install --user
```

`--with-sdram` además necesita el repositorio `litedram` que ese script ya clona. El BIOS llama a `python3 -m litex.soc.software.crcfbigen`: ese `python3` tiene que ser el intérprete donde quedó LiteX. Si usas un virtualenv, actívalo antes de `make soc`.

```bash
make doctor
```

## Blinky Verilog

Enciende un LED y lo rota a unos 4 Hz. Sirve para comprobar el cable USB antes de construir el SoC.

```bash
make blinky
make load-blinky          # SRAM: se pierde al quitar la alimentación
make flash-blinky         # SPI flash: arranca solo
```

## SoC VexRiscv

```bash
make soc
make load-soc
```

La UART del USB-C es el segundo interfaz serie. En macOS suele ser `/dev/cu.usbmodem…`. A 115200 8N1:

```bash
make term PORT=/dev/cu.usbmodemXXXX
```

El BIOS de LiteX imprime la identificación del SoC y deja el prompt `litex>`. Los LEDs caminan solos porque `enable` arranca en 0.

Variantes del núcleo: `--cpu-variant=minimal` (RV32I), `lite` (RV32IM, el defecto), `standard` (con caché). Ejemplo:

```bash
python3 -m tang_nano_kyma.soc --toolchain=apicula --cpu-variant=standard --build
```

Para usar la SDRAM del encapsulado:

```bash
python3 -m tang_nano_kyma.soc --toolchain=apicula --with-sdram --build
```

## Firmware

`make demo` enlaza `firmware/main.c` contra el SDK que dejó `make soc` (cabeceras CSR, `libbase`, crt0 de VexRiscv). S1 deja el patrón `010101`, S2 deja `101010`, y si no hay botón pulsado los LEDs vuelven a rotar. Un 1 en el CSR es un LED encendido; el Verilog invierte la lógica de la placa.

```bash
make demo
make term-demo PORT=/dev/cu.usbmodemXXXX
```

`litex_term --kernel` entrega el binario al BIOS por la UART y salta a la RAM principal (`0x40000000`).

## Pines que usa el SoC

| Señal | Ball |
| --- | --- |
| Reloj 27 MHz | 4 |
| UART TX / RX | 69 / 70 |
| LED0…LED5, activos en bajo | 15, 16, 17, 18, 19, 20 |
| Botón S1 / S2, activos en bajo | 88 / 87 |

El resto del mapa (flash, SD, HDMI, RGB, J5, J6 y la SDRAM interna) está en `tang_nano_kyma/platform.py`.
