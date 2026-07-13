import serial # make sure pyserial, not serial is installed
import time
import io
#from PIL import Image
import matplotlib.pyplot as plt
from datetime import datetime
import numpy as np
from crc import Configuration, Calculator

crc_config = Configuration(
    width=16, 
    polynomial=0x1021, #0x1021
    init_value=0xffff, 
    final_xor_value=0x0000, 
    reverse_input=True, 
    reverse_output=True)
crc_calc = Calculator(crc_config)

ser = serial.Serial('COM19', baudrate=12000000, rtscts=True, timeout=3)
for i in range(5):
    time.sleep(0.05)
    ser.reset_input_buffer()

file_desc = "1ms"
pix_format = 'RAW10'
crc_check = False
n_rows = 30
n_cols = 1600
n_slices = 16
n_frames = 240

if pix_format == 'RAW8':
    n_bytes_per_row = n_cols
    if crc_check:
        n_bytes_per_row += 4
elif pix_format == 'RAW10':
    n_bytes_per_row = int(n_cols * 5 / 4)
elif pix_format == 'RAW12':
    n_bytes_per_row = int(n_cols * 3 / 2)

n_crc_errors = 0
img_data_stack = np.empty((n_frames, n_rows*n_slices, n_cols), dtype=np.uint16)
for iframe in range(n_frames):
    for i in range(8):
        time.sleep(0.05)
        ser.reset_input_buffer()
    print(f"Processing frame {iframe}")
    img_raw_data = bytearray()
    print("Trigger slice   ", end='')
    for islice in range(n_slices):
        print(f"\b\b{islice:2d}", end='', flush=True)
        ser.write([islice, islice+(1<<4)])
        img_raw_data.extend(ser.read(n_rows*n_bytes_per_row))
    #ser.close()
    print("")

    if pix_format == 'RAW8':
        img_data = np.array(img_raw_data, dtype=np.uint8)
        img_data = img_data.reshape((n_rows*n_slices, n_bytes_per_row))
    elif pix_format == 'RAW10':
        img_data = np.zeros(n_rows*n_cols*n_slices, dtype=np.uint16)
        for ipix in range(0, len(img_data), 4):
            img_data[ipix] = (img_raw_data[int(ipix*5/4)]<<2) + (img_raw_data[int(ipix*5/4)+4]&0b00000011)
            img_data[ipix+1] = (img_raw_data[int(ipix*5/4)+1]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b00001100)>>2)
            img_data[ipix+2] = (img_raw_data[int(ipix*5/4)+2]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b00110000)>>4)
            img_data[ipix+3] = (img_raw_data[int(ipix*5/4)+3]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b11000000)>>6)
        img_data = img_data.reshape((n_rows*n_slices, n_cols))
    elif pix_format == 'RAW12':
        img_data = np.zeros(n_rows*n_cols*n_slices, dtype=np.uint16)
        for ipix in range(0, len(img_data), 2):
            img_data[ipix] = (img_raw_data[int(ipix*3/2)]<<4) + (img_raw_data[int(ipix*3/2)+2]&0x0f)
            img_data[ipix+1] = (img_raw_data[int(ipix*3/2)+1]<<4) + ((img_raw_data[int(ipix*3/2)+2]&0xf0)>>4)
        img_data = img_data.reshape((n_rows*n_slices, n_cols))


    img_mean = np.mean(img_data)
    img_var = np.var(img_data)
    img_k2 = img_var/(img_mean**2)
    print(f"pix val mean {img_mean:.1f}  var {img_var:.2f}  k2 {img_k2:.3f}")

    img_data_stack[iframe, :, :] = img_data 

    if crc_check == True:
        print("CRC check line     ", end='')
        for irow in range(img_data.shape[0]):
            if irow%10 == 9:
                print(f"\b\b\b\b{(irow+1):4d}", end='', flush=True)
            #print(f"CRC calculated {crc_calc.checksum(img_data[irow,:-2].tobytes())}  received {img_data[irow,-1]} {img_data[irow,-2]}")
            if not crc_calc.verify(img_data[irow,:-4].tobytes(), (int(img_data[irow,-3])<<8) + int(img_data[irow,-4])):
                n_crc_errors += 1
        print("")
        print(f"CRC errors detected in {n_crc_errors} lines")
        #img_data = img_data[:,:-2] # remove crc from image

ser.close()
print("show image")

mean_img = np.mean(img_data_stack, axis=0, keepdims=False)
var_img = np.var(img_data_stack, axis=0, keepdims=False)

mean_of_mean = np.mean(mean_img.flatten())
var_of_mean = np.var(mean_img.flatten())
mean_of_var = np.mean(var_img.flatten())

now = datetime.now()
now_str = now.strftime("%Y%m%d_%H%M%S")

np.save(f"./meas/{now_str}-{file_desc}-{pix_format}-{n_frames}.npy", img_data_stack)
print("\a") #bell sound

# 3. Display the image using Matplotlib

plt.imshow(mean_img)
plt.axis('off')  # Hide axes for cleaner image display
plt.colorbar(location='bottom', shrink=0.6)
plt.show()

plt.imshow(var_img)
plt.axis('off')  # Hide axes for cleaner image display
plt.colorbar(location='bottom', shrink=0.6)
plt.show()

plt.hist(mean_img.flatten(), [i for i in range(0,2**8,1)])
plt.title(f'{pix_format} {file_desc} Mean Dark Histogram')
plt.xlabel('Digital Level')
plt.grid(visible=True, alpha=0.1)
if pix_format == 'RAW8':
    plt.xlim(0, 2**8)
elif pix_format == 'RAW10':
    plt.xlim(0, 2**10)
elif pix_format == 'RAW12':
    plt.xlim(0, 2**12)
xmin, xmax = plt.xlim()
ymin, ymax = plt.ylim()
plt.text(xmin+0.6*(xmax-xmin), 0.8*ymax, f"n_frames: {n_frames} \nmean: {mean_of_mean:.1f} \nvar: {var_of_mean:.2f}")
plt.savefig(f"./meas/{now_str}-{file_desc}-{pix_format}-{n_frames}-mean.png", dpi=200)
plt.show()

plt.hist(var_img.flatten(), 150)
plt.title(f'{pix_format} {file_desc} Pixel Temporal Variance Histogram')
plt.xlabel('var(Digital Level)')
plt.grid(visible=True, alpha=0.1)
xmin, xmax = plt.xlim()
ymin, ymax = plt.ylim()
plt.text(xmin+0.6*(xmax-xmin), 0.8*ymax, f"n_frames: {n_frames} \nmean: {mean_of_var:.2f}")
plt.savefig(f"./meas/{now_str}-{file_desc}-{pix_format}-{n_frames}-var.png", dpi=200)
plt.show()

