import mira
import power

mira.spi_init()
power.uart_init()

power.all_off()
mira.spi_close()
