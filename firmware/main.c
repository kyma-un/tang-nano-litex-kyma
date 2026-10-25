#include <stdio.h>

#include <generated/csr.h>
#include <generated/soc.h>
#include <irq.h>
#include <libbase/uart.h>

static void delay(void)
{
	for (volatile unsigned i = 0; i < 2000000; i++)
		;
}

int main(void)
{
	unsigned buttons;
	unsigned last;

	/* Poll the UART. With interrupts enabled, printf waits for a TX IRQ
	 * that never arrives and the button loop is never reached. */
	irq_setmask(0);
	irq_setie(0);
	uart_init();

	kyma_leds_enable_write(1);
	kyma_leds_pattern_write(0x3f);
	printf("\nKyma demo, VexRiscv on Tang Nano 20K\n");
	printf("sysclk %lu Hz\n", (unsigned long)CONFIG_CLOCK_FREQUENCY);
	printf("LEDs on means the program is running. Then hold S1 or S2.\n");
	delay();

	last = 0xffffffff;
	while (1) {
		buttons = buttons_in_read() & 3;
		if (buttons != last) {
			printf("buttons: %u\n", buttons);
			last = buttons;
		}
		if (buttons & 0x1) {
			kyma_leds_enable_write(1);
			kyma_leds_pattern_write(0x15);
		} else if (buttons & 0x2) {
			kyma_leds_enable_write(1);
			kyma_leds_pattern_write(0x2a);
		} else {
			kyma_leds_enable_write(0);
		}
	}

	return 0;
}
