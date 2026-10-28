def set_rgb(red=False, green=False, blue=False):
    """Turn RGB LED channels on or off (True = on)."""
    GPIO.output(RED_PIN,   GPIO.LOW if red   else GPIO.HIGH)
    GPIO.output(GREEN_PIN, GPIO.LOW if green else GPIO.HIGH)
    GPIO.output(BLUE_PIN,  GPIO.LOW if blue  else GPIO.HIGH)
