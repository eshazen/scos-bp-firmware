def set_shutdown(asserted, *, active_low):
    """Assert or deassert SHUTDOWN.

    Set active_low=True if the signal is asserted by driving it LOW;
    otherwise, it is asserted by driving it HIGH.
    """
    level = GPIO.LOW if bool(asserted) == active_low else GPIO.HIGH
    GPIO.output(SHUTDOWN_PIN, level)
