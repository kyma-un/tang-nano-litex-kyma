<img src="assets/banner.png" />

# ¡Bienvenidxs!

Este repositorio es el flujo de **LiteX** de KYMA para la [Sipeed Tang Nano 20K](https://wiki.sipeed.com/hardware/en/tang/tang-nano-20k/nano-20k.html). La placa (Gowin GW2AR-LV18QN88C8/I7) está descrita en Python y en Verilog, y el SoC arranca un softcore RISC-V: **VexRiscv**.

## ¿Para qué usamos LiteX?

Para no redibujar un SoC cada vez que una placa de KYMA necesita un procesador, una UART y un periférico. LiteX arma el sistema en Python, deja el Verilog de los bloques propios en el repo, y lo sintetiza con herramientas abiertas.

* **¿Por qué no solo el IDE de Gowin?** El proyecto queda atado a una instalación propietaria y es más difícil de repetir en otra máquina del grupo.
* **¿Por qué no describir todo el SoC a mano en Verilog?** El bus, la UART, el timer y el arranque del núcleo ya existen. Reescribirlos no aporta al experimento.

### Pero, ¿por qué sí LiteX?

* El mismo archivo Python describe la placa y el SoC, y se puede volver a generar.
* El núcleo es VexRiscv, un RISC-V de verdad, con BIOS y consola serie.
* El Verilog propio (los LEDs, un periférico nuevo) entra al bus sin salir del flujo.
* La síntesis es abierta: Yosys, nextpnr, Apicula y openFPGALoader.
* Se puede trabajar el diseño sin la placa conectada y cargarlo cuando esté en la mesa.

El IDE de Gowin sigue disponible con `--toolchain=gowin` si hace falta comparar.

---

### Getting Started

Al terminar vas a tener tres cosas corriendo en la Tang Nano 20K: un blinky en Verilog, el BIOS del SoC en la UART, y un programa que cambia los LEDs con los botones.

1. Instala el flujo abierto. Hace falta un Yosys con `synth_gowin -family gw2a` y un `nextpnr-himbaechel` compilado con los dispositivos Gowin. El `nextpnr` de Homebrew suele traer solo iCE40: el binario que vale es `nextpnr-himbaechel`. La vía más corta es [OSS CAD Suite](https://github.com/YosysHQ/oss-cad-suite-build/releases). Después:

   ```bash
   pip install apycula          # instala gowin_pack
   brew install openfpgaloader  # o el paquete de tu distro
   ```

   El compilador RISC-V tiene que llamarse `riscv64-unknown-elf-gcc` o `riscv-none-elf-gcc`.

2. Instala LiteX desde git. El snapshot de PyPI se queda atrás.

   ```bash
   mkdir -p ~/src && cd ~/src
   curl -fsSL -o litex_setup.py https://raw.githubusercontent.com/enjoy-digital/litex/master/litex_setup.py
   python3 litex_setup.py --init --install --user
   ```

   El BIOS llama a `python3 -m litex.soc.software.crcfbigen`. Ese `python3` tiene que ser el intérprete donde quedó LiteX. Si usas un virtualenv, actívalo antes de construir.

3. Clona este repositorio y comprueba que las herramientas están en el `PATH`.

   ```bash
   make doctor
   ```

4. Sintetiza el blinky y cárgalo. Los seis LEDs rotan a unos 4 Hz. Sirve para comprobar el cable USB antes de construir el SoC.

   ```bash
   make blinky
   make load-blinky     # SRAM de la FPGA: se pierde al quitar la alimentación
   make flash-blinky    # SPI flash: arranca solo
   ```

5. Construye el SoC y cárgalo. El reloj de 27 MHz pasa por un PLL a 48 MHz. El núcleo por defecto es VexRiscv `lite` (RV32IM).

   ```bash
   make soc
   make load-soc
   ```

6. Abre la consola. La UART del USB-C es el segundo interfaz serie. En macOS suele ser `/dev/cu.usbmodem…`, a 115200 8N1.

   ```bash
   make term PORT=/dev/cu.usbmodemXXXX
   ```

   El BIOS imprime la identificación del SoC y deja el prompt `litex>`. Los LEDs caminan solos porque el registro `enable` arranca en 0.

7. Compila el programa de los botones y súbelo por la UART, encima del BIOS. S1 deja el patrón `010101`, S2 deja `101010`, y si no hay botón pulsado los LEDs vuelven a rotar.

   ```bash
   make demo
   make term-demo PORT=/dev/cu.usbmodemXXXX
   ```

¡Y listo! `litex_term --kernel` entrega el binario al BIOS y salta a la RAM principal (`0x40000000`).

> Antes de construir, activa el mismo Python donde instalaste LiteX. Si `make soc` falla en `python3 -m litex...`, el intérprete del `PATH` no es ese.

## Estructura del repositorio

| Ruta | Para qué sirve |
| --- | --- |
| `tang_nano_kyma/platform.py` | La placa: reloj, UART, LEDs, botones, flash, SD, HDMI, SDRAM del encapsulado y los conectores J5/J6 |
| `tang_nano_kyma/soc.py` | El SoC: PLL, VexRiscv, UART, botones y el periférico Verilog |
| `rtl/kyma_leds.v` | Seis LEDs activos en bajo, colgados del bus CSR |
| `rtl/blinky.v` | Blinky en Verilog, sin LiteX |
| `constraints/tangnano20k.cst` | Pines del blinky |
| `firmware/` | Programa bare-metal que se carga por la UART |

Por defecto la ROM del BIOS, la SRAM y 32 KiB de RAM principal salen de los bloques de RAM de la FPGA. El BIOS de esta configuración ocupa unos 23 KiB. `--with-sdram` usa los 64 Mbit de SDRAM que van dentro del GW2AR. Para eso hace falta `litedram`, que el script de instalación de LiteX ya clona.

## Otras variantes del SoC

`minimal` es RV32I. `lite` es RV32IM y es el defecto. `standard` añade caché.

```bash
python3 -m tang_nano_kyma.soc --toolchain=apicula --cpu-variant=standard --build
python3 -m tang_nano_kyma.soc --toolchain=apicula --with-sdram --build
```

Un 1 en el CSR de LEDs enciende ese LED. El Verilog invierte la lógica, porque en la placa el LED se prende con un 0.

## Pines que usa el SoC

| Señal | Ball |
| --- | --- |
| Reloj 27 MHz | 4 |
| UART TX / RX | 69 / 70 |
| LED0…LED5, activos en bajo | 15, 16, 17, 18, 19, 20 |
| Botón S1 / S2, activos en bajo | 88 / 87 |

El resto del mapa está en `tang_nano_kyma/platform.py`.

<img src="assets/footer.png" />
