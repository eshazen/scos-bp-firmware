import RPi.GPIO as GPIO
import time

GPIO.setmode( GPIO.BOARD)
GPIO.setwarnings( False)

# RED_PIN = 18    # header pin 12
# GREEN_PIN = 24  # header pin 18
# BLUE_PIN = 25   # header pin 22

RED_PIN = 12    # BCM pin 18
GREEN_PIN = 18  # BCM pin 24
BLUE_PIN = 22   # BCM pin 25

GPIO.setup( RED_PIN, GPIO.OUT)
GPIO.setup( GREEN_PIN, GPIO.OUT)
GPIO.setup( BLUE_PIN, GPIO.OUT)

def set_rgb(red=False, green=False, blue=False):
    """Turn RGB LED channels on or off (True = on)."""
    GPIO.output(RED_PIN,   GPIO.LOW if red   else GPIO.HIGH)
    GPIO.output(GREEN_PIN, GPIO.LOW if green else GPIO.HIGH)
    GPIO.output(BLUE_PIN,  GPIO.LOW if blue  else GPIO.HIGH)


set_rgb( False, False, False)
time.sleep(0.2)
set_rgb( True, False, False)
time.sleep(0.2)
set_rgb( False, True, False)
time.sleep(0.2)
set_rgb( False, False, True)
time.sleep(0.2)
set_rgb( False, False, False)
