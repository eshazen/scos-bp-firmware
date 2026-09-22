#
# read FW version and bit depth only for SPI testing
#
import spidev
from time import sleep
import numpy as np

# Initialize SPI bus
spi_bus = 0
spi_dev = 0
spi_mode = 0
spi_max_speed_hz = 12_000_000
spi = spidev.SpiDev()
spi.open(spi_bus, spi_dev) #(bus, device)
spi.max_speed_hz = spi_max_speed_hz
spi.mode = spi_mode
rxtx_buf = np.zeros(8196, dtype=np.uint8)
spi.writebytes2([0, 0, 0]) # flush cfg fsm

def spi_read(n_bytes_rqd=2):
    global spi
    out_buf = bytearray(n_bytes_rqd)
    n_bytes_read = 0
    bytes_available = 0
    while n_bytes_read < n_bytes_rqd:
        # limit reads/writes to chunks of less than SPI bufsiz
        # (/sys/module/spidev/parameters/bufsiz ~= 4096 on this machine)
        n_rdnow = min(bytes_available+2, 4096)
        buf = spi.readbytes(n_rdnow)
        lbuf = len(buf)
        print(f"read bytes( {n_rdnow} ) returned {lbuf}")
        print(buf)
        if len(buf) < n_rdnow:
            print(f"read error: expected {n_rdnow}, received {len(buf)}")
        bytes_available = buf[0] + buf[1]*256 - (n_rdnow-2)
        print(f"bytes_available = {bytes_available}")
        if n_rdnow > 2:
            print("add to out_buf from 2:")
            print(buf)
            out_buf[n_bytes_read:(n_bytes_read+n_rdnow)] = buf[2:]
            n_bytes_read += (n_rdnow-2)
            print(f"n_bytes_read = {n_bytes_read}")
        else:
            sleep(0.001)
    print("out_buf")
    print(out_buf)
    return out_buf

n_rows = 40
n_cols = 1600
n_slices = 12
n_img_sum = 1 # number of images to sum in fpga

n_bytes_per_row = int(n_cols * 2)

spi.writebytes2([0xfe, (1<<7)+1, 0]) # select cfg reg as data source
# reset tx buffer in fpga
spi.writebytes2([0xfe, (1<<7)+0, (1<<7)])
spi.writebytes2([0xfe, (1<<7)+0, 0])
sleep(0.001)

# get firmware version and bit depth
spi.writebytes2([0xfe, (1<<7)+1, 0]) # select cfg reg as data source
spi.writebytes2([0xfe, 14, 0]) # read cmd for bit depth
spi.writebytes2([0xfe, 15, 0]) # read cmd for fw version
buf = spi_read(4)
if buf[0] == 0xfd and buf[2] == 0xfd:
    bit_depth = buf[1]
    fw_ver = buf[3]
    print(f"FPGA fw ver: {fw_ver}, bit depth: {bit_depth}")
else:
    print(f"read error, buf = {buf}")

spi.close()
print("")

