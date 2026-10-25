#!/usr/bin/env python3
#
# LiteX SoC for the Sipeed Tang Nano 20K.
# Softcore: VexRiscv (RV32IM, variant "lite" unless --cpu-variant says otherwise).
# SPDX-License-Identifier: BSD-2-Clause

from pathlib import Path

from migen import *

from litex.gen import *

from litex.build.io import DDROutput

from litex.soc.cores.clock.gowin_gw2a import GW2APLL
from litex.soc.cores.gpio import GPIOIn
from litex.soc.integration.builder import Builder
from litex.soc.integration.soc_core import SoCCore
from litex.soc.interconnect.csr import CSRStorage

from tang_nano_kyma.platform import Platform

_RTL = Path(__file__).resolve().parents[1] / "rtl" / "kyma_leds.v"


class _CRG(LiteXModule):
    def __init__(self, platform, sys_clk_freq):
        self.rst = Signal()
        self.cd_sys = ClockDomain()
        self.cd_por = ClockDomain()

        clk27 = platform.request("clk27")

        por_count = Signal(16, reset=2**16 - 1)
        por_done = Signal()
        self.comb += self.cd_por.clk.eq(clk27)
        self.comb += por_done.eq(por_count == 0)
        self.sync.por += If(~por_done, por_count.eq(por_count - 1))

        self.pll = pll = GW2APLL(devicename=platform.devicename, device=platform.device)
        self.comb += pll.reset.eq(~por_done | self.rst)
        pll.register_clkin(clk27, 27e6)
        pll.create_clkout(self.cd_sys, sys_clk_freq)


class KymaLeds(LiteXModule):
    """Verilog LED block on the CSR bus. pattern bit 1 lights that LED."""

    def __init__(self, pads, clk_hz):
        self.pattern = CSRStorage(6, description="Active-high LED pattern.")
        self.enable = CSRStorage(1, description="1: hold pattern. 0: rotate a single LED.")
        self.specials += Instance(
            "kyma_leds",
            p_CLK_HZ=int(clk_hz),
            i_clk=ClockSignal(),
            i_rst=ResetSignal(),
            i_pattern=self.pattern.storage,
            i_enable=self.enable.storage,
            o_leds_n=pads,
        )


class BaseSoC(SoCCore):
    def __init__(self, toolchain="apicula", sys_clk_freq=48e6, with_sdram=False, **kwargs):
        platform = Platform(toolchain=toolchain)
        platform.add_source(str(_RTL))

        self.crg = _CRG(platform, sys_clk_freq)

        kwargs.setdefault("cpu_type", "vexriscv")
        kwargs.setdefault("cpu_variant", "lite")
        kwargs.setdefault("ident", "Kyma RISC-V SoC on Tang Nano 20K")
        if not with_sdram:
            kwargs.setdefault("integrated_main_ram_size", 0x8000)

        SoCCore.__init__(self, platform, sys_clk_freq, **kwargs)

        if with_sdram:
            if self.integrated_main_ram_size:
                raise SystemExit("with_sdram requires integrated_main_ram_size = 0")
            from litedram.modules import M12L64322A
            from litedram.phy import GENSDRPHY

            class SDRAMPads:
                def __init__(self):
                    self.clk = platform.request("O_sdram_clk")
                    self.cke = platform.request("O_sdram_cke")
                    self.cs_n = platform.request("O_sdram_cs_n")
                    self.cas_n = platform.request("O_sdram_cas_n")
                    self.ras_n = platform.request("O_sdram_ras_n")
                    self.we_n = platform.request("O_sdram_wen_n")
                    self.dm = platform.request("O_sdram_dqm")
                    self.a = platform.request("O_sdram_addr")
                    self.ba = platform.request("O_sdram_ba")
                    self.dq = platform.request("IO_sdram_dq")

            pads = SDRAMPads()
            self.specials += DDROutput(0, 1, pads.clk, ClockSignal("sys"))
            self.sdrphy = GENSDRPHY(pads, sys_clk_freq)
            self.add_sdram(
                "sdram",
                phy=self.sdrphy,
                module=M12L64322A(sys_clk_freq, "1:1"),
                l2_cache_size=128,
            )

        self.kyma_leds = KymaLeds(platform.request_all("led_n"), sys_clk_freq)
        # Buttons are active-low on the board. The CSR reads 1 when pressed.
        self.buttons = GPIOIn(pads=~platform.request_all("btn"))


def main():
    from litex.build.parser import LiteXArgumentParser

    parser = LiteXArgumentParser(platform=Platform, description="LiteX RISC-V SoC on Tang Nano 20K.")
    parser.add_target_argument("--flash", action="store_true", help="Write the bitstream to SPI flash.")
    parser.add_target_argument("--sys-clk-freq", default=48e6, type=float, help="System clock frequency.")
    parser.add_target_argument("--with-sdram", action="store_true", help="Use the 64 Mbit SIP SDRAM (needs litedram).")
    parser.set_defaults(cpu_type="vexriscv", cpu_variant="lite")
    args = parser.parse_args()

    if args.with_sdram:
        args.integrated_main_ram_size = 0

    soc = BaseSoC(
        toolchain=args.toolchain,
        sys_clk_freq=args.sys_clk_freq,
        with_sdram=args.with_sdram,
        **parser.soc_argdict,
    )

    # synth_gowin defaults to the GW1N cell library. This part is GW2A.
    if args.toolchain == "apicula" and "-family" not in soc.platform.toolchain._synth_opts:
        soc.platform.toolchain._synth_opts += " -family gw2a"

    builder = Builder(soc, **parser.builder_argdict)
    if args.build:
        builder.build(**parser.toolchain_argdict)

    if args.load:
        prog = soc.platform.create_programmer()
        prog.load_bitstream(builder.get_bitstream_filename(mode="sram"))

    if args.flash:
        prog = soc.platform.create_programmer()
        prog.flash(0, builder.get_bitstream_filename(mode="flash"), external=True)


if __name__ == "__main__":
    main()
