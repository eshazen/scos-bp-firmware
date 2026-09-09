import mira
import power

mira.spi_init()
power.uart_init()

power.all_off()
power.mira_power_up()

cfg_fname = "Mira220_1500Mbps_1600x480_240fps_2lane_1ms_RAW10.csv"  
#cfg_fname = "Mira220_1500Mbps_1600x480_240fps_2lane_1ms_RAW10_walking0s.csv" 
#cfg_fname = "Mira220_1500Mbps_1600x480_240fps_2lane_1ms_RAW8_diagGrad.csv"  
mira.turn_on(cfg_fname=cfg_fname)

mira.spi_close()
