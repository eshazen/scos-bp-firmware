#
# control power using uart
#
import serial

ser = "x"

def uart_init():
    global ser
    ser = serial.Serial('/dev/ttyS0', 115200, timeout=1)

def led_on():
    ser.write(b'$P@|')

def all_off():
    ser.write(b'$P@@')

def mira_power_up():
    ser.write(b'$P@@')
    ser.write(b'$P@P')
    ser.write(b'$P@X')
    ser.write(b'$P@\\')
    ser.write(b'$P@|')

def mira_power_down():
    ser.write(b'$P@\\')
    ser.write(b'$P@X')
    ser.write(b'$P@P')
    ser.write(b'$P@@')

