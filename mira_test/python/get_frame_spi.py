import spidev
from time import sleep
import matplotlib.pyplot as plt
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
        if len(buf) < n_rdnow:
            print(f"read error: expected {n_rdnow}, received {len(buf)}")
        bytes_available = buf[0] + buf[1]*256 - (n_rdnow-2)
        if n_rdnow > 2:
            out_buf[n_bytes_read:(n_bytes_read+n_rdnow)] = buf[2:]
            n_bytes_read += (n_rdnow-2)
        else:
            sleep(0.001)
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


# configure for frame buffer read
#ser.write([0xfe, ireg, ival])
spi.writebytes2([0xfe, (1<<7)+1, 2]) # select raw frame as data source
spi.writebytes2([0xfe, (1<<7)+5, 0]) # select slice 0
spi.writebytes2([0xfe, (1<<7)+6, n_img_sum-1]) # set to sum N images

# reset tx buffer in fpga
spi.writebytes2([0xfe, (1<<7)+0, (1<<7)])
spi.writebytes2([0xfe, (1<<7)+0, 0])
sleep(0.001)

img_raw_data = bytearray()
print("Trigger slice   ", end='')
for islice in range(n_slices):
    print(f"\b\b{islice:2d}", end='', flush=True)
    spi.writebytes2([0xfe, (1<<7)+5, islice]) # set slice number
    spi.writebytes2([0xfe, (1<<7)+0, 1<<1]) # trigger slice
    spi.writebytes2([0xfe, (1<<7)+0, 0])
    img_raw_data.extend(spi_read(n_rows*n_bytes_per_row))

spi.close()
print("")

img_data = np.frombuffer(img_raw_data, dtype=np.uint16)
    
img_mean = np.mean(img_data)
img_var = np.var(img_data)
img_k2 = img_var/(img_mean**2)
print(f"pix val mean {img_mean:.1f}  var {img_var:.2f}  k2 {img_k2:.3f}")

# Display the image using Matplotlib
print("show image")
img = img_data.reshape((n_rows*n_slices, n_cols))
plt.imshow(img, cmap='gray')
plt.axis('off')  # Hide axes for cleaner image display
plt.show()

# Display histogram
# plt.hist(img_data.flatten(), [i for i in range(0,2**12,1)])
# plt.xlim([0, n_img_sum*(2**bit_depth)])
# plt.xlabel('Digital Level')
# plt.title(f'RAW{bit_depth} Histogram of {n_img_sum} Images')
# plt.text(200, 800*4, f"mean: {img_mean:.1f} \nvar: {img_var:.2f} \nk2: {img_k2:.3f}")
# plt.show()
