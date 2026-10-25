#include <stdio.h>

#include <generated/csr.h>
#include <generated/soc.h>
#include <irq.h>
#include <libbase/uart.h>

static void delay(void)
{
	for (volatile unsigned i = 0; i < 100000; i++)
		;
}

int main(void)
{
	irq_setmask(0);
	irq_setie(1);
	uart_init();

	printf("\nKyma demo — VexRiscv on Tang Nano 20K\n");
	printf("sysclk %lu Hz\n", (unsigned long)CONFIG_CLOCK_FREQUENCY);
	printf("S1 holds 010101, S2 holds 101010, neither lets the LEDs walk.\n");

	kyma_leds_enable_write(0);

	while (1) {
		unsigned buttons = buttons_in_read();

		if (buttons & 0x1) {
			kyma_leds_enable_write(1);
			kyma_leds_pattern_write(0x15);
		} else if (buttons & 0x2) {
			kyma_leds_enable_write(1);
			kyma_leds_pattern_write(0x2a);
		} else {
			kyma_leds_enable_write(0);
		}
		delay();
	}

	return 0;
}
