from time import perf_counter, sleep
import numpy as np
import pyqtgraph as pg
import spidev

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

# set up real time plotting
win = pg.GraphicsLayoutWidget(show=True)
win.setWindowTitle('Real-Time BFi')

N_FRAMES_TO_DISP = 1200
FRAME_RATE = 240
N_FRAMES_PER_XFER = 24
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

def spi_read(n_bytes_rqd=2):
    global spi
    out_buf = bytearray(n_bytes_rqd)
    n_bytes_read = 0
    bytes_available = 0
    while n_bytes_read < n_bytes_rqd:
        buf = spi.readbytes(2)
        bytes_available = buf[0] + buf[1]*256
        #if len(buf) < n_rdnow or len(buf)<2:
        #    print(f"read error: expected {n_rdnow}, received {len(buf)}")
        #bytes_available = buf[0] + buf[1]*256 - (n_rdnow-2)
        if bytes_available > 0:
            # limit reads/writes to chunks of less than SPI bufsiz
            # (/sys/module/spidev/parameters/bufsiz ~= 4096 on this machine)
            n_rdnow = min(min(bytes_available, n_bytes_rqd-n_bytes_read), 4096-2)
            buf = spi.readbytes(2+n_rdnow)
            out_buf[n_bytes_read:(n_bytes_read+n_rdnow)] = buf[2:]
            n_bytes_read += n_rdnow
        else:
            sleep(0.001)
    return out_buf

ptr = 0
frm_cnt = 0
def update():
    global bfi, ptr, frm_cnt
    rawdat_bytes = spi_read(N_BYTES_PER_XFER)
    
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
        spi_read(offset)

    ptr = (ptr+N_FRAMES_PER_XFER) % N_FRAMES_TO_DISP
    frm_cnt += N_FRAMES_PER_XFER
    bfi[ptr:ptr+N_FRAMES_PER_XFER] = np.nan # create gap in front of newest data
    #print(f'Result {bfi[ptr-1]}')
    curve.setData(x=tv, y=bfi)
    
timer = pg.QtCore.QTimer()
timer.timeout.connect(update)
timer.start(40)

if __name__ == '__main__':
    print("Starting real-time BFi display")
    
    # configure for real-time bfi
    #ser.write([0xfe, ireg, ival])
    spi.writebytes2([0xfe, (1<<7)+1, 1]) # select bfi pre-processing as datasource
    spi.writebytes2([0xfe, (1<<7)+2, 0]) # dark level subtraction = 0
    # reset tx buffer in fpga
    spi.writebytes2([0xfe, (1<<7)+0, (1<<7)])
    spi.writebytes2([0xfe, (1<<7)+0, 0])
    # run img processing
    spi.writebytes2([0xfe, (1<<7)+0, 1]) 

    pg.exec()
    print(" closing")
    spi.writebytes2([0xfe, (1<<7)+0, 0]) # stop img processing
    spi.close()
