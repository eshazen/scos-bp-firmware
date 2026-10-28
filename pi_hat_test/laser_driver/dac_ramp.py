import RPi.GPIO as GPIO
import time
import sys

# Physical header pins 35, 33, 31, respectively:
CS   = 35   # BCM GPIO19, physical pin 35
SCK  = 33   # BCM GPIO13, physical pin 33
SDI  = 31   # BCM GPIO6,  physical pin 31

SHUTDOWN_PIN = 37   # physical pin 37

RED_PIN = 12    # BCM pin 18
GREEN_PIN = 18  # BCM pin 24
BLUE_PIN = 22   # BCM pin 25

GPIO.setmode(GPIO.BOARD)
GPIO.setwarnings( False)

GPIO.setup( RED_PIN, GPIO.OUT, initial=GPIO.HIGH)
GPIO.setup( GREEN_PIN, GPIO.OUT, initial=GPIO.HIGH)
GPIO.setup( BLUE_PIN, GPIO.OUT, initial=GPIO.HIGH)

GPIO.setup(CS, GPIO.OUT, initial=GPIO.HIGH)
GPIO.setup(SCK, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(SDI, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(SHUTDOWN_PIN, GPIO.OUT, initial=GPIO.HIGH)

def set_shutdown(asserted, *, active_low = False):
    """Assert or deassert SHUTDOWN.

    Set active_low=True if the signal is asserted by driving it LOW;
    otherwise, it is asserted by driving it HIGH.
    """
    level = GPIO.LOW if bool(asserted) == active_low else GPIO.HIGH
    GPIO.output(SHUTDOWN_PIN, level)

def set_rgb(red=False, green=False, blue=False):
    """Turn RGB LED channels on or off (True = on)."""
    GPIO.output(RED_PIN,   GPIO.LOW if red   else GPIO.HIGH)
    GPIO.output(GREEN_PIN, GPIO.LOW if green else GPIO.HIGH)
    GPIO.output(BLUE_PIN,  GPIO.LOW if blue  else GPIO.HIGH)

def set_dac_code(code, gain=1):
    """Write a 12-bit code (0–4095) to the MCP4821.

    gain: 1 for 1x output gain, or 2 for 2x output gain.
    """
    if not 0 <= code <= 4095:
        raise ValueError("code must be from 0 to 4095")
    if gain not in (1, 2):
        raise ValueError("gain must be 1 or 2")

    # MCP4821 command bits: GA (bit 13), SHDN (bit 12).
    # GA=1 selects 1x; GA=0 selects 2x. SHDN=1 enables the DAC.
    command = 0x3000 if gain == 1 else 0x1000
    word = command | int(code)

    GPIO.output(CS, GPIO.LOW)
    for bit in range(15, -1, -1):  # send MSB first
        GPIO.output(SDI, (word >> bit) & 1)
        GPIO.output(SCK, GPIO.HIGH)  # DAC reads data on rising edge
        GPIO.output(SCK, GPIO.LOW)
    GPIO.output(CS, GPIO.HIGH)


set_shutdown( False)
set_rgb( False, False, False)

if len(sys.argv) < 2:
    while True:
        for code in range(4095):
            set_dac_code( code, 2)
else:
    set_dac_code( int(sys.argv[1]), 2)
