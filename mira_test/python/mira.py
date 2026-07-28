
# ---- Mira Power-up sequence ----
# From datasheet section 7.2.1
# 
# 1. Apply 2.5 V power supply (VDD25). Supply ramp up should be greater than 30 µs. Allow
# the bandgap reference to settle (i.e. at least 600 µs).
# 2. Apply 1.35 V power supply (VDD13A, VDD13D and VDD13P). Supply ramp up time should
# be greater than 30 µs. Allow the supply to finish ramping up.
# 3. Apply 1.8 V power supply (VDD18). Supply ramp up time should be greater than 30 µs.
# Allow the supply to finish ramping up.
# 4. Apply the external clock on the CLK_IN clock input pin.
# 5. Release the hard reset signal on the ARST_N input pin. I²C communication is now
# available.
#
# --- Steps 1-5 are handled by the sequencer chip on the demo board ---
#
# 6. Wait for the PLL to lock. Check the lock bit in the read-only register PLL_STATUS through
# I²C read to verify that the PLL has locked.
#
# 7. Disable three internal LDOs by writing via I²C the value 0x02 to address 0x401E and the
# value 0x3B to address 0x4038.
# Attention:
# The external supply VDD25 is connected to VDD25A, VDD25R and VDDINT_1. Hence, the
# internally generated voltages are bypassed. Step 7 in the power-up sequence disables these
# internal voltages.
#
# 8. Restore the LDO and gain calibration values stored in OTP, see section 8.5.5 and
# application note AN001030.
# 
# 9. The sensor is now in its default state. The sensor can now be configured for image capture
# and pixel data output through CCI uploads.

import spidev
from time import sleep

#i2c = busio.I2C(scl=board.GP7, sda=board.GP6, frequency=50000)
spi = spidev.SpiDev()
mira_addr = 0x54  # Mira220
#addr = 0x36 # Mira050??

scl_f = 1
sda_f = 1

def spi_init():
    global spi
    # Initialize SPI bus
    spi_bus = 0
    spi_dev = 0
    spi_mode = 0
    spi_max_speed_hz = 12_000_000
    spi.open(spi_bus, spi_dev) #(bus, device)
    spi.max_speed_hz = spi_max_speed_hz
    spi.mode = spi_mode
    spi.writebytes2([0, 0, 0]) # flush cfg fsm
    # select cfg reg as data source
    spi.writebytes2([0xfe, (1<<7)+1, 0]) 
    # reset tx buffer in fpga
    spi.writebytes2([0xfe, (1<<7)+0, (1<<7)])
    spi.writebytes2([0xfe, (1<<7)+0, 0])
    sleep(0.001)
    update_force()

def spi_close():
    global spi
    spi.close()

# ---- I2C bitbang functions ----
def update_force(): # force i2c pins to either 0 or high-impedance
    global spi, scl_f, sda_f
    spi.writebytes2([0xfe, (1<<7)+8, (sda_f<<1)+scl_f])

def read_bit(): # trigger reading single bit of SDA
    global spi
    spi.writebytes2([0xfe, 8, 0]) # read cmd for i2c reg

def read_all_bits(): # collect all bit reads triggered by read_bit()
    global spi
    buf = spi.readbytes(2+8*2)
    if buf[0] != 8*2 or buf[1] != 0: # verify bytes available
        print("Error: unexpected number of available bytes")
    res = 0
    for ibit in range(8):
        if buf[ibit*2+2] != 0xfd:
            print("Header error")
        res += ((buf[ibit*2+3]>>3)&1) * (1<<(7-ibit)) # add bit value
    return res
    
def start(): # generate i2c start condition
    global scl_f, sda_f
    (scl_f,sda_f) = (1,1)
    update_force()
    (scl_f,sda_f) = (1,0)
    update_force()
    (scl_f,sda_f) = (0,0)
    update_force()
    
def rep_start(): # generate i2c repeated start condition
    global scl_f, sda_f
    (scl_f,sda_f) = (0,1)
    update_force()
    (scl_f,sda_f) = (1,1)
    update_force()
    (scl_f,sda_f) = (1,0)
    update_force()
    (scl_f,sda_f) = (0,0)
    update_force()
    
def stop(): # generate i2c stop condition
    global scl_f, sda_f
    (scl_f,sda_f) = (0,0)
    update_force()
    (scl_f,sda_f) = (1,0)
    update_force()
    (scl_f,sda_f) = (1,1)
    update_force()

def send_byte(data): # send a byte of data over i2c
    # note: low-level function, needs to be used with start(), stop(), ...
    global scl_f, sda_f
    for ii in range(7,-1,-1):
        bval = (data>>ii) & 1
        (scl_f,sda_f) = (0,bval)
        update_force()
        (scl_f,sda_f) = (1,bval)
        update_force()
    # ack/nack bit
    # todo: read ack/nack
    (scl_f,sda_f) = (0,1)
    update_force()
    (scl_f,sda_f) = (1,1)
    update_force()
    (scl_f,sda_f) = (0,1)
    update_force()

def read_byte():
    # note: low-level function, needs to be used with start(), stop(), ...
    global scl_f, sda_f
    for ii in range(8):
        (scl_f,sda_f) = (0,1)
        update_force()
        (scl_f,sda_f) = (1,1)
        update_force()
        read_bit()
    # send nack bit as we only do a single byte read
    (scl_f,sda_f) = (0,1)
    update_force()
    (scl_f,sda_f) = (1,1)
    update_force()
    (scl_f,sda_f) = (0,1)
    update_force()
    return read_all_bits()

