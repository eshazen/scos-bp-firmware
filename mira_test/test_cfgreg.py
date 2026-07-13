import serial # make sure pyserial, not serial is installed
import time

N_CFG_REG_ADDR_BITS = 0

ser = serial.Serial('COM19', baudrate=12000000, rtscts=True, timeout=3)
ser.write([0xfe, (1<<7)+1, 0]) # cfg reg readback
for ival in range(5):
    time.sleep(0.05)
    ser.reset_input_buffer()



errcnt = 0;
print("ireg/ival :        ", end='')
for ireg in range(2**N_CFG_REG_ADDR_BITS):
    for ival in range(256):
        print(f"\b\b\b\b\b\b\b{ireg:3d}/{ival:3d}", end='', flush=True)
        ser.write([0xfe, (1<<7)+ireg, ival]) # write register
        ser.write([0xfe, ireg, ival]) # read register
        rawdat = ser.read(2)
        if rawdat[0]!=0xfd or rawdat[1]!=ival:
            errcnt += 1
        time.sleep(0.01)

print("")
print(f"errcnt = {errcnt}")



print("closing")
ser.close()


