import RPi.GPIO as GPIO

# Physical header pins 35, 33, 31, respectively:
CS   = 19   # BCM GPIO19, physical pin 35
SCK  = 13   # BCM GPIO13, physical pin 33
SDI  = 6    # BCM GPIO6,  physical pin 31

GPIO.setmode(GPIO.BCM)
GPIO.setup(CS, GPIO.OUT, initial=GPIO.HIGH)
GPIO.setup(SCK, GPIO.OUT, initial=GPIO.LOW)
GPIO.setup(SDI, GPIO.OUT, initial=GPIO.LOW)


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
