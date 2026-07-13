import serial # make sure pyserial, not serial is installed
import time
import io
from PIL import Image
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
ser.write([0, 0, 0]) # flush cfg fsm

pix_format = '16b_sum'
crc_check = False
n_rows = 40
n_cols = 1600
n_slices = 12

if pix_format == 'RAW8':
    n_bytes_per_row = n_cols
    if crc_check:
        n_bytes_per_row += 4
elif pix_format == 'RAW10':
    n_bytes_per_row = int(n_cols * 5 / 4)
elif pix_format == 'RAW12':
    n_bytes_per_row = int(n_cols * 3 / 2)
elif pix_format == 'RAW12avg':
    n_bytes_per_row = int(n_cols * 3 / 2)
elif pix_format == '16b_sum':
    n_bytes_per_row = int(n_cols * 2)

# configure for frame buffer read
#ser.write([0xff, ireg, ival])
ser.write([0xfe, (1<<7)+1, 2]) # select raw frame as data source
ser.write([0xfe, (1<<7)+5, 0]) # select slice 0
ser.write([0xfe, (1<<7)+6, 0]) # set to sum 1 images


n_crc_errors = 0
for iframe in range(1):
    for i in range(3):
        time.sleep(0.05)
        ser.reset_input_buffer()
    print(f"Processing frame {iframe}")
    img_raw_data = bytearray()
    print("Trigger slice   ", end='')
    for islice in range(n_slices):
        print(f"\b\b{islice:2d}", end='', flush=True)
        ser.write([0xfe, (1<<7)+5, islice]) # set slice number
        ser.write([0xfe, (1<<7)+0, 1<<1]) # trigger slice
        ser.write([0xfe, (1<<7)+0, 0])
        img_raw_data.extend(ser.read(n_rows*n_bytes_per_row))
    #ser.close()
    print("")

    if pix_format == 'RAW8':
        img_data = np.array(img_raw_data, dtype=np.uint8)
        img_data = img_data.reshape((n_rows*n_slices, n_bytes_per_row))
    elif pix_format == 'RAW10':
        img_data = np.zeros(n_rows*n_cols*n_slices, dtype=np.uint32)
        for ipix in range(0, len(img_data), 4):
            img_data[ipix] = (img_raw_data[int(ipix*5/4)]<<2) + (img_raw_data[int(ipix*5/4)+4]&0b00000011)
            img_data[ipix+1] = (img_raw_data[int(ipix*5/4)+1]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b00001100)>>2)
            img_data[ipix+2] = (img_raw_data[int(ipix*5/4)+2]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b00110000)>>4)
            img_data[ipix+3] = (img_raw_data[int(ipix*5/4)+3]<<2) + ((img_raw_data[int(ipix*5/4)+4]&0b11000000)>>6)
    elif pix_format == 'RAW12':
        img_data = np.zeros(n_rows*n_cols*n_slices, dtype=np.uint32)
        for ipix in range(0, len(img_data), 2):
            img_data[ipix] = (img_raw_data[int(ipix*3/2)]<<4) + (img_raw_data[int(ipix*3/2)+2]&0x0f)
            img_data[ipix+1] = (img_raw_data[int(ipix*3/2)+1]<<4) + ((img_raw_data[int(ipix*3/2)+2]&0xf0)>>4)
    elif pix_format == 'RAW12avg':
        img_data = np.zeros(n_rows*n_cols*n_slices, dtype=np.uint32)
        for ipix in range(0, len(img_data), 2):
            img_data[ipix] = img_raw_data[int(ipix*3/2)] + ((img_raw_data[int(ipix*3/2)+1]&0x0f)<<8)
            img_data[ipix+1] = (img_raw_data[int(ipix*3/2)+1]>>4) + (img_raw_data[int(ipix*3/2)+2]<<4)
    elif pix_format == '16b_sum':
        img_data = np.frombuffer(img_raw_data, dtype=np.uint16)
        
    img_mean = np.mean(img_data)
    img_var = np.var(img_data)
    img_k2 = img_var/(img_mean**2)
    print(f"pix val mean {img_mean:.1f}  var {img_var:.2f}  k2 {img_k2:.3f}")

    #n_crc_errors = 0
    if crc_check == True and pix_format == 'RAW8':
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

# If it's raw pixel data, use frombuffer.
# You need to know the image mode (e.g., 'L' for grayscale, 'RGB' for color)
# and the dimensions (width, height) for frombuffer.
# Example for raw grayscale data:
if pix_format == 'RAW8':
    if crc_check:
        img = Image.frombuffer('L', (n_cols+4, n_rows*n_slices), img_data, 'raw', 'L', 0, 1)
    else:
        img = Image.frombuffer('L', (n_cols, n_rows*n_slices), img_data, 'raw', 'L', 0, 1)
else:
    img = img_data.reshape((n_rows*n_slices, n_cols))


# 3. Display the image using Matplotlib
plt.imshow(img, cmap='gray')
plt.axis('off')  # Hide axes for cleaner image display
plt.show()

sum_I_1 = np.sum(img[0:64, 0:60]-1)
sum_sq_I_1 = np.sum(np.square(img[0:64, 0:60].astype(np.uint64)-1))
print(f'Sum 1st ROI {sum_I_1}, sum of squares {sum_sq_I_1}')

# hist, bins = np.histogram(img_data, [i for i in range(2**12)]) 

# printing histogram
# print()
# print (hist[:10]) 
# print (bins[:10]) 
# print() 

plt.hist(img_data.flatten(), [i for i in range(0,2**12,1)])
plt.xlim([0, 2**12])
#plt.ylim([0, 10000])
plt.xlabel('Digital Level')
plt.title(f'{pix_format} Histogram')
plt.text(200, 800*4, f"mean: {img_mean:.1f} \nvar: {img_var:.2f} \nk2: {img_k2:.3f}")
plt.show()

# Save image as PNG
if pix_format == 'RAW8':
    now = datetime.now()
    fname = now.strftime("%Y%m%d_%H%M%S.png")
    img.save(fname, format="PNG")