def reg_write(reg_addr, reg_data): # write a single register of mira
    global mira_addr
    start()
    send_byte(mira_addr<<1)
    send_byte(reg_addr>>8)
    send_byte(reg_addr&0xff)
    send_byte(reg_data)
    stop()
    
def reg_read(reg_addr): # read a single register of mira
    global mira_addr
    start()
    send_byte(mira_addr<<1)
    send_byte(reg_addr>>8)
    send_byte(reg_addr&0xff)
    rep_start()
    send_byte((mira_addr<<1)+1)
    res = read_byte()
    stop()
    return res

# ---- Higher level Mira functions ----
def otp_power_on():
    reg_write(0x0080, 0x04)

def otp_power_off():
    reg_write(0x0080, 0x08)

def otp_read_byte(otp_address, offset):
    reg_write(0x0086, otp_address)
    reg_write(0x0080, 0x02)
    return reg_read(0x0082 + offset)

def trim_restore(reg_address, otp_address):
    data = otp_read_byte(otp_address, 0)
    reg_write(reg_address, data)

def trims_restore():
    # addresses of the registers where the values as read from OTP need to be restored to
    reg = [0x4015, 0x4016, 0x4017, 0x4018, 0x403B, 0x4040, 0x4041, 0x4042, 0x402A, 0x4029, 0x4009, 0x403E]
    for ii in range(11):
        trim_restore(reg[ii], ii)
    trim_restore(reg[11], 13) # new for rev2: restore OTP data at addr 13 

def read_internal_id():
    b = bytearray(8)
    b[0] = otp_read_byte(0x25, 0) # byte 0 otp address 0x25
    b[1] = otp_read_byte(0x1E, 0) # byte 0 otp address 0x1E
    b[2] = otp_read_byte(0x1E, 1) # byte 1 otp address 0x1E
    b[3] = otp_read_byte(0x1E, 2) # byte 2 otp address 0x1E
    b[4] = otp_read_byte(0x1D, 0) # byte 0 otp address 0x1D
    b[5] = otp_read_byte(0x1D, 1) # byte 1 otp address 0x1D
    b[6] = otp_read_byte(0x1D, 2) # byte 2 otp address 0x1D
    b[7] = otp_read_byte(0x1D, 3) # byte 3 otp address 0x1D
    print("Sensor ID: 0x ", end="")
    for ii in range(7):
        print(f"{b[ii]:02x}:", end="")
    print(f"{b[7]:02x}")

def read_dark_mean():
    b0 = otp_read_byte(0x0E, 0) # byte 0 otp address 0x0E
    b1 = otp_read_byte(0x0E, 1) # byte 1 otp address 0x0E
    dark_mean = (b1 << 8) + b0
    print(f"OTP dark mean: {dark_mean:#06x}")

def read_revision():
    b0 = otp_read_byte(0x3A, 0)
    print(f"Revision: {b0:#04x}")

def main_opt_ops():
    otp_power_on()
    trims_restore() # restore all trims
    read_internal_id()
    read_dark_mean()
    read_revision()
    otp_power_off()

def check_pll(verbose = False):
    data = reg_read(0x50DC)
    pll_locked = (data & 0x01) > 0
    ref_clk_missing = (data & 0x02) > 0
    if verbose:
        print(f"PLL locked: {pll_locked}, Ref clock missing : {ref_clk_missing}")
    return pll_locked

def set_ldo(enable=False):
    # these resgisters are not properly documented in the Mira220 datasheet
    # taking the 'off' values from section 7.2.1 and the 'on' values as read at power-up
    if enable:
        reg_write(0x4038, 0xFB)
        reg_write(0x401E, 0x03)
    else:
        reg_write(0x401E, 0x02)
        reg_write(0x4038, 0x3B)

def upload_cfg(cfg_fname=None, verbose=False):
    # upload a config created by the "AMS Sensor Configuration Tool"
    # the configuration needs to be exported as .csv from the tool
    if cfg_fname==None:
        cfg_fname = "./mira_cfgs/Mira220_100Mbps_vertical_test_pattern.csv"
    else:
        cfg_fname = "./mira_cfgs/" + cfg_fname
    with open(cfg_fname, 'r') as file:
        for line in file:
            linesp = line.split(',')
            reg_write(int(linesp[0], 16), int(linesp[1], 16))
            if verbose: # print the comment in the .csv line
                print(linesp[2])

def turn_on(cfg_fname=None):
    # steps 1-5 (sequencer on demo board)
    # if powercycle:
    #     cam_en.value = False
    #     sleep(0.1)
    # cam_en.value = True
    # sleep(0.1)
    # step 6
    print("Initializing Mira with config file " + cfg_fname)
    while not check_pll():
        sleep(0.01) # TODO: implement timeout?
    # step 7
    set_ldo(enable=False)
    sleep(0.01)
    # step 8
    main_opt_ops()
    set_ldo(enable=True) # TODO: is this step necessary and correct? It is not explicitly mentioned in the datasheet
    sleep(0.01)
    # step 9
    upload_cfg(cfg_fname=cfg_fname)
    sleep(0.05)
    # soft reset
    reg_write(0x0040, 0x01)

