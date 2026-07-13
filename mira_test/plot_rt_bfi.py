from time import perf_counter, sleep
import numpy as np
import pyqtgraph as pg
import serial # make sure pyserial, not serial is installed

ser = serial.Serial('COM19', baudrate=12000000, rtscts=True, timeout=2)
ser.set_buffer_size(rx_size = 1048575, tx_size = 1024)
sleep(0.05)
ser.reset_input_buffer()

win = pg.GraphicsLayoutWidget(show=True)
win.setWindowTitle('Real-Time BFi')

N_FRAMES_TO_DISP = 1200
FRAME_RATE = 240
N_FRAMES_PER_XFER = 20
TILE_SIZE = [64, 60]
FRAME_SIZE = [1600, 480]

N_PIX = TILE_SIZE[0] * TILE_SIZE[1]
N_TILES = int(FRAME_SIZE[0] * FRAME_SIZE[1] / N_PIX)
N_BYTES_PER_XFER = int(4*N_FRAMES_PER_XFER*(2*N_TILES+2))

VAR_DIGI = 1/12
GAIN = 0.0956 / 10 #need to re-measure this
VAR_READ = 1

p = win.addPlot()
p.showGrid(x=True, y=True)
p.setLabel(axis='bottom', text='Time', units='s')
p.setLabel(axis='left', text='BFi')
bfi = np.empty(N_FRAMES_TO_DISP)
bfi[:] = np.nan
tv = np.arange(N_FRAMES_TO_DISP)/FRAME_RATE
curve = p.plot(x=tv, y=bfi, pen={'color':(255, 220, 220), 'width':1})

ptr = 0
frm_cnt = 0
def update():
    global ser, bfi, ptr, frm_cnt
    rawdat_bytes = ser.read(N_BYTES_PER_XFER)

    # check first header, calculate offset
    offset = 0
    header = rawdat_bytes[0:8]
    while not (header == b'\xfe\xff\x00\x00\xff\xff\x00\x00') and offset+10 < N_BYTES_PER_XFER:
        offset += 1
        header = rawdat_bytes[offset:offset+8]

    if offset == 0:
        rawdat = np.frombuffer(rawdat_bytes, dtype=np.uint32)
        for iframe in range(N_FRAMES_PER_XFER):
            # Check header
            header_start = int(iframe * (2 * N_TILES + 2))
            header = rawdat[header_start:header_start + 2]
            
            if not (header == [65534, 65535]).all():
                print(f' header error 0x{header[0]:08x} 0x{header[1]:08x}')
                result = np.nan
            else:
                # Extract pixel sum and sum of squares
                indices_sum = np.arange(0, 2 * N_TILES, 2) + 2 + iframe * (2 * N_TILES + 2)
                indices_sq_sum = np.arange(0, 2 * N_TILES, 2) + 3 + iframe * (2 * N_TILES + 2)
                
                pix_sum_array = rawdat[indices_sum]
                pix_sq_sum_array = rawdat[indices_sq_sum]
                
                # Calculate statistics
                mean_I_array = pix_sum_array / N_PIX
                var_I_array = pix_sq_sum_array / N_PIX - mean_I_array ** 2
                var_shot_array = mean_I_array * GAIN
                K2_f_array = (var_I_array - VAR_DIGI - var_shot_array - VAR_READ) / (mean_I_array ** 2)
                result = 1/np.mean(K2_f_array)
                #result = pix_sum_array[1]

            # Store result
            K2_f_index = (ptr + iframe) % N_FRAMES_TO_DISP
            bfi[K2_f_index] = result
    else:
        print(f"incurred offset of {offset} bytes")
        # flush to realign
        ser.read(offset)

    ptr = (ptr+N_FRAMES_PER_XFER) % N_FRAMES_TO_DISP
    frm_cnt += N_FRAMES_PER_XFER
    bfi[ptr:ptr+N_FRAMES_PER_XFER] = np.nan # create gap in front of newest data
    #print(f'Result {bfi[0]}')
    curve.setData(x=tv, y=bfi)
    
timer = pg.QtCore.QTimer()
timer.timeout.connect(update)
timer.start(50)

if __name__ == '__main__':
    print("Starting real-time BFi display")
    # configure for real-time bfi
    #ser.write([0xfe, ireg, ival])
    ser.write([0xfe, (1<<7)+1, 1]) # select bfi pre-processing as datasource
    ser.write([0xfe, (1<<7)+2, 0]) # dark level subtraction = 0
    ser.write([0xfe, (1<<7)+0, 1]) # run img processing

    pg.exec()
    print(" closing")
    ser.write([0xfe, (1<<7)+0, 0]) # stop img processing
    ser.reset_input_buffer()
    ser.close()